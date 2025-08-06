---
title: "illumos Telegraf Plugins"
date: 2021-09-11
tags: [illumos, Telegraf, Go, Wavefront]
category: articles
---

Some time ago I made
[some Solaris collectors for Diamond](https://github.com/snltd/sunos-diamond-collectors),
and I also [wrote about making them](/tag/Diamond). Those collectors work great:
I've had them running for about four years with no issue, in conjunction with
[a Wavefront output](https://github.com/python-diamond/Diamond/pull/632) that
ain't never getting merged. (UPDATE! They reviewed the PR!)

I used Diamond because at that time Telegraf wouldn't build on anything
Solarish. But some smart people soon fixed that, even though none of the
OS-related plugins could make any sense of a SunOS kernel or userspace.

So I cobbled together
[some really sketchy Telegraf inputs](https://github.com/snltd/solaris-telegraf-plugins/tree/28949e2ad61e9d02b0a033d36420289eee7f27d9).
They worked fine, but they weren't well written, had no tests, and they didn't
have anything like the coverage of the Diamond ones. Because I was using the
lamented Joyent Public Cloud at the time, I tailored them specifically for
non-global SmartOS zones, which meant they weren't much good for monitoring
servers.

Furthermore, they needed a whole Python setup, which was extremely painful to
implement in the global zone of a SmartOS system, and even when I moved to
OmniOS, where the more traditional global zone approach made that a lot simpler,
it still felt messy.

So, I decided to rework the Telegraf plugins.

## Philosophy and Excuses

Most of my input plugins generate metrics from kstats. Kstats have a `snaptime`
value, which allows extremely accurate calculation of rates of change. Any smart
person would use `snaptime` to calculate diffs between values and send them as
rates. But not me.

I chose to send the raw kstat value, stamped with the time at which it was
collected. This was partly down to the "just get it done" first iteration, but
I've found it works perfectly well. Really, when you're running on a ten or
thirty second collection interval, and your target system has one-second
resolution, nanosecond timing doesn't make a whole heap of difference. I'm not
trying to implement super-accurate, super-critical aeroplane blackbox telemetry:
I just want an overview of system health.

Most of my charts, as you'll see later, convert the raw values with a
`rate()`-type function. But, I've found that sometimes the raw values can even
be better than rates, especially when alerting. It's nice to have the absolute
value and the derivative, and it's easier to get from the former to the latter.

I chose to drop Solaris support this time. I don't run Solaris any more, and
there's significant divergence now between it and illumos.

## CPU

The first thing people tend to want to measure, probably because it's easy, is
CPU usage.[^1]

illumos exposes a lot of CPU statistics, down to things like per-core page
scans, but all I'm not interested in that. I only want to know how hard a system
is working on, and maybe whether it's spending its time in kernel or user space.
That means I want the `cpu_nsec` stats, which are part of the `cpu:n:sys`
module.

```cmd
$ kstat cpu:0:sys | grep nsec
        cpu_nsec_dtrace                 14699590921
        cpu_nsec_idle                   1302005686348634
        cpu_nsec_intr                   10345655014135
        cpu_nsec_kernel                 81405829122846
        cpu_nsec_user                   384278971412372
```

The `cpu` input, like most of the inputs I'll talk about later, is mostly
configured by naming the kstats you want to see. So, my config looks like this:

```toml
[[inputs.illumos_cpu]]
sys_fields = [
  "cpu_nsec_dtrace",
  "cpu_nsec_intr",
  "cpu_nsec_kernel",
  "cpu_nsec_user",
]
cpu_info_stats = true
zone_cpu_stats = true
```

> Here's an "interesting" design decision I maybe should have mentioned earlier.
> If you set `sys_fields` to an empty list, you get **all** the `cpu:n:sys`
> kstats.
>
> You may feel this is a terrible, counter-intuitive decision, and I wouldn't
> blame you, but it feels right to me. If you actually want to specify "no
> stats", put something like `["none"]` as your field list. Or disable the
> plugin.

Here is a chart of some of those `sys` metrics, along with the Wavefront
[WQL](https://docs.wavefront.com/query_language_reference.html) queries which
generate it. Hover over the points to see the extra dimensions, or tags, or
labels, or whatever you prefer to call them.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> deriv(
       sum(ts("cpu.nsec.*", source=${host}), coreID))
       /
       (count(ts("cpu.nsec.dtrace", source=${host})
    ) * 1e7)
```

This sums the different types of CPU usage presented by the kstats across all
the cores. Dividing by `number of cores × 1e7` gives a percentage.

We could omit the `sum()` and get per-core usage, if we cared about that. If you
aren't interested in DTrace or interrupt usage -- which you likely aren't ---
omit them from the Telegraf config and save yourself some point rate. Pretty
standard stuff.

It might be more interesting to look at a per-zone breakdown. To turn this on,
set `zone_cpu_stats` to true, and you'll get something like this.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> sum(
      deriv(ts("cpu.zone.*", source=${host})), name)
      /
      (count(ts("cpu.nsec.user", source=${host})
    ) * 1e7)
```

You can see a few builds happening in `serv-build`; `serv-fs` booting up about
halfway along, and a bit of spikiness where Ansible ran and asserted the state
of all the zones. The kernel exposes, and the collector collects, system and
user times for each zone, but here I've summed them for a "total CPU per zone"
metric.

Turning on `cpu_info_stats` looks at the `cpu_info`. It produces a single metric
at the moment: the current speed of the VCPU, tagged with some other,
potentially useful, information.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ts("cpu.info.speed", source=${host})
```

## Disk Health

Next, alphabetically, is the disk health plugin. This uses kstats in the
`device_error` class. Let's have a look:

```cmd
$ kstat -c device_error -i3
module: sderr                           instance: 3
name:   sd3,err                         class:    device_error
        crtime                          33.030081552
        Device Not Ready                0
        Hard Errors                     0
        Illegal Request                 0
        Media Error                     0
        No Device                       0
        Predictive Failure Analysis     0
        Product                         Samsung SSD 860 9
        Recoverable                     0
        Revision                        1B6Q
        Serial No                       S3Z2NB1K728477N
        Size                            500107862016
        snaptime                        2112679.332420447
        Soft Errors                     0
        Transport Errors                0
        Vendor                          ATA
```

There are two things to notice here. First, a lot of the values are not numeric.
If you try to turn these into metrics, you'll have a bad time. So choose wisely.
Secondly, what's with those names? Capital letters and spaces?

The plugin makes some effort to improve this. You specify your fields using the
real kstat names, but the plugin will `camelCase` them into `hardErrors` and
`illegalRequest` and so-on. If any of the string-valued stats look useful, you
can turn them into tags.

The choice to output raw values also makes sense here, because you're measuring
the _rate_ of errors on a disk, you've got real issues. Better to know
cumulatively how many there have been.

The "not specifying anything gets you everything" approach also makes more sense
in this context. You may not know in advance what device IDs your disks will
get, so by using a blank value, you'll get metrics about them all, wherever they
land. Add more disks, get more metrics, no configuration required.

Here's my config, which checks disk health every ten minutes.

```toml
[[inputs.illumos_disk_health]]
interval = "10m"
fields = ["Hard Errors", "Soft Errors", "Transport Errors", "Illegal Request"]
tags = ["Vendor", "Serial No", "Product", "Revision"]
devices = []
```

I used to have a lovely chart here of a disk dying in agony. Sadly, the data
expired, so now the best I can do is show you a few illegal request errors from
a USB drive I use for backups.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ceil(deriv(ts("diskHealth.*", source=${host})))
```

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> sum(ts("diskHealth.*", source=${host}), product, serialNo)
```

## FMA

The `illumos_fma` collector shells out to `fmstat(1m)` and `fmadm(1m)`, turning
their output into numbers. I don't think there's a huge amount of value in the
`fmstat` metrics, at least on the little home machines I have, though they do
give a little insight into how FMA actually works. I don't collect them now.

I do, however, collect, and alert off, the `fma.fmadm.faults` metric. Anything
non-zero here ain't good.

For each FMA error, it sees, the collector will produce a point whose tags are a
breakdown of the fault FMRI. A fault of `zfs://pool=big/vdev=3706b5d93e20f727`
will therefore generate a point with a constant value of 1 and tags of
`module = zfs`, `pool = big`, and `vdev = 3706b5d93e20f727`. Put these in a
table and they're a pretty useful metric.

## IO

The IO plugin looks at the `disk` kstat class which, on my machines at least,
breaks down into `sd` (device level) and `zfs` (pool level) statistics.

```cmd
$ kstat -c disk -m zfs
module: zfs                             instance: 0
name:   rpool                           class:    disk
        crtime                          33.040698445
        nread                           89256141824
        nwritten                        4917084512256
        rcnt                            0
        reads                           12924589
        rlastupdate                     2283599909215801
        rlentime                        93260596443424
        rtime                           22778143997056
        snaptime                        2283600.200850278
        wcnt                            0
        wlastupdate                     2283599909180201
        wlentime                        1382360339824286
        writes                          134488141
        wtime                           17956052528931
...
$ kstat -c disk -m sd
module: sd                              instance: 6
name:   sd6                             class:    disk
        crtime                          38.500260610
        nread                           4403392102
        nwritten                        63619379200
        rcnt                            0
        reads                           617284
        rlastupdate                     779318097724680
        rlentime                        6037614078523
        rtime                           3660651799956
        snaptime                        2283628.843277697
        wcnt                            0
        wlastupdate                     779318095367423
        wlentime                        2103813659369
        writes                          153664
        wtime                           685893661939
...
```

The config looks like this

```toml
[[illumos_io]]
fields = ["reads", "nread", "writes", "nwritten"]
modules = ["sd", "zfs"]
```

You can select `zfs` and/or `sd` modules, and you can select also specify
`devices` (the kstat name). As usual, selecting none gets you all of them. You
can also select the kstat fields you wish to collect, and they're emitted as raw
values, so you'll likely need to get your `rate()` on.

This is a view of bytes written, broken down by zpool:

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> rate(ts("io.nwritten", source=${host} and module="zfs"))
```

## Memory

The memory plugin takes its info from a number of sources, all of which are
optional. Here's my config:

```toml
[[inputs.illumos_memory]]
swap_on = true
swap_fields = ["allocated", "reserved", "used", "available"]
extra_on = true
extra_fields = ["kernel", "arcsize", "freelist"]
vminfo_on = true
vminfo_fields = [
  "freemem",
  "swap_alloc",
  "swap_avail",
  "swap_free",
  "swap_resv",
]
cpuvm_on = true
cpuvm_fields = [
  "pgin",
  "anonpgin",
  "pgpgin",
  "pgout",
  "anonpgout",
  "pgpgout",
  "swapin",
  "swapout",
  "pgswapin",
  "pgswapout",
]
cpuvm_aggregate = true
zone_memcap_on = true
zone_memcap_zones = []
zone_memcap_fields = ["physcap", "rss", "swap"]
```

`swap` (as in `on` and `fields`) uses the output of `swap -s`, turning the
numbers into bytes.

`vminfo` looks at the `unix:0:vminfo` kstat, and converts the values it finds
there, which are in pages, into bytes.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> deriv(ts("memory.vminfo.*", source=${host}))
```

`cpuvm` uses the `cpu:n:vm` kstats:

```cmd
# kstat cpu:0:vm
module: cpu                             instance: 0
name:   vm                              class:    misc        anonpgin                        91181
        anonpgout                       691806
                       280100%9691
        cow_fault                       456075696
        crtime                          34.408122794
        dfree                           2198350
        execfree                        39764
        execpgin                        1
        execpgout                       1526
        fsfree                          602089
        fspgin                          530327
        fspgout                         377473
        hat_fault                       0
        kernel_asflt                    0
        maj_fault                       160708
        pgfrec                          374000423
        pgin                            161053
        pgout                           88551
        pgpgin                          621509
        pgpgout                         1070805
        pgrec                           374000476
        pgrrun                          887
        pgswapin                        0
        pgswapout                       0
        prot_fault                      1300095547
        rev                             0
        scan                            88740494
        snaptime                        2371429.653330849
        softlock                        22753
        swapin                          0
        swapout                         0
        zfod                            1610062468
```

Choose whichever fields you think will be useful. Per-CPU information of this
level seemed excessive to me, so I added the `cpuvm_aggregate` switch, which
adds everything together and puts them under an `aggregate` metric path. I use
these numbers to look for paging and swapping.

Finally, there are the `extra` fields, which look for the size of the kernel,
ZFS ARC, and the freelist. These are all kstats, but they're gauge values, so
there's no need to process them further.

This is their view of a machine booting:

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ts("memory.arcsize", source=${host})
WQL> ts("memory.kernel", source=${host})
WQL> ts("memory.freelist", source=${host})
```

Per-zone memory stats are also available, via the `memory_cap` kstats:

```cmd
$ kstat memory_cap:1            
module: memory_cap                      instance: 1     
name:   serv-dns                        class:    zone_memory_cap
        anon_alloc_fail                 0
        anonpgin                        0
        crtime                          67.911936037
        execpgin                        0
        fspgin                          0
        0
        pgpgin                          0
                        314572100%
        rss                             1874.005818820
        swap                            66465792
                        314572100%
        zonename                        serv-dns
```

These are gauge metrics, so no need to process them further. Let's look at RSS:

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ts("memory.zone.rss", source=${host} and zone=${zone})
```

## Network

The network plugin tries to be at least a little smart. If you hover over this
chart and look at the legend you'll see it's collecting network metrics for all
VNICs, and attempting to add meaningful tags to them.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> rate(ts("net.obytes64", source=${host} and zone != "global" and zone = "${zone}"))
WQL> rate(ts("net.obytes64", source=${host} and zone = "global")) - sum(${zones})
```

It can work out the zone, by running `dlamd(1m)` each time it is invoked, and
mapping the VNIC name to the zone. Whilst it's doing that it also tries to get
stuff like the link speed and the name of the underlying NIC. It's not very good
with etherstubs, and it wouldn't have a clue about anything any more advanced
than you see here. Like all these plugins, it does what I wanted and goes no
further.

## NFS

The NFS server and client plugins expose metrics in the kstat `nfs` modules.
Here you run up against a limitation of kstats. So far as I can tell, zones keep
their own kstat views, so Telegraf running in the global zone _cannot_ monitor
the NFS activity -- server or client -- in a local zone. I suppose I could do
something horrible, like `zlogin` into the NGZ and parse the output of
`kstat(1m)`, but doing things cleanly, it's not possible. So if NGZ NFS is a big
thing to you, you're stuck using per-zone Telegrafs.

You can choose which NFS protocol versions you require with the `nfs_versions`
setting, and then you just pick your kstat `fields` like all the other plugins.
The NFS version is a tag. This chart aggregates my main global zone Telegraf
with another which runs in a local NFS server zone.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> rate(ts("nfs.server.*"))
```

## OS

This one is so dumb you can't even configure it. Its value is always one, but
the tags might be useful for something. I "borrowed" it from Prometheus Node
Exporter.

!!["broadcom deleted my account"](/i/deleted.png)

```wql
WQL> ts("os.release")
```

## Packages

This counts the number of packages which can be upgraded, or which are
installed. It works in `pkg(5)` or `pkgin` zones, and if it runs in the global
zone, it can attempt to `zlogin` to NGZs and get their information.

```
[[inputs.illumos_packages]]
## Whether you wish this plugin to try to refresh the package database. Personally, I wouldn't.
  # refresh = false
  ## Whether to report the number of installed packages
  # installed = true
  ## Whether to report the number of upgradeable packages
  # upgradeable = true
  ## Which zones, other than the current one, to inspect
  # zones = []      
  ## Use this command to get the elevated privileges run commands in other zones via zlogin. 
  ## and to run pkg refresh anywhere. Should be a path, like "/bin/sudo" "/bin/pfexec", but can 
  ## also be "none", which will collect only the local zone.
  # elevate_privs_with = "/bin/sudo"
```

The final part of the config talks about how to make it work. In the past I've
used `pfexec` with a role, but `sudo` is simplest.

```
# cat /etc/sudoers.d/telegraf
telegraf ALL=(root) NOPASSWD: /usr/sbin/zlogin
telegraf ALL=(root) NOPASSWD: /bin/svcs
telegraf ALL=(root) NOPASSWD: /usr/sbin/fmadm
```

The `packages` plugin can refresh the package database on every run. This might
be very heavy if you have a lot of zones, and if you have config management,
that's probably already doing it. I don't use it myself.

!!["broadcom deleted my account"](/i/deleted.png)

```wql
WQL> ts("packages.upgradeable")
```

Looks like I need a `pkg update -r`.

## Process

The most complicated, and probably least useful input plugin is `process`. It
works a bit like `prstat(8)`, sampling CPU and/or memory usage at a given
interval.

```
[[inputs.illumos_process]]
  ## A list of the kstat values you wish to turn into metrics. Each value
  ## will create a new timeseries. Look at the plugin source for a full
  ## list of values.
  # Values = ["rtime", "rsssize", "inblk", "oublk", "pctcpu", "pctmem"]
  ## Tags you wish to be attached to ALL metrics. Again, see source for
  ## all your options.
  # Tags = ["name", "zoneid", "uid", "contract"]
  ## How many processes to send metrics for. You get this many process for
  ## EACH of the Values you listed above. Don't set it to zero.
  # TopK = 10
  ## It's slightly expensive, but we can expand zone IDs and contract IDs
  ## to zone names and service names.
  # ExpandZoneTag = true
  # ExpandContractTag = true
```

Let's see what's consuming memory:

!!["broadcom deleted my account"](/i/deleted.png)

I say "least useful" because, as with all tools of this nature, it's very easy
for things to happen between collection intervals. It can still be useful for
giving a sense of what's going on, though, and it'll certainly show up memory
leaks in long-running processes.

```
WQL> ts("process.rssize")
```

!!["broadcom deleted my account"](/i/deleted.png)

```
WQL> ts("process.pctcpu") / 100
```

## SMF

This shells out to `svcs(1m)` to give you an overview of the health of your SMF
services. It runs `svcs` with the `-Z` flag, and, like the `packages` input, you
can specify a privilege-elavator (`sudo` or `pfexec`) to make this work.
Alternatively, run your Telegraf service with the `file_dac_search` privilege,
which does the business on its own.

Here's just one NGZ, seen from the global. You can, of course, specify which
zones you're interested in, and specifying none gets you the lot.

The tagging is rich enough that you can get a table of errant services. Here's a
look at my media server, from when it booted in the morning with a broken
`minidlna` server to 5pm when tried to listen to some music, found it didn't
work, and fixed it. Maybe I need an alert.

!!["broadcom deleted my account"](/i/deleted.png)

```wql
WQL> ts("smf.states", zone="serv-media")
```

If you don't want the detailed service view, or you're worried applying service
names as tags will cause high cardinality, you can set
`generate_details = false` and not get these metrics.

## ZFS ARC

This plugin just presents the stats you get from `kstat -m zfs -n arcstats`.
There are too many of those to list here, and I don't run this plugin as I don't
have anything with a ZFS ARC right now so you don't even get a chart. Sorry!

## Zones

The zones plugin gathers the uptime and the age of every zone on the box. The
former comes from the `zones` `boottime` kstat, and the latter is worked out by
looking when the relevant file in `/etc/zones` was modified. I haven't found
uptime enormously useful, but I like the age stat because I like to exercise my
infrastructure creation, and it shows me any zones that haven't been rebuilt in
too long.

Each point on these metric paths comes with a bunch of tags like brand, IP type
and status. Filtering and grouping on these can turn up lots of useful and
interesting data. Or you can just count zones.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> count(ts("zones.uptime", source=${host}), brand)
```

## Zpool

Zpool is another run-external-program cop-out. For starters it parses
`zpool list`, and offers up the various fields as numbers.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ts("zpool.cap", source=${host})
```

There's a synthetic "health" metric too. This converts the health of the pool to
a number. I put the mapping in my chart annotation:

```
0 = ONLINE, 1 = DEGRADED, 2 = SUSPENDED, 3 = UNAVAIL, 4 = unknown
```

And I can alert off non-zero states.

You can also turn on "status" metrics. This takes the output of
`zpool status -pv <pool>` and turns it into numbers. As well as counting the
errors in each device of the pool, it also plots the time since the last
successful scrub (for easy alerting off not-scrubbed-in-forever pools), and
plots the time of a resilver scrub. The actual elapsed time probably isn't so
useful, but it being non-zero certainly can be.

!!["broadcom deleted my account"](/i/deleted.png)

```sql
WQL> ts("zpool.status.timeSinceScrub", host=${host})
```

## Making it Work

[The repo](https://github.com/snltd/illumos-telegraf-plugins) has full
instructions on how to build a version of Telegraf with these plugins installed,
and there's
[everything you need to run it under SMF](https://github.com/snltd/illumos-telegraf-plugins/tree/main/smf).
I even put in
[a directory](https://github.com/snltd/illumos-telegraf-plugins/tree/main/omnios-build)
you can drop into an [omnios-extra](https://github.com/omniosorg/omnios-extra)
checkout, and get a proper package.

If you wish to improve these plugins, or add more, please do fork
[the repo](https://github.com/snltd/illumos-telegraf-plugins) and raise a PR. If
you find bugs, or wish improvements that you aren't able to make yourself,
[open an issue](https://github.com/snltd/illumos-telegraf-plugins/issues/new)
and I'll have a look.

[^1]: Actually, the first thing a lot of people seem to look for is load
average, but if you think that's a good way to monitor a system, look elsewhere.

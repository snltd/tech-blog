---
title: "Illumos Telegraf Plugins"
date: 2021-09-11
tags: [Illumos, Telegraf, Go, Wavefront]
category: articles
---

Some time ago I made [some Solaris collectors for
Diamond](https://github.com/snltd/sunos-diamond-collectors), and I also
[wrote about making them](https://sysdef.xyz/tag/Diamond). Those collectors
work great: I've had them running for about four years with no issue, in
conjunction with [a Wavefront
output](https://github.com/python-diamond/Diamond/pull/632) that ain't never
getting merged.

I used Diamond because at that time Telegraf wouldn't build on anything
Solarish. But some smart people soon fixed that, even though none of the
OS-related plugins could make any sense of a SunOS kernel.

So I cobbled together [some really sketchy Telegraf
inputs](https://github.com/snltd/solaris-telegraf-plugins/tree/28949e2ad61e9d02b0a033d36420289eee7f27d9).
They worked well enough, but they weren't well written, had no tests, and they
didn't have anything like the coverage of the Diamond ones. Because I was
using the lamented Joyent Public Cloud at the time, I targeted them
specifically for non-global SmartOS zones, so they weren't much good for
monitoring servers.

Recently I decided to rework the Telegraf plugins, hoping to replace my creaky
old Diamond setup.

## Philosophy and Excuses

Most of the plugins generate metrics from kstats. Kstats have a `snaptime`
value, which allows extremely accurate calculation of rates of change. Any
smart person would use `snaptime` to calculate diffs between values and send
them as rates. But not me.

I chose to send the raw kstat value, stamped with the time at which it was
collected. This was partly down to the "just get it done" first iteration, but
I've found it works perfectly well.

Most of my charts, as you'll see later, simply convert the raw values with a
`rate()` function, which is no effort at all, and I've even found that
raw values can even be better than rates, in some circumstances.
Often I wish to alert off changes over time, rather than thresholds, and it's
far easier to reliably turn a counter into a rate than the other way round.

I also chose to drop Solaris support. I don't run Solaris any more, and
there's significant divergence now between it and Illumos.

## CPU

The first thing people tend to want to measure, probably because it's easy, is
CPU usage.[^1]

My `telegraf.conf` stanza for the CPU plugin looks like this:

```toml
[[inputs.illumos_cpu]]
  sys_fields = ["cpu_nsec_dtrace", "cpu_nsec_intr", "cpu_nsec_kernel", "cpu_nsec_user"]
  cpu_info_stats = true
  zone_cpu_stats = true
```

`sys_fields` is a list of `cpu::sys` kstats you want to collect. I use the
`nsec` ones, which are counters of the nanoseconds spent by the CPU in one of
a number of states.

```cmd
$ kstat cpu:0:sys | grep nsec
        cpu_nsec_dtrace                 14699590921
        cpu_nsec_idle                   1302005686348634
        cpu_nsec_intr                   10345655014135
        cpu_nsec_kernel                 81405829122846
        cpu_nsec_user                   384278971412372
```

Here's an "interesting" design decision I maybe should have mentioned earlier.
If you set `sys_fields` to an empty list, you get *all* the `cpu:n:sys`
kstats.

You may feel this is a terrible, counter-intuitive decision, and I wouldn't
blame you, but it feels right to me. If you actually want to specify "no
stats", put something like `["none"]` as your field list. Or disable the
plugin.

Here is a chart of some of those `sys` metrics, along with the Wavefront
[WQL](https://docs.wavefront.com/query_language_reference.html) queries which
generate it. Hover over the points to see the extra dimensions, or tags, or
labels, or whatever you prefer to call them.

<script src="https://metrics.wavefront.com/embedded/whY52xZSmT/js"
id="wavefront-embedded-whY52xZSmT" width="700" height="300"></script>

```sql
WQL> rate(sum(ts("dev.telegraf.cpu.nsec.*"), metrics)) / 4e7
WQL> mavg(10m, rate(sum(ts("dev.telegraf.cpu.nsec.*"))) / 4e7)
```

The first query sums the different types of CPU usage presented by the kstats
across all the cores.  Dividing by `number of cores × 1e7` gives me a
percentage.

The second query (the flatter blue line) is the moving average of all CPU
usage across all cores.

We could omit the `sum()` and get per-core usage, if we cared about that. If
you aren't interested in DTrace or interrupt usage -- which you likely aren't
--- omit them from the Telegraf config and save yourself some point rate.
Pretty standard stuff.

It might be more interesting to look at a per-zone breakdown. To turn this on,
set `zone_cpu_stats` to true, and you'll get something like this.

<script src="https://metrics.wavefront.com/embedded/vqwbpMqbcQ/js"
id="wavefront-embedded-vqwbpMqbcQ" width="700" height="300"></script>

```sql
WQL> rate(sum(ts("dev.telegraf.cpu.zone.*"), name)) / 4e7
```

This is a largely idle system: the spikes are Puppet running in
each zone, with the global burbling along running things, and it looks like
something maxed out a core in `cube-ws` for about five minutes. You get
system and user times for each zone, but here I've summed them for a "total
CPU per zone" metric.

Turning on `cpu_info_stats` looks at the `cpu_info`. It produces a single
metric at the moment: the current speed of the VCPU, tagged with some other,
potentially useful, information.

<script src="https://metrics.wavefront.com/embedded/X12RSlWQ6C/js"
id="wavefront-embedded-X12RSlWQ6C" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.cpu.info.speed")
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

There are two things to notice here. First, a lot of the values are not
numeric. If you try to turn these into metrics, you'll have a bad time. So
choose wisely. Secondly, what's with those names? Capital letters and spaces?

The plugin makes some effort to improve this. You specify your
fields using the real kstat names, but the plugin will `camelCase` them into
`hardErrors` and `illegalRequest` and so-on. If any of the string-valued stats
look useful, you can turn them into tags.

The choice to output raw values also makes sense here, because you're
measuring the *rate* of errors on a disk, you've got real issues. Better to
know cumulatively how many there have been.

The "not specifying anything gets you everything" approach also makes
more sense in this context. You may not know in advance what device IDs your
disks will get, so by using a blank value, you'll get metrics about them all,
wherever they land. Add more disks, get more metrics, no configuration
required.

Here's my config, which checks disk health every ten minutes.

```toml
[[inputs.illumos_disk_health]]
  interval = "10m"
  fields = ["Hard Errors", "Soft Errors", "Transport Errors", "Illegal Request"]
  tags = ["Vendor", "Serial No", "Product", "Revision"]
  devices = []
```

And here is a disk dying in agony. Please excuse the screwy "size" tag: that bug
is fixed now. The metric path is different from the others because these are
production metrics. The alert ends because the disk was taken out of the
pool.

<script src="https://metrics.wavefront.com/embedded/pdnzbqzdKN/js"
id="wavefront-embedded-pdnzbqzdKN" width="700" height="300"></script>

```sql
WQL> ts("diskHealth.transportErrors", serialNo="WD-WCC7K3ZVCRH6")
```

## FMA

The `illumos_fma` collector shells out to `fmstat(1m)` and `fmadm(1m)`,
turning their output into numbers. I don't think there's a huge amount of
value in the `fmstat` metrics, though they do give a little insight into how
FMA actually works. I don't collect them now.

I do, however, collect, and alert off, the `fma.fmadm.faults` metric. Anything
non-zero here ain't good.

For each FMA error, it sees, the collector will produce a point whose tags are
a breakdown of the fault FMRI. A fault of
`zfs://pool=big/vdev=3706b5d93e20f727` will therefore generate a point with a
constant value of 1 and tags of `module = zfs`, `pool = big`, and `vdev =
3706b5d93e20f727`. Put these in a table and they're a pretty useful metric.
Sadly, Wavefront won't let me share tables with you.

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
  ## Report on the following devices, inside the above modules. Specifying none reports on all.
  #devices = ["sd0"]

```

You can select `zfs` and/or `sd`; you can select any devices (the kstat name)
and, as usual, selecting none gets you all of them. You can also select the
kstat fields you wish to collect, and they're emitted as raw values, so you'll
likely need to get your `rate()` on.

<script src="https://metrics.wavefront.com/embedded/dq77sN9L2J/js"
id="wavefront-embedded-dq77sN9L2J" width="700" height="300"></script>

```sql
WQL> rate(ts("dev.telegraf.io.nwritten", module="sd"))
```

You can see from that that I have mirrored disks. Here's the same view by
pool, which probably makes more sense.

<script src="https://metrics.wavefront.com/embedded/71w2KZrxRg/js"
id="wavefront-embedded-71w2KZrxRg" width="700" height="300"></script>

```sql
WQL> rate(ts("dev.telegraf.io.nwritten", module="zfs"))
```

## Memory

The memory plugin takes its info from a number of sources, all of which are
optional. Here's the config:


```toml
[[inputs.illumos_memory]]
 swap_on = true
 swap_fields = ["allocated", "reserved", "used", "available"]
 extra_on = true
 extra_fields = ["kernel", "arcsize", "freelist"]
 vminfo_on = true
 vminfo_fields = ["freemem", "swap_alloc", "swap_avail", "swap_free", "swap_resv"]
 cpuvm_on =true
 cpuvm_fields = ["pgin", "anonpgin", "pgpgin", "pgout", "anonpgout", "pgpgout",
                 "swapin", "swapout", "pgswapin", "pgswapout"]
 cpuvm_aggregate = true
```

`swap` (as in `on` and `fields`) uses the output of `swap -s`, turning the
numbers into bytes.

<script src="https://metrics.wavefront.com/embedded/ZvcD7WTmFD/js"
id="wavefront-embedded-ZvcD7WTmFD" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.memory.swap.*")
```

`vminfo` looks at the `unix:0:vminfo` kstat, and converts the values it finds
there, which are in pages, into bytes.

<script src="https://metrics.wavefront.com/embedded/XgNdmP6l2j/js"
id="wavefront-embedded-XgNdmP6l2j" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.memory.vminfo.*")
```

`cpuvm` uses the `cpu:n:vm` kstats:

```cmd
# kstat cpu:0:vm
module: cpu                             instance: 0
name:   vm                              class:    misc
        anonfree                        1556497
        anonpgin                        91181
        anonpgout                       691806
        as_fault                        2808009691
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

<script src="https://metrics.wavefront.com/embedded/F2c1ZWJZt8/js"
id="wavefront-embedded-F2c1ZWJZt8" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.memory.cpuVm.vm.aggregate.*")
```

Finally, there are the `extra` fields, which look for the size of the kernel,
ZFS ARC, and the freelist. These are all kstats, but they're gauge values, so
there's no need to process them further.

<script src="https://metrics.wavefront.com/embedded/Ps5KNvtD4d/js"
id="wavefront-embedded-Ps5KNvtD4d" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.memory.arcsize")
WQL> ts("dev.telegraf.memory.kernel")
WQL> ts("dev.telegraf.memory.freelist")
```

## Network

The network plugin tries to be at least a little smart. If you hover over this
chart and look at the legend you'll see it's collecting network metrics for
all VNICs, and attempting to add meaningful tags to them.

<script src="https://metrics.wavefront.com/embedded/79ZCn47NHH/js"
id="wavefront-embedded-79ZCn47NHH" width="700" height="300"></script>


```sql
WQL> rate(ts("dev.telegraf.net.obytes64"))
```

It can work out the zone, by running `dlamd(1m)` each time it is invoked, and
mapping the VNIC name to the zone. Whilst it's doing that it also tries to get
stuff like the link speed and the name of the underlying NIC. It's not very
good with etherstubs, and it wouldn't have a clue about anything any more
advanced than you see here. Like all these plugins, it does what I wanted and
goes no further.

## NFS

The NFS server and client plugins expose metrics in the kstat `nfs` modules.
Here you run up against a limitation of kstats. So far as I can tell, zones
keep their own kstat views, so Telegraf running in the global zone *cannot*
monitor the NFS activity -- server or client -- in a local zone. I suppose I
could do something horrible, like `zlogin` into the NGZ and parse the output
of `kstat(1m)`, but doing things cleanly, it's not possible. So if NGZ NFS is
a big thing to you, you're stuck using per-zone Telegrafs.

You can choose which NFS protocol versions you require, and then you just pick
your kstats like all the other plugins. The NFS version is a tag.

<script src="https://metrics.wavefront.com/embedded/QWYfDZnQSQ/js"
id="wavefront-embedded-QWYfDZnQSQ" width="700" height="300"></script>

```sql
WQL> rate(ts("dev.telegraf.nfs.server.*", nfsVersion="v4"))
```

## Packages

This just counts the number of packages which can be upgraded. It works in a
`pkg(5)` or `pkgin` zone, but can't see other zones. I plan to make it able to
see into NGZs from the global, but I haven't got round to it yet.

Here you can see me upgrading my dev server.

<script src="https://metrics.wavefront.com/embedded/DkSnTyfwYX/js"
id="wavefront-embedded-DkSnTyfwYX" width="700" height="300"></script>


```sql
WQL> ts("dev.telegraf.packages.upgradeable")
WQL> events(name="patch cube")
```

The caveat here is that something needs to continually refresh the package
cache. For me, Puppet does that as part of its normal duties.

## SMF

This shells out to `svcs(1m)` to give you an overview of the health
of your SMF services. It runs `svcs` with the `-Z` flag, via `pfexec`, which,
assuming the user running Telegraf has the `file_dac_search` privilege, lets
it see the states of services in all non-global zones. Here's just one NGZ,
seen from the global. You can, of course, specify which zones you're
interested in, and specifying none gets you the lot.

<script src="https://metrics.wavefront.com/embedded/dNbS8yyBQ1/js"
id="wavefront-embedded-dNbS8yyBQ1" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.smf.states", zone="cube-pkgsrc")
```

You can also get more detailed breakdowns of errant services. Normally I
present this data as a table, but that won't work here.

<script src="https://metrics.wavefront.com/embedded/sXr43DY9NN/js"
id="wavefront-embedded-sXr43DY9NN" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.smf.errors", zone="cube-pkgsrc")
```

If you don't want the detailed service view, or you're worried applying
service names as tags will cause high cardinality, you can set
`generate_details = false` and not get these metrics.

## ZFS ARC

This plugin just presents the stats you get from `kstat -m zfs -n arcstats`.
There are too many of those to list here, and I don't run this plugin as I
don't have anything with a ZFS ARC right now so you don't even get a chart.
Sorry!

## Zones

The zones plugin gathers the uptime and the age of every zone on the box. The
former comes from the `zones` `boottime` kstat, and the latter is worked out
by looking when the relevant file in `/etc/zones` was modified.  I haven't
found uptime enormously useful, but I like the age stat because I like to
exercise my infrastructure creation, and it shows me any zones that haven't
been rebuilt in too long.

Each point on these metric paths comes with a bunch of tags like brand, IP
type and status. Filtering and grouping on these can turn up lots of useful
and interesting data.

I display this as a pie chart, but Wavefront can't share those either.

<script src="https://metrics.wavefront.com/embedded/z9mF2cL0wd/js"
id="wavefront-embedded-z9mF2cL0wd" width="700" height="300"></script>

```sql
WQL> count(ts("dev.telegraf.zones.status"), brand)
```

## Zpool

Zpool is another run-external-program cop-out. For starters it parses `zpool
list`, and offers up the various fields as numbers. Here you can see me
alerting off >80% capacity.

<script src="https://metrics.wavefront.com/embedded/y9Gck0SvMp/js"
id="wavefront-embedded-y9Gck0SvMp" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.zpool.cap")
```

There's a synthetic "health" metric too. This converts the health of the pool
to a number. I put the mapping in my chart annotation:

```
0 = ONLINE, 1 = DEGRADED, 2 = SUSPENDED, 3 = UNAVAIL, 4 = unknown
```

and as you can see from this chart, I alert off non-zero values. Here's an
errant pool being fixed:

<script src="https://metrics.wavefront.com/embedded/RfrYhrCFv3/js"
id="wavefront-embedded-RfrYhrCFv3" width="700" height="300"></script>

```sql
WQL> ts("dev.telegraf.zpool.status")
```

You can also turn on "status" metrics. This takes the output of `zpool status
-pv <pool>` and turns it into numbers. As well as counting the errors in each
device of the pool, it also plots the time since the last successful scrub
(for easy alerting off not-scrubbed-in-forever pools), and plots the time of a
resilver scrub. The actual elapsed time probably isn't so useful, but it being
non-zero certainly can be.

Here's a pool being scrubbed. The purple line (left axis) is the time since it
was scrubbed, the blue line (right axis) the time spent scrubbing.

<script src="https://metrics.wavefront.com/embedded/NZJ6fZYmqR/js"
id="wavefront-embedded-NZJ6fZYmqR" width="700" height="300"></script>

```sql
WQL> ts("zpool.status.scrubTime", name="rpool")
WQL> ts("zpool.status.timeSinceScrub", name="rpool")
```

## Making it Work

[The repo](https://github.com/snltd/illumos-telegraf-plugins) has full
instructions on how to build a version of Telegraf with these plugins
installed, and there's [everything you need to run it under
SMF](https://github.com/snltd/illumos-telegraf-plugins/tree/main/smf).

## The Future

I have a couple more plugins not quite ready for production. One mimics
`prstat` to give you charts of resource consumption by process; another is
specifically written to run inside a SmartOS NGZ, reporting mostly on the
proportions of allocated resources currently being consumed.

I think I currently measure everything I'm interested in, but I see telemetry
as a work forever in progress, and I constantly refine not only my alerts and
dashboards, but also my metric collection.

If you wish to improve these plugins, or add more, please do fork [the
repo](https://github.com/snltd/illumos-telegraf-plugins) and raise a PR.  If
you find bugs, or wish improvements that you aren't able to make yourself,
[open an issue](https://github.com/snltd/illumos-telegraf-plugins/issues/new)
and I'll have a look.

[^1]: Actually, the first thing a lot of people seem to look for is load
      average, but if you think that's a good way to monitor a system, look
      elsewhere.

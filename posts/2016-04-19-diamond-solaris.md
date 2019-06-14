---
title: "Wavefront and Solaris 02: Collecting Metrics, or Adventures in Kstats"
date: 2016-04-19
tags: [Solaris, Wavefront, Diamond, kstat]
category: Wavefront
---

So, [I have a Wavefront proxy running on
Solaris](/post/2016-03-30-wavefront-solaris): now I want to get
metrics into it.

## Not Collectd

For a long time, `collectd` has been the standard way of collecting
telemetry and pushing to an endpoint, usually Graphite.  Wavefront can
intepret the Graphite wire format, so that should the be path of least
resistance.

Oracle do not provide us with a conveniently installable Collectd
package. But given the dependency chains which can result from
various plugins, this may not be a bad thing. (If you want a giggle
about how someone somewhere thinks Unix systems ought to be built,
have a look at the dependency chain for the Ubuntu `collectd`
package.)

Collectd 5.5 builds easily enough on Solaris though, and I soon had it
up and running, sending data to my Wavefront proxy in Graphite
format. You'll get all the basics: CPU, memory usage, disk
consumption and throughput, network packets sent and recieved. It
works perfectly well.

Collectd feels, I think, a bit old, clunky, and arcane. It has real
problems reconnecting when its endpoint goes away. And, it doesn't
have stellar Solaris support. Some of the collectors simply refuse to
work, others, like CPU, send limited, whilst the old `du/df` disk-space
plugin haemorrages crap when it sees a box with a couple of hundred ZFS
datasets.

## Diamond

With this in mind, and fancying learning something new, I decided to
have a go with [Diamond](https://github.com/python-diamond/Diamond).
This is a more modern approach to the same problem. It's written in
Python, and it's very modular, so it ought to be easy to extend. But,
it's not without problems.

## Problem 1: Installing Diamond

Installing Diamond on Solaris is easy:

```cmd
# pip install diamond
```

Except it isn't if you don't have a C compiler. Diamond requires
`psutil` (even though it doesn't actually work properly: more later)
and the `psutil` module needs to compile itself. That's fine for a
dev box, but even in the age of the 2Gb base install, I am *not*
putting GCC or Forte (God, I'm old) on machines just to install a
single Python module

## Problem 2: Nothing Works

Trying out the standard collectors didn't go too well. In short:

* `CPUCollector`: this works, but it's pretty basic, just giving you
  the user, system, and idle times for each VCPU. So nothing on
  interrupts, cross-calls, context-switches or any of that good
  `mpstat` stuff.
* `MemoryCollector`: doesn't work at all, and doesn't even fail
  gracefully. For some reason the `psutil` implementation seems
  incomplete on Solaris. It probably uses `/proc` too.
* `NetworkCollector`: this doesn't work, for the same reasons, and
  with the same bad error-handling, as `MemoryCollector`.
* `LoadAverageCollector`: this works, but who cares? Load average is
  rubbish.
* `DiskUsageCollector`: doesn't work because it uses
  `/proc/diskstats`, which we obviously don't have.
* `DiskSpaceCollector`: doesn't work in the global zone when running
  as a non-root user with standard privileges, because delegated
  datasets are not visible from the global. But, I don't really care
  about *filesystem* usage, as everything is in ZFS datasets. For
  the most part, I'm more interested in the capacity of the pools, and
  this can't do that.
* `VMStatCollector`: doesn't work because, guess what? It uses
  `/proc`. (And even if it didn't, Linux's `vmstat` is different to
  the one in Solaris.)
* `NFSCollector`: doesn't work. You know why.

Well, I'm up slack alley with that lot aren't I? And there's nothing
for ZFS, or zones, or SMF, or FMA, or pretty much anything that I
might conceivably want to alert on.

## Problem 3: Virtualization

One of the great things about zones is that a non-global-zone (NGZ), is
fully visible from the global. This gives you a different way to perform
many housekeeping jobs. Why run dozens, or hundreds of identical jobs in
all the zones on a box when you could run the same job once from the
global?

As you think more deeply about telemetry on a zoned system, you find
yourself dividing metrics down into particular scopes.

For instance, all zones see the same physical disks, so monitoring disk
I/O across a hundred zones gives you a hundred copies of the same
metric. But counting failed services *needs* to be done per-zone.
You can't run an NFS server from an NGZ, but you can see the kstats
for one running in the global.

Things get more complicated in a multi-tenant system: what metrics do
your users care about? Will global things visible from their NGZ confuse
them?

If you're running the system, you can see how much of their
allocated disk space your clients are using, but why do you care --
it's no skin off your nose if they fill their quota. How about
VNIC throughput? That might be relevant to you *and* your tenants..
As so often we find that the technological problem of recording this
stuff is a small part of the whole.

## Enough Problems!

I know a little bit of Python, and I know a bit about Solaris internals
and the user interfaces to them. Get writing!

## Solution 1: Installing Diamond -- use `tar(1)`

To get round Python dependencies, need for a C compiler etc, I took the
"Omnibus" approach that I use to deploy Puppet.

That is, I compiled Python 2.7 from source, installed it in
`/opt/diamond`, then installed the PIP in there. I packaged up that
directory (actually I `tar`red it: that's still a package, ask
Slackware) and now I can drop it into any box or zone, however minimal.
This also has the nice side-effect of meaning that changes to the system
Python can't break your Diamond install.

If I were doing this on SmartOS I'd make a proper `pkgin` package: it's
not a lot more effort than a tarfile. IPS, though, is way too much of a
PITA.

## Solution 2: Nothing Works -- use `kstat(3kstat)`

Solaris does have a `/proc` filesystem, but it is quite a pure
interface, only exposing `proc`ess information, rather than Linux's
"chuck anything in there, in any format, possibly even binary, and
oh, you can write to some of it" approach.

Instead, we have kstats. Kstats are kernel counters, exposed to userland
by `/dev/kstat`, which appears in any kind of zone. Solaris ships with C
and Perl libraries which provide simple access to kstats, and bindings
exist for a number of other languages. Fortunately for me, [someone
already made a Python binding](https://github.com/imp/kstat), and
[someone else made it better](https://github.com/pyhedgehog/kstat).

Kstats are good and bad. First, the good. They are quick to access. They
are very accurate: values are given with a high-resolution
timestamp. They give you deep introspection -- look:

```cmd
$ kstat | wc -l
   67150
```

That's a lot of information for one host. I wouldn't want the bill for
chucking a datacentre full of those into Wavefront every second.

The bad, now. kstats aren't documented. This is because they are not
considered a stable interface. They can change. They can go away, be
renamed. and new ones can appear. (It's actually not hard to add your
own.)

This lack of documentation also makes it difficult to work out what
a lot of them are. Off the top of my head I couldn't tell you the
exact meaning of `sdpib:0:sdpstat:sdpOutUrg`, and finding out might
mean a trip deep into [the
source](https://github.com/illumos/illumos-gate).  (Not the Solaris
source, obviously. Up yours, Oracle.)

The final difficulty with kstats is that, in statsd speak, some are
counters, and some are gauges. For instance, the number of pages in the
free list is a gauge: it goes up and down.

```cmd
$ while true; do; kstat -p unix:0:system_pages:pagesfree; sleep 1; done
unix:0:system_pages:pagesfree   234875
unix:0:system_pages:pagesfree   235084
unix:0:system_pages:pagesfree   234786
unix:0:system_pages:pagesfree   234924
unix:0:system_pages:pagesfree   234905
```

Whilst the bytes written to a disk is a counter which only ever goes up:

```cmd
$ while true; do; kstat -p cmdk:2:cmdk2:writes; sleep 1; done
cmdk:2:cmdk2:writes     1488501
cmdk:2:cmdk2:writes     1488509
cmdk:2:cmdk2:writes     1488518
cmdk:2:cmdk2:writes     1488526
```

Others, like `cpu_info:0:cpu_info0:chip_id` are constants, and
things like `cmdkerror:0:cmdk0,error:Model` are constant strings.  All
of this is fine, and makes good sense, but it's not possible to
programatically tell which kstat is of which datatype, and sometimes
difficult to work it out from man pages and source code.

I also, at the time of writing, am ambivalent about the correct way to
deal with the counter kstats. When you get a group of kstats, that
group includes `snaptime`, which is a high-resolution timestamp
telling you exactly when the kstats had the values you see. If you
have Diamond remember the last value of `snaptime`, it's therefore
trivial to calculate and send deltas rather than absolute values.
Because, that's what we want, right? Hmmm, weeeeelll, it *could* be.

Take traffic through a NIC. My immediate reaction is to think rate is
what matters. But, if I want to see which VNIC has used the most
traffic, or get an absolute value for usage over a 24h period, I have to
do some work summing all those little deltas. (Though [the Wavefront
CLI](https://github.com/wavefrontHQ/ruby-client), particularly with
its `human` formatter, makes this relatively simple, especially if
you know a little bit of `awk`. And if you don't know a little bit
of `awk`, learn a little bit of `awk`.)

If I send the counter, these tasks become trivial, and displaying
the rate on a graph is as simple as wrapping the timeseries in
Wavefront's `deriv()` function. Or, maybe I'll decide that looking
at the steepness of the unmodified counter line gives me a better
sense of how all my NICs are doing. I think the raw value gives you
flexibility, which is good.  But, hasn't Collectd set the precedent?
Don't people expect to get rates? It's hard to decide what's right.

Using the kstat `snaptime` lets you calculate very, very accurate
rates, but does that really matter? Most people are used to using
Graphite, with 15-second intervals, and everything most likely
rounded to an integer.  And, `snaptime` might not be what you think
it is. Are you thinking it's the clock time? Seconds since the
epoch?  I bet you are, but you're wrong. It's the time elapsed since
a point marked by its friend `crtime`. This is also a
high-resolution timestamp, and is time the kstat was created.
Relative to... errr.... yes.

[The source
shows](https://github.com/illumos/illumos-gate/blob/master/usr/src/uts/common/os/kstat_fr.c#L1084)
us that `crtime` is set to the value of `gethrtime()`, and [the
`gethrtime` man page](https://illumos.org/man/3c/gethrtime) says
that:

> Time is expressed as nanoseconds since some arbitrary time in the
> past; it is not correlated in any way to the time of day

so, good luck converting your kstat `snaptime`s to anything meaningful.

It's not ideal for our particular application, but I can see why
things were done this way. Calulating a rate since `crtime` gives
you a (probably pointless) "since boot" type summary, like the first
line of `vmstat` output. Clearly kstats and their `snaptimes` were
implemented with things like `vmstat` and `mpstat` in mind: accurate
"live" deltas, not pinned to a fixed point in time. But feeding data
into a telemetry system mandates that you fix it to timestamps.
We're at odds, aren't we?

## New Shiny! Point Tags

I particularly like Wavefront's ability to apply any number of
`key=value` tags to a point. This lets you build up
multi-dimensional data.  Tags are fully integrated in the query
language, so you can use them for all manner of selection and
filtering. They're also handy markers, giving clues that might be
useful in further investigation.

At my current client's site, we have a Puppet reporter which, at the
end of each run, pumps all the statistics for that run (times,
change and error counts etc.) into Wavefront. It tags all these
points with the release of the Puppet code, so if we see, say, a
spike in run time, or something starts making flappy changes, it's
easy to know which Puppet release caused the problem. We can also
easily find any machines which aren't on the same release but should
be.

Starting simple, one of the first Solaris collectors I wrote was to
[monitor disk
errors](https://github.com/snltd/sunos-diamond-collectors/tree/master/collectors/sunos_disk_health).
A lot of people don't like Solaris's SYSV `c0t0d0s0` way of
identifying disks, but kstats don't even do that: they use the
kernel module to derive the disk names, and call them things like
`cmdk0` (IDE or SATA, *obviously*), or the somewhat more logical `sd1`
for SCSI or SAS.  These names are not particularly meaningful, and I
wanted a better way of knowing which disk was on the blink when my
`disk_health` alerts fired.

In among the `cmdkerr` or `sderr` kstat bundle is the serial number
of the disk. "Wouldn't it be nice", I thought (knowing full well
most tech disasters begin with just those words), to tag the points
so you can more easily idenfity the errant disk? Which brings us to:

## Problem 4: Diamond does not Understand Point Tags

Up to this point, I was using the OpenTSDB handler (output plugin)
for Diamond. OpenTSDB does have a concept of tags, but they're
different to point tags, so it was time to...

## Solution 4: Write a Wavefront Handler

Wavefront's wire format is, of course, clearly documented, and very
close to OpenTSDB's, so I began with the code for the OpenTSDB
handler, and soon [ended up with a working Wavefront
equivalent](https://github.com/snltd/Diamond/blob/24583dc41fba9007e545b44e4ed982ce8025f033/src/diamond/handler/wavefront.py).
There's not a lot to it: with all of these things you only ever end
up poking a simple string into a socket.

Next there were some [pretty minor changes to the Diamond metrics
code](https://github.com/python-diamond/Diamond/compare/master...snltd:feature/wavefront_handler)
to give us an extra argument for defining point tags. Diamond's code
is simple, and well structured, so making changes isn't hard at all.

Now, I was able to return to my collector, pull each drive's serial
number out of the kstats, and apply it to every error point for the
relevant disk.  This makes it far easier to identify the exact disk
which is reporting errors.  I also tag (when I can: not all devices
expose the same information) by vendor and model, because in
large-scale deployments it might be interesting to see whose devices
show the highest error rates. Or maybe the highest throughput. Or
anything else you can think of.

Now, when you hover over a point on a disk error chart, you see:

![point tags](/i/wf_disk_point_tags.png)

It may not be the most useful thing in the world, but I hope that is
reasonably illustrative of point tags. I think they are a powerful
feature of Wavefront, and I expect to get a lot of value from them
in the future. At the moment, it's a little hard to know how best to
get data tagged, and I hope the code I've written is a step along
the road.

My Diamond extensions allow you to tag per-point, in the collector
code, or *en-masse*, tagging everything from a single collector, or
even everything from the whole of Diamond.

I'd like to go even further, and be able to apply point tags
en-masse in the proxy, perhaps using regexes, but that's one for
Wavefront.

At the time of writing, all of this work is [sitting in a PR in
Diamond's
repository](https://github.com/python-diamond/Diamond/pull/480). I
don't know when, or if, it will be merged into master, but if you
wish to use it now, you can clone from [my
branch](https://github.com/snltd/Diamond/tree/feature/wavefront_handler),
and if you can make it better, piggy-back off my PR.

## Postscript: There is no Solution 3

The observant reader (yeah, right) may have noticed that I posed
four problems but only three solutions; the outstanding being
"from where to collect what" on a heavily virtualized system.

I'm still mulling it over. Still changing my mind, and still
experimenting with different approaches.

Most of the new collectors I have written so far are for a
full-machine overview: that is, they are intended to run in the
global zone.  Others adapt their behaviour depending on their view
of the system.  This seems to be working pretty well, but the
requirements for a multi-tenant system are different. As always with
open source software, I'm scratching my own itch, and that itch is
mostly a server where all the zones are mine.

I do have a couple of instances in the Joyent Public Cloud, for
which I've written [a collector solely for use in a SmartOS
zone](https://github.com/snltd/sunos-diamond-collectors/tree/master/collectors/smartos-zone).
That collector is to help keep check on how close you are sailing to
the limits of the instance. It is instrumenting the site you are
looking at now.

Solaris's introspection goes very deep: it's always been a very
observable platform, and it's a lot of fun feeding all those numbers
into Wavefront. I've always been interested in system interals, and
it's quite exciting to be able to properly visualize things like
latency, saturation, paging, batching of writes and anything else
that I can think of. I like to stick a bunch of different metrics on
a single chart, wrap them all with the `normalize()` function, and
see how work is distributed throughout the system: see the network
throughput spike, then the CPUs start processing data, and handing
the results to disk; and I can watch how the SSD ZFS cache device
interacts with, and behaves differently to the spinning disk where
the data ends up.

It's informative and fun to generate more and more load on the box
and watch how things fail. Or, rather, how things behave differently
in order *not* to fail. That, I think, would make for a good
article in the future.

Next time, though, I'm going to have a crack at wiring DTrace up to
Wavefront. If you think there are too many kstats to choose from,
wait until you see what DTrace offers.

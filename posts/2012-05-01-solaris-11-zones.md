---
title: "Solaris 11 zones part 1"
tags: [Solaris, Solaris 11, zones]
date: 2012-05-01
category: Solaris
---

Throughout the lifespan of Solaris 10, zones got more flexible and more
complicated, but without the fundamentals changing.

In Solaris 11, however, things are different. The commands are still
`zonecfg` and `zoneadm`, and many of the subcommands are as they were,
but things have changed at a lower level. ZFS and SMF integration are
far tighter, Crossbow is used much more, and, of course, the packaging
system has changed, which means things have to happen in a new way. In
this article I'm going to try to explain the major changes. There's a
lot of automation in zone creation now, and I haven't yet found a decent
technical document which explains it, so most of what follows I've
worked out myself, mostly by watching what happens with `dtrace`.

# Networking

I'm starting with this because I think it's the best change. You can
still have shared IP instance zones, but now we have the power of
Crossbow, there isn't a persuasive case for using them. Zones are
created with their own full IP stack, which implies a VNIC. But here's
the new thing: *the VNIC doesn't have to exist in the global zone*. The
idea behind this is that zones can be moved between systems, so the
receiving host doesn't need to have anything done to it: you just drop
the new zone in, VNIC and all, and it works. It also has the nice
side-effect of not leaving an unused VNIC hanging about when a zone is
removed.

So if you just create a zone `newzone` with the `ip-type=physical`
property, and no other information, you'll find that once the zone is
installed and configured, it has a single NIC called `net0`, and your
global zone's primary interface will have gained a VNIC called,
sensibly, `newzone/net0`.  You'll only be able to see that through
`dladm` - it's not in `ifconfig`'s output, and you won't find it via
`ipadm`, as everything other than the virtual link belongs to the zone.

All this "magic" is done by a new zone property, called `anet`. It has
many properties, but the main ones are `lower-link`, which specifies the
(usually) physical link the VNIC will be created on top of. This
defaults to `auto`, which so far as I can tell means the primary
interface. As I said, the link is usually physical, but you can also use
aggregates, which is nice. `linkname` specifies the name of the link
inside the zone, and it defaults to the aforementioned `net0`.

Now, giving away a whole IP stack, particularly in a multi-tenant
system, comes with risks. For instance, our guest has access to `ipadm`
and may change his address to something which clashes with another
system on our network. So, network security has been beefed up, and is
managed with new zone properties.  `allowed-address` is simply an
address, list, or range of addresses to which that interface may be
configured. If a user in the zone attempts to set any other address,
they'll be told

    ipadm: cannot create address: Permission denied

If you set the `anet`'s `configure-allowed-address` property, then the
interface will be reconfigured to that address on every reboot, whatever
it may have been when the zone went down.

Further security is provided by the `link-protection` property. This
works only if `allowed-address` is set, and can be set to one or more of
the `dladm` protection properties - `mac-nospoof`, `ip-nospoof`,
`dhcp-nospoof`, and `restricted`. The first two mean that any packets
whose source MAC or IP do not match those configured in the zone
properties, are dropped.  `restricted` discards packets which aren't
IPv4, IPv6, or ARP. I'm not looking at DHCP today, since I don't use it.

It's possible to limit the bandwidth consumed by the zone with the
`maxbw` property, and you can set a priority for the zone's VNIC with
the `priority` command. You may notice a lot of these properties have
equivalents in `dladm`. That's because whether we're using `dladm` or a
zone with an exclusive IP instance, we're still referring to a VNIC.
Like I said - Crossbow is everywhere now.

The old `net` property still exists if you want to use it. It's as it
always was but for the addition of the `allowed-address` property. If
you want the `dladm` security and flow management, you have to use
`anet`. I don't really see any reason other than legacy to continue
using `net`.

# Filesystems

Back when zones first appeared we used to have to put their roots in UFS
filesystems because UFS was all we had. Then ZFS came along, we moved
our zone roots to ZFS so we could snapshot them, then later found that
some patches wouldn't work unless the zones were on UFS roots. So we
moved them back. Now UFS seems about as current as 5.25" floppies, and
zone/ZFS integration is tight.

When you create a zone `newzone`, the following ZFS datasets are
created:

```
NAME                                           MOUNTPOINT               ZONED
rpool/zoneroot/newzone                         /zones/newzone             off
rpool/zoneroot/newzone/rpool                   /rpool                      on
rpool/zoneroot/newzone/rpool/ROOT              legacy                      on
rpool/zoneroot/newzone/rpool/ROOT/solaris      /zones/newzone/root         on
rpool/zoneroot/newzone/rpool/ROOT/solaris/var  /zones/newzone/root/var     on
rpool/zoneroot/newzone/rpool/export            /export                     on
rpool/zoneroot/newzone/rpool/export/home       /export/home                on
```

Note the strong use of `zoned` datasets. This means the zone completeley
owns them, so snaphots and datasets, can be created from the zone, and
any other ZFS operation carried out there as well.  The mountpoint shown
above refers to the mountpoint inside the zone.  Zoned datasets are
still visible from the global zone, under the zone's mountpoint,
whenever the zone is running. (`/` and `/var` are always mounted, even
when the zone is halted.)

I'm not sure I'm entirely comfortable with something creating
filesystems all over the place, and there seem rather a lot of them to
me. I certainly don't want `/export/home` creating for each zone.

`dataset` has gained a new property, `alias`, which lets you make any
old delegated dataset appear to the zone as a proper zpool. For
instance, in the global zone:

```cmd
# zfs create space/newzone_data # zonecfg -z newzone_data
zonecfg:newzone> add dataset zonecfg:newzone:dataset> set
name=space/newzone_data zonecfg:newzone:dataset> set alias=zdat
zonecfg:newzone:dataset> end
```

Then boot the zone, log into it and you'll see:

```cmd
root@newzone:~# zpool list
NAME    SIZE  ALLOC   FREE  CAP  DEDUP    HEALTH  ALTROOT
rpool  24.9G  20.2G  4.72G  81%  1.29x    ONLINE  -
zdat   1.58T  1.44T   137G  91%  1.05x    ONLINE  -
```

Pretty nifty eh? In Solaris 10 the `space/newzone_data` would have
appeared as a ZFS filesystem, not a pool.

# Zone Administration

`admin` is a new property that integrates with RBAC to let you grant
administrative rights to normal (i.e. non-root users). For instance, to
give myself the ability to log into `newzone` with `zlogin`, and to
stop, start and reboot that zone, I would do the following in `zonecfg`.

```cmd
zonecfg:newzone> select admin user=rob
zonecfg:newzone:admin> set user=rob
zonecfg:newzone:admin> set auths=login,manage
```

As I said, RBAC is doing the magic, so we need to "Simon says"
everything with `pfexec`.

```cmd
$ zlogin newzone
zlogin: You lack sufficient privilege to run this command (all privs required)
$ pfexec zlogin newzone
[Connected to zone 'newzone' pts/12]
Oracle Corporation      SunOS 5.11      11.0    November 2011
#
```

And I'm in as root. It won't work on other zones though:

```cmd
$ pfexec zlogin tap-ws
zlogin: rob is not authorized  to login to tap-ws zone.
```

If you check `/etc/user_attr` you'll see how this works (I've broken the
line to preserve the page format.)

```
rob::::type=normal;auths=solaris.zone.login/newzone,
solaris.zone.manage/newzone;profiles=Zone Management;roles=root;
defaultpriv=basic,dtrace_kernel,dtrace_proc
```

I'm not sure how useful this is, as I wouldn't generally want my zone
tenants anywhere near my global zone, but if you're a big RBAC shop,
this may be right up your street. Someone needed it, or it wouldn't be
in.

# Resource Control

I don't think the original incarnation of zones had any resource control
at all. Gradually things like CPU and memory caps crept in, and that was
good.  I'm fairy sure that pretty much every kind of resource control
was covered in the later Solaris 10 releases, so there wasn't a whole
lot to add to this.

`max-proceses` is new however: it's pretty much an extension of the old
`max-lwps` global and caps, as you would expect, the number of processes
that can be in the zone's process table at any one time.

# Observability

In Solaris 10 all we had to monitor zones was the `-Z` option to
`prstat`.  It was helpful, but given that observability is one of the
things which sets Solaris apart from other, more hobbyist, operating
systems, it wasn't quite good enough. Now we have `zonestat`.

`zonestat` runs in intervals, like `mpstat` or `vmstat`, an by default
it prints  a row for each zone informing us how much CPU, physical
memory, virtual memory, and netowrk bandwidth that zone has consumed
over the previous interval.

I won't just regurgitate the man page, read it for yourself, but a
couple of things I particularly like are the `-p` flag, which forces
colon-separated parseable output for your scripting pleasure; and the
fact that unlike the traditional `*stat` tools, it waits to begin
output, not bothering with that pointless, misleading first line.

Like `prstat`, `zonestat` is a tool which superficially looks simple,
and defaults to far and away the most useful format, but has a lot of
hidden depth. Read the `man` page.

It's interesting to compare where Oracle have taken Zones with what
Joyent are doing with SmartOS VMs. Joyent, as one might expect given
then personnel, have developed phenomenal instrumentation far more
powerful than zonestat, and they also give you the ability to properly
DTrace in local zones. Solaris 11 can't really do that. The DTrace
functionality is pretty much the same as in the latest Solaris 10
releases, which is to say that by default, you get no DTrace at all in a
zone:

```cmd
# dtrace -l
 ID   PROVIDER            MODULE                          FUNCTION NAME
```

To get some kind of tracing capability, you need to give the zone
special privileges by setting `limitpriv` via `zonecfg`. Let's have a
look what the DTrace privileges are:

```cmd
$ ppriv -l | grep dtrace
dtrace_kernel
dtrace_proc
dtrace_user
```

Now, for (I hope) obvious reasons, you're not going to get
`dtrace_kernel` in a local zone. (Try it, it'll just tell you it's not
permitted.) You can have the other two though. `dtrace_proc` gives you
the `fasttrap` and `pid` providers; `dtrace_user` gives you `profile`
and `syscall`.  I think `pid` and `syscall` are the most useful
providers anyway, so it's much better than nothing.

Turn the privileges on through `zonecfg`.

```cmd
zonecfg>set limitpriv=default,dtrace_proc,dtrace_user
```

Now let's count the probes. These commands are on global and local zones
on the same physical host:

```cmd
# zonename
global
# dtrace -l | wc -l
   97272
# zonename
tap-ws
# dtrace -l | wc -l
     620
```

The mis-match there is mostly down to not having the `fbt` provider in a
zone, but even with the probes that are enabled, I've been continually
frustrated trying to DTrace in zones.  (Solaris 10 had fewer probes,
around 400.)

Fortunately, I always have access to the global, so it's not a big
problem, but not everyone has that privilege.

DTrace works great in SmartOS zones though, and I have to say I'm not
hugely confident about the future of DTrace in Solaris 11. I don't think
it'll go, or shrink, but I can't see it growing much. I wish Oracle
would go back to an open Solaris, and start integrating some of the
things the Illumos people are doing. (And vice-versa - I want ZFS crypto
in Illumos!)

I'm digressing aren't I? Probably time to wind things up.

# Fin

That'll have to do for now. I'm working on a piece about the way zones
are installed and configured, the new `solaris` brand, zone boot
environments, and the way the new packaging system works. Should be up
soon.

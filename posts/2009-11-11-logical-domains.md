---
title: "Logical Domains"
tags: [Solaris, virtualization, LDOMs]
date: 2009-11-11
category: Solaris
---

I must begin this article by saying that, in all the Solaris
virtualization work I've done, I haven't found hypervisor level
virtualization particularly useful. That is not a criticism of xVM or
LDOMs, rather it's a praise of zones.

If zones didn't exist, or weren't so powerful or flexible, I know I'd be
using xVM and LDOMs for all kinds of things. I've certainly seen VMWare
used to virtualize Windows and Linux systems to brilliant effect. But, I
*like* the "thin separation" of zones. It's so good to be able to manage
multiple systems in one shot, and a single O/S pretending to be many
O/Ses seems the right solution to almost all my virtualization problems.
At least xVM has the advantage of letting you host multiple OSes.
LDOMs just let you have multiple instances of Solaris 10, which has to
be less useful. (Update: or Solaris 11, obviously.)

Sometimes though, LDOMs are the right way to go. Maybe two groups both
want a cluster. Get them to buy one machine each, domain them, and
cluster the domains. Nice.

In this article I'm going to give a bit of an outline of two kinds of
domain: the primary (which some people call a 'control' domain), and the
guest. You have to have one primary per physical host, because it's what
talks to the hyervisor and makes the domaining possible; the guest is
where you run your applications.  As guest domains don't have dedicated
I/O resources, you'd generally use them just for separation. Don't put
I/O intensive things like databases in them! There are also I/O domains
and service domains, which allow you to farm out the distribution of
resources from the primary to dedicated domains. I'll leave those for
another day.

First, you've got to be aware that the LDOM management software is picky
about patches and machine firmware versions. Check the README, or you'll
end up in a proper pickle! Also make sure you've got the standard
Solaris LDOM packages installed. These should be installed on
`sun4v` machines even in a minimal install, but it never hurts to
check.

```cmd
$ pkginfo | grep SUNWldom
system      SUNWldomr                    Solaris Logical Domains (Root)
system      SUNWldomu                    Solaris Logical Domains (Usr)
```

Installing the LDOM Management software couldn't be a lot easier. Just
unpack it (the version I'm using is 1.2), and do

```cmd
# LDoms_Manager-1_2/Install/install-ldm -d none
```

Because my Jumpstart server already locks my boxes down as hard as
nails, and I dislike JASS (I'll tell you why one day), I'm using the
`-d` flag to tell the installer not to apply a JASS profile to the
system. If you do an interactive install, this is equivalent to taking
the "Standard Solaris configuration" option.  If unlike me, you're a
conscientious sysadmin, you'll choose "Hardened Solaris configuration
for LDoms".

I told the installer not to launch the LDoms Configuration assistant.
We'll do things by hand to get a better feel for what's really
happening.

The LDOM software is installed in `/opt/SUNWldm`, but if you do a

```cmd
$ which ldm
```

You'll see that the installer has kindly symlinked the binaries into the
normal superuser `$PATH`.

We'd better check that we have the services we need, and find out what
they're doing.

```cmd
$ svcs "*ldom*"
STATE          STIME    FMRI
disabled       14:30:18 svc:/ldoms/vntsd:default
online         14:25:09 svc:/ldoms/ldmd:default
```

The `vntsd` service shouldn't be up yet. In fact, if you try to start
it, it will fall into maintenance state, and you'll get a line in
`messages` to the effect of

```
Error opening VCC device control port:
```

We'll come back to that later. So what's the ldmd service doing?

```cmd
$ svcs -Hp ldoms/ldmd
online         13:48:43 svc:/ldoms/ldmd:default
               13:48:42     4209 ldmd
```

Not a lot. Just running the `ldmd`, which is the "management daemon".
It's the glue between the hardware hypervisor and the domains.

```cmd
# ldm list
------------------------------------------------------------------------------
Notice: the LDom Manager is running in configuration mode. Configuration and
resource information is displayed for the configuration under construction;
not the current active configuration. The configuration being constructed
will only take effect after it is downloaded to the system controller and
the host is reset.
------------------------------------------------------------------------------
NAME             STATE      FLAGS   CONS    VCPU  MEMORY   UTIL  UPTIME
primary          active     -n-c--  SP      16    8064M    0.1%  1h 25m
```

From the top, the notice is a clue that, kind of like a cluster, you have to
go into "configuration mode" and later commit the configuration changes
to the system. You can see what configuration you're using with the
`ldm list-config` command.

```cmd
$ ldm list-config
factory-default [current]
```

Back to the `ldm list` output, and the bottom line shows us we have a
single domain, &quot;primary&quot; to which is currently assigned all of
the physical machine's 16 VCPUs and 8Gb of RAM. (I'm using a fairly
low-spec T2000.)

The primary domain is also known as the **control** domain.  You have to
have one of these, and it's where you create and administer all your
other domains - the ones that run your apps and do some work.  It's
also the source of your all-important console access. That is, it's the
one that you get to through your ALOM, and it runs the terminal
concentrator that lets you access the consoles of all the other domains.

Your primary domain should be minimal and as secure as you can make it.
Strip it right down. Turn everything off. As I said, all it does is
manage the other domains, so it won't need much in the way of resources.
All it needs is CPU and a couple of GB of RAM. Note that the following
commands will all trigger the notice we saw above. That's fine.

```cmd
# ldm set-mem 2G primary
# ldm set-mau 1 primary
# ldm set-vcpu 4 primary
```

Because initially all hardware resources were assigned to the primary
domain, the commands above effectively *remove* them. If you try to
remove all but one of the CPU cores, `ldm` will complain that that
leaves an orphaned MAU. This makes sense, as each core has its own MAU.
That's why I had to do the `set-mau` commands before I set the CPUs.  A
single CPU core on a T2000 is four VCPUs, hence the `4`.

Returning to the `ldm list` output above, the `STATE` of the primary
domain is always going to be active. The `n` and `c` flags show that the
domain is &quot;normal&quot; and a control domain, respectively. `CONS`
shows us the domain's console. In this case, the SP.

It's the job of the control domain to virtualize all the system's
resources and present them to the other domains. The first thing to
present is a console. This is done via the VCC, or Virtual Console
Concentrator. It's kind of like a Cyclades in software. To make a VCC we
need to decide what ports to use, what to call it, and what domain it
will be in. Convention seems to be to use ports 5000 to 5100, and as
it's going to be in the primary domain, we'll call it `primary-vcc`.

```cmd
# ldm add-vcc port-range=5000-5100 primary-vcc primary
```

The domains will also need some network connections. I've cabled up two of
the e1000g ports on my T2000. e1000g0 is on the `10.10.8.0` subnet, and
e1000g1 is on `10.10.4.0` I'm going to put a virtual switch on each of
those NICs, named in a way that identifies them. The syntax is similar
to the `add-vcc` command. Again, the virtual switches belong to the
`primary` domain.

```cmd
# ldm add-vsw net-dev=e1000g0 primary-vsw-10108 primary
# ldm add-vsw net-dev=e1000g1 primary-vsw-10104 primary
```

So we have a pool of spare CPUs, a pool of spare memory, a terminal
server, and a couple of switches to offer our guest domains. The only
other thing they'll need is I/O.

When you carve up big-iron into domains, you have to give each domain
its own I/O channels so it can access disks or cards. My T2000 only has
two channels, and it supposedly supports up to 32 LDOMs. Obviously they
can't all have their own dedicated I/O channel: they're going to have to
share.  This sharing done through a VDS, or Virtual Disk Server.  You
only have one of these in your primary domain, and the way in which it's
created is probably not a surprise.

```cmd
# ldm add-vds primary-vds primary
```

I also need some disk space to assign.

```cmd
# zpool create mirror space c1t0d0s3 c1t1d0s3
# zfs set mountpoint=none space
# zfs set compression=on space
# zfs create space/ldoms
# zfs set mountpoint=/ldoms space/ldoms
```

Later we'll create virtual disks in that ZFS dataset, and make them
available to the guest domains via the VDS.

With the primary domain and all its virtualization interfaces, it's time to
store the configuration. You can give it any name you like.

```cmd
# ldm add-config basic-conf
# ldm list-config
factory-default
basic-conf [current]
```

Because of the close tie between the hardware and the primary domain, a
change to the config requires a reboot. So reboot.

```cmd
# init 6
```

Once we're rebooted, let's see how things look.

```cmd
# ldm list
NAME             STATE      FLAGS   CONS    VCPU  MEMORY   UTIL  UPTIME
primary          active     -n-cv-  SP      4     2G       0.4%  3m
```

Well, that all seems to be as we requested. Note that we've acquired a
`v` in the flags. That denotes the domain is a &quot;virtual I/O service
domain&quot;. That is, it provides the VCC, VSW and VDS we defined
earlier.

But is `ldm` getting the VCPU and MEMORY values from the configuration
we created, or does the domain *really* look like that?

```cmd
$ prtdiag  | head -2
System Configuration:  Sun Microsystems  sun4v Sun Fire T200
Memory size: 2048 Megabytes

$ psrinfo
0       on-line   since 11/10/2009 16:56:14
1       on-line   since 11/10/2009 16:56:15
2       on-line   since 11/10/2009 16:56:15
3       on-line   since 11/10/2009 16:56:15
```

Yep. The hypervisor is only showing this domain the resources we reserved
for it. Cool. How about the virtual switches?

```cmd
# dladm show-dev
vsw0            link: up        speed: 100   Mbps       duplex: full
vsw1            link: up        speed: 1000  Mbps       duplex: full
...
```

(Don't worry about the different speeds. One of the NICs is plugged into
a pretty old switch.)

If you forget how you defined what, `ldm list-bindings` will remind
you.

Back to work. Remember that `vntsd` service from earlier? Well now we
should be able to start it up. It runs the `vntsd` process, which
acts as a terminal server for our LDOMs.

```cmd
# svcadm enable vntsd
```

Now we can create a guest domain. It's pretty similar to creating the
primary domain, but you're looking at the VCC, VSW and VDS from the
other side. My naming convention is to add `l-something-num` on to the
hostname, where `l` denotes a logical domain, `something` denotes the
purpose of the domain, like ws, or db, and `n` is an instance number.
This can get a bit of a mouthful, but it's once you know the code you
can instantly tell that ls-w-01-l02 is logical domain 02 on webserver 01
machine 01, running Solaris, in London.  You may wish to call the same
domain &quot;Kryten&quot;. That's up to you, and I won't judge.

Let's make a webserver domain, with 4Gb of RAM, 4 VCPUs and the
attendant MAO. It'll be on my 10.10.4 subnet, auto-booting, and I'm
going to give it 10Gb of disk space. The hardware resources are easy,
they're just like when we did the primary. The machine I'm working on is
cs-dev-02.

```cmd
# ldm add-domain cs-dev-02-lws01
# ldm add-mau 1 $_
# ldm add-vcpu 4 $_
# ldm add-mem 4G $_
```

Next we'll make a virtual disk in our ZFS pool, and assign it as a VDS
device. This bit's a little bit more complicated. I'll call the disk
domianname-boot, so it's clear what it's for.

```cmd
# zfs create -V 10g space/ldoms/lws01-boot
# ldm add-vdsdev /dev/zvol/dsk/space/ldoms/lws01-boot lws01-boot@primary-vds
```

Note that you're referring to a device file. You can infer from that
that you could just as easily map a real disk, or a real multipathed SAN
LUN, to a guest.

Whatever you map, once the VDS device exists, we can assign it to the
domain as a vdisk,

```cmd
# ldm add-vdisk lws01-boot lws01-boot@primary-vds cs-dev-02-lws01
```

then tell the domain that's the boot disk.

```cmd
# ldm set-variable boot-device=lws01-boot cs-dev-02-lws01
```

If that looks familiar, good. Each LDOM has its own OBP, and `ldm
set-variable` is analogous to `eeprom`. While we're about it, we can
also set the domain to auto-boot, just like we would with a physical
server.

```cmd
# ldm set-variable auto-boot\?=true cs-dev-02-lws01
```

Now we virtually plug the domain into the virtual switch.

```cmd
# ldm add-vnet lws01-vnet-10104 primary-vsw-10104 cs-dev-02-lws01
```

I'm planning to Jumpstart the domains on this server, so each domain is
going to need its own MAC address.

```cmd
# ldm set-variable local-mac-address\?=true cs-dev-02-lws01
```

And we can store the configuration to the system controller. `ldm` likes
to call this &quot;binding&quot;.

```cmd
# ldm bind-domain cs-dev-02-lws01
# ldm ls
NAME             STATE      FLAGS   CONS    VCPU  MEMORY   UTIL  UPTIME
primary          active     -n-cv-  SP      4     2G       0.3%  1h 5m
cs-dev-02-lws01  bound      ------  5000    4     4G
```

There it is. Let's start it.

```cmd
# ldm start-domain cs-dev-02-lws01
# ldm ls
NAME             STATE      FLAGS   CONS    VCPU  MEMORY   UTIL  UPTIME
primary          active     -n-cv-  SP      4     2G       0.4%  1h 6m
cs-dev-02-lws01  active     -t----  5000    4     4G        25%  20s
```

The `t` flag means the domain is in a &quot;transition&quot; state,
and the 5000 in the `CONS` column is the port through which we can
connect to the domain's console. Let's do that.

```cmd
$ telnet localhost 5000
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.

Connecting to console "cs-dev-02-lws01" in group "cs-dev-02-lws01" ....
Press ~? for control options ..
~ ?

{0} ok
{0} ok
```

There you go. Just like being on a proper computer.

```cmd
{0} ok banner

Sun Fire T200, No Keyboard
Copyright 2009 Sun Microsystems, Inc.  All rights reserved.
OpenBoot 4.30.3, 4096 MB memory available, Serial #83503631.
Ethernet address 0:14:4f:fa:2a:f, Host ID: 84fa2a0f.
```

Now you can set up your Jumpstart server in the usual way, and install
Solaris. It's important to know that a virtual disk won't have a target
number in its name, and the first assigned disk will be disk 0 on
controller 0. So, your root partition would be `c0d0s0`.

It's also vital to know that the MAC address shown in the banner doesn't
belong to the domain, it belongs to the virtual switch the domain is on.
(Update: I don't think that's the case any more, but be aware of it just
in case you're using an old version of the softwar.) To get the domain's
real MAC, use

```cmd
# ldm ls-bindings cs-dev-02l-s101
```

and get it from the network section.

# Cheat

I've made [a script that does all this for
you](https://github.com/snltd/virtualization-tools/blob/master/s-ldom.sh),
and I've even [written documentation
too](https://github.com/snltd/virtualization-tools/wiki/s-ldom.sh).

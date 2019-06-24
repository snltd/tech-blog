---
title: "Solaris 10 branded zones in SXCE"
tags: [Solaris, zones, virtualization]
date: 2009-12-16
category: Solaris
---

Nevada release 129 supports Solaris 10 branded zones. I've never really
understood the point of the `lx` branded zones -- there isn't much that
runs on linux but not on Solaris. The Solaris 10 brand, however, seems
more useful. When I write code, I do it on Nevada. My production
machines run Solaris 10, so it would be handy to be able to drop into a
zone on the local machine and quickly make sure things work in that OS
too.

Here's a quick recipe for getting a Solaris 10 zone up and running. I'm
not saying it's best practice or anything, but it does work. The host
machine, `tap` is running Solaris Nevada (SXCE) build 129.

I run a nice, minimal Solaris, so the first thing I had to do was
install the packages that make the brand work. Off to my
`Solaris_11/Product` directory, and

```cmd
# pkgadd -d . SUNWs10brandr SUNWs10brandu
```

You can't jumpstart a zone in the way you can an LDOM, so as far as I
can tell, the only way to install Solaris 10 is from an archive or image
of an existing zone. The man page says this can be all kinds of archive,
including a flar. I gave that a go, but it didn't work for me. I wasn't
in the mood for chasing down why not, so I thought I'd try using a ZFS
dataset.

Incidentally, you can only use Solaris 10 update 8 in your branded zone.
The only x86 installation of that that I had access to was installed in
a VirtualBox on my laptop, so I started it up, logged in, then
snapshotted and sent the root pool across to by nv-b129 machine.
Obviously I had to temporarily enable SSH as root for this to work.

```cmd
# zfs snapshot rpool/ROOT/s10x_u8wos_08a@send
# zfs send rpool/ROOT/s10x_u8wos_08a@send | ssh tap zfs recv \
  space/s10x_u8wos_08a@send
```

Then on tap I set a temporary mountpoint on the received filesystem, and
created the target dataset into which I intended to install the zone.

```cmd
# zfs set mountpoint=/s10_img space/s10x_u8wos_08a
# zfs create space/tap-sol10
# zfs set mountpoint=/zones/tap-sol10 space/tap-sol10
# chmod 0700 /zones/tap-sol10
```

Next I created a zone using the `SUNWsolaris10` template.

```cmd
# zonecfg -z tap-sol10
tap-sol10: No such zone configured
Use 'create' to begin configuring a new zone.
zonecfg:tap-sol10> create -t SUNWsolaris10
zonecfg:tap-sol10> set zonepath=/zones/tap-sol10
zonecfg:tap-sol10> add net
zonecfg:tap-sol10:net> set address=192.168.1.28
zonecfg:tap-sol10:net> set physical=iprb0
zonecfg:tap-sol10:net> end
zonecfg:tap-sol10> commit
```

That's a bit quick and dirty, but it's sufficient to do the install:

```cmd
# zoneadm -z tap-sol10 install -x nodataset -u -d /s10_img
```

Here I'm telling `zoneadm` not to create a ZFS dataset with `-x
nodataset`. (I did it by hand so I knew exactly where it would be. I
don't think that's `zoneadm`'s job.) I tell it where to find the Solaris
image I brought over from the VirtualBox with `-d`, and `-u` tells
`zoneadm` to do a `sys-unconfig` once the zone is installed.

You can also supply a `-v` flag to get a fair bit of debugging output.
It's not particularly interesting though, so I haven't included it here.
Once it's done, check out the zone list.

```cmd
$ zoneadm list -cv
  ID NAME             STATUS     PATH                           BRAND    IP
   0 global           running    /                              native   shared
...
   - tap-sol10        installed  /zones/tap-sol10               solaris10 shared
```

I fired up another xterm and connected to the new zone with `zlogin -C`,
then booted it up from the original window. I worked my way through the
normal set locale, set term type `sysidconfig` stuff and we were good to
go.

```cmd
$ ssh 192.168.1.28 uname -a
SunOS tap-sol10 5.10 Generic_Virtual i86pc i386 i86pc
```

Yeah!

Oh, here's a zones top tip. When you're SSHed into a machine and you
`zlogin -C` doing a `~.` will terminate the SSH session, rather than the
`zlogin`. Do `~~.` and that won't happen. Very useful that.

## Update

I patched my Solaris 10 zone, and found it wouldn't boot. I also tried
installing another zone from another source, and the `zoneadm` failed
with the message:

    Error: The installed version of Solaris 10 is not supported

This was on an SXCE b129 host. On a hunch, I `pkgrm`ed the
`SUNWs10brandu` and `SUNWs10brandr` packages, and installed the ones
from b130. After that, everything worked again. I'm expecting further
patching of the Solaris 10 zones to break compatibility again, and since
I refuse to (up?)grade to OpenSolaris, I'll be stuck then.

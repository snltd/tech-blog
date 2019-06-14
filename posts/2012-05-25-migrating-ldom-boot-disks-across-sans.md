---
title: "Migrating LDOM Boot Disks Across SANs"
tags: [Solaris, LDOMs]
date: 2012-05-25
category: Solaris
---

As part of a SAN migration, I had to move an LDOM's boot disk from one
SAN to another. These notes begin from a point where the new LUNs are
presented to the box and properly multipathed. The old LUN is 36Gb, and
pretty full, so I've been given 145Gb for the new one, and I want to use
all of it.

In this example the domain is called `mydom`.

Looking at the existing boot disk from inside the domain I see:

```cmd
# iostat -En
c0d0             Soft Errors: 0 Transport Errors: 0 Protocol Errors: 0
Vendor: SUN Product: VDSK Size: 39.02GB <39018823680 bytes>
```

There's no reference to the SAN or those long multipathed target names
because the disk is abstracted by the primary domain via the virtual
disk server. What we need to do is add the new LUN to the VDS so it's
visible in the domain. Then, from the domain we can attach the new disk
to the old one as a mirror, let them sync, and remove the original
mirror.

So, in the global, map the LUN's device to a virtual disk. Remember (I
often forget) that you need the path to the full disk device, including
the `/dev/dsk`, and the `s2`.

```cmd
# ldm add-vdsdev /dev/dsk/c5t600601600DC02D0048F57258A29EE111d0s2 mydom-newboot@primary-vds
```

Then map the disk to the VDS

```cmd
# ldm add-vdisk mydom-newboot mydom-newboot@primary-vds mydom
```

And tell the domain that's the new boot disk

```cmd
# ldm set-variable boot-device=mydom-newboot mydom
```

Connect to the domain, and the disk should show up in `format`, without
you even needing to do a `devfsadm`.

Because this is a root pool you have to attach slice 0 of an SMI
labelled disk. If you have an EFI label, use `format -e` to change it,
and make a slice 0 at least as large as the one you're attaching to.

As I said earlier, my new device is bigger than my old one, and I want
to use the new space. So I set

```cmd
# zpool set autoexpand=on rpool
```

and attach my new LUN.

```cmd
# zpool attach rpool c0d0s0 c0d1s0
```

Wait for the resilver to complete and check the size:

```cmd
# zpool get size rpool
NAME   PROPERTY  VALUE  SOURCE
rpool  size      36.2G  -
```

Then detach the original half of the mirror and see if anything's changed

```cmd
# zpool detach rpool c0d0s0
# zpool get size rpool
NAME   PROPERTY  VALUE  SOURCE
rpool  size      145G   -
```

And, if you have the luxury of being able to do so, reboot-test it. You
can never be too careful!

Back in the primary we have to clear up the references to the original
boot device. You can see the disk in `ldm ls-bindings` and the device in
`ldm ls-services`.

```cmd
# ldm ls-bindings mydom | grep boot
   auto-boot\?=true
   boot-device=mydom-newboot
   mydom-newboot mydom-newboot@primary-vds      disk@1  primary
# ldm rm-vdisk mydom-boot mydom
# ldm ls-services | grep boot
    primary-vds primary mydom-boot /dev/dsk/c5t60060480000290101683533030344142d0s2
# ldm rm-vdsdev mydom-boot@primary-vds
```

And we're done. Making the box forget the LUNs is an exercise for
another day, and exactly how you do it depends on the drivers and
multipathing software you use.

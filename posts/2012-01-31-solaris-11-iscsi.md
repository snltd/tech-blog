---
title: "Setting Up A Simple iSCSI Target in Solaris 11"
tags: [Solaris, iscsi, Solaris 11]
date: 2012-01-31
category: Solaris
---

So many things have changed in the FCS of Solaris 11. Some needed
changing because they've been the same way for twenty years and they got
too creaky and/or complicated, but others seem to have changed for the
sake of change.  Filesystem sharing and exporting is the main issue,
because other than `share` and the `dfstab`, it was all new in Solaris
10 (I'm thinking of the way the `sharesmb` property worked), some of it
new in Solaris Nevada (`sharemgr`). We were just getting familiar with
that stuff, and it's all changed again. As I found when I tried to share
an iSCSI LUN in the way you always have on Solaris.

  # zfs set shareiscsi=on space/iscsi
  cannot set property for 'space/iscsi': invalid property 'shareiscsi'

It seems the commands we need now are `sbdadm` and `stmfadm`. Wow, how many
`*adm` commands do Oracle think we need?

```cmd
$ uname -r
5.11
$ ls /usr/sbin/*adm  | wc -l
      52
```

```cmd
$ uname -r
5.9
$ ls /usr/sbin/*adm | wc -l
      18
```

That's a lot of new commands to learn, especially given how complex some
of them are. Still, I suppose it's all for the best. Move with the times
eh?  If you don't have them, these two are in the
`scsi-target-mode-framework` package.

Let's make a volume to export.

```cmd
# zfs create -V 10g space/iscsi/vol01
```

I used the `-V` flag so I'd get a raw device file in `/dev/zvol/rdsk`.
That's because, just like creating VDISKs for an LDOM, you want Solaris
to treat an area of disk as if it were a physical block device.

`sbdadm` is for managing SCSI block disks within something called the
SCSI Target Mode Framework (STMF). This, like most things in Solaris 11,
has its own service.

```cmd
$ svcs "*stmf*"
STATE          STIME    FMRI
disabled       Jan_29   svc:/system/stmf:default
```

Hmm. Looks like we'd better enable that.

```cmd
# svcadm enable stmf
```

I honestly don't know what that does. It doesn't start any new
processes, so I guess it's flipped a switch somewhere in the kernel. The
SMF `start/exec` program is a binary, so I can't even look at that. I
could `dtrace` I suppose, but I don't know what I'm looking for, and
we're getting well off-topic already.

Now we know such a thing as the STMF exists, we surmise that we want to
add a logical unit to it, using that raw device file I just talked
about.

```cmd
# sbdadm create-lu /dev/zvol/rdsk/space/iscsi/vol01
```

There's a `-s` option to the `create-lu` subcommand that lets you
specify the size of the logical unit to create (if you don't use it,
`sbdadm` uses all of the "disk" is is given.) It goes from kilobytes to
exabytes: rather a frightening thought for those of us old enough to
still think of an Exabyte as an 8mm tape.

So now you've got a proper logical unit with a bona-fide GUID, and it's
in the STMF. Now we need to make it into an iSCSI target. Unsurprisinly,
STMF has its own `adm` program, called `stmfadm`, with a ton of
sub-commands.

It seems that the `sbdadm` command largely a subset of `stmfadm`. You
could also have added the lu with

```cmd
# stmfadm create-lu /dev/zvol/rdsk/space/iscsi/vol01
Logical unit created: 600144F04348CF0000004F281B1C0002
```

getting the same results. Anyway, next we need to make the LUN visible.
This is done through "views". You can make a LUN visible to one, many,
or all, hosts. The simplest way is to let everything see it:

```cmd
# stmfadm add-view 600144f04348cf0000004f281b1c0002
# stmfadm list-view -l 600144f04348cf0000004f281b1c0002
View Entry: 0
    Host group   : All
    Target group : All
    LUN          : 0
```

But that's only the LUN we've taken care of. We don't yet have an iSCSI
target. We used to use the sensibly-monikered `iscsitadm` for this, but
that's gone, so now we use `itadm`. This is an altogether more capable,
more grown-up command that handles various authentication types and
portal groups. First job is to enable the iSCSI target service.

```cmd
# svcadm enable iscsi/target
```

Then you can make the machine an iSCSI target. I'm not using any
authentication.

```cmd
# itadm create-target
Target iqn.1986-03.com.sun:02:d1c080de-d123-67fb-c880-96a7712d9928
successfully created
```

Job done. Setting up an initiator hasn't changed since Solaris 10.

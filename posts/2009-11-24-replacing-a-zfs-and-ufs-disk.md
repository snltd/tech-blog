---
title: "Replacing a disk with UFS and ZFS filesystems"
tags: [Solaris, storage, ZFS]
date: "2009-11-24"
category: Solaris
layout: post
---

One of the disks in one of our v210s was having episodes. It temporarily
went nuts, streaming a load of SCSI errors out to the console, but not
writing anything to `messages`, leaving all the UFS metadevices in
the &quot;Okay&quot; state, and not bothering the zpool either. We thought
that sounded more like a controller issue, but Sun said &quot;disk&quot; and
sent us a new one.

Why do we have two kinds of filesystem, and two volume managers on one disk?
Well, when I built these systems we wanted the many benefits of ZFS for our
data, but ZFS boot didn't yet exist outside of Solaris Nevada. So, we built
them with my old-fashioned, multi-partition (small root, separate
`/var` and `/usr`) layout, and a zpool mirrored across slice 3
of both disks, for the data. v210s, of course, only have two disks.

Replacing UFS disks is one of those things I always have to look up. You do
it very rarely, and it's one of those jobs you're **super** careful
about, triple-checking everything. Hence this document.

First, I had to detach all the mirrored devices on disk 0. We partition our
disks quite aggressively, and I didn't want to have to write down where
everything came from, and keep manually detaching. So, I wrote this little
script. It only took two minutes

```ksh
#!/bin/ksh

metastat -p | grep c1t0d0 | while read md junk
do
	print -u2 "metainit $(metastat -p $md)"
	metastat -p | grep -- -m | grep -w $md | read mirror junk
	metadetach -f $mirror $md
	metaclear $md
	print -u2 "metattach $mirror $md"
done 2>recover.sh
```

Not only does that detach all the submirrors on `c1t0d0`, but it puts
recovery information into a file called `recover.sh`. The idea is
that I'll run that script once the disk is changed, and everything will be
recreated exactly as it is now. Note that I let the `meta` commands
write to standard out so I know what's happening, but have my
`print`s go to stderr so I can capture their output easily.

Once the metadevices were all detached and cleared, I got rid of the metadbs
on that disk. We keep our metadbs in a dedicated slice, slice 7.

```cmd
# metadb -d c1t0d0s7
```

With all the SVM mirrors detached, I have to do something similar with my
zpool.

```cmd
# zpool status
  pool: space
 state: ONLINE
 scrub: scrub completed after 0h13m with 0 errors on Sun Nov 22 01:13:36 2009
config:

        NAME          STATE     READ WRITE CKSUM
        space         ONLINE       0     0     0
          mirror      ONLINE       0     0     0
            c1t0d0s6  ONLINE       0     0     0
            c1t1d0s6  ONLINE       0     0     0
```

ZFS is great. All you have to do is offline the disk, then later, tell it
there's a new one. It does everything else for you. Are you listening
Veritas?

```cmd
# zpool offline space c1t0d0s6
```

Now, for the benefit of SVM, we have to tell `cfgadm` that the disk
is going away. `cfgadm` is one of those commands I can
*never* remember how to drive, and this step is the reason for
putting this document online.

```cmd
# cfgadm -al
Ap_Id                          Type         Receptacle   Occupant     Condition
c0                             scsi-bus     connected    configured   unknown
c0::dsk/c0t0d0                 CD-ROM       connected    configured   unknown
c1                             scsi-bus     connected    configured   unknown
c1::dsk/c1t0d0                 disk         connected    configured   unknown
c1::dsk/c1t1d0                 disk         connected    configured   unknown
c2                             scsi-bus     connected    unconfigured unknown
usb0/1                         unknown      empty        unconfigured ok
usb0/2                         unknown      empty        unconfigured ok
```

Right, there's my disk, c1t0d0. I just have to unconfigure it.

```cmd
# cfgadm -c unconfigure c1::dsk/c1t0d0
```

`cfgadm` is even thoughtful enough to put a lovely blue light on next
to the disk you unconfigured. So, off to the server room, pop the SPUD and
swap the disk.

Back at your desk, run

```cmd
# cfgadm -c configure c1::dsk/c1t0d0
```

then use `cfgadm -al` again to make sure the disk is back. You'll
have to recreate the VTOC before you can put the metadevices back. That's
easy, because we are only making a clone of the other disk. `fmthard`
is quite happy to take stdin as its datafile, so it's a one-shot job.

```cmd
# prtvtoc /dev/rdsk/c1t1d0s2 | fmthard -s - /dev/rdsk/c1t0d0s2
```

Now recreate your metadbs. We have four copies in a dedicated slice 7, so to
make disk 0 match:

```cmd
# metadb -a -c4 c1t0d0s7
```

Now I have to recreate and reattach all the metadevices I blew away earlier.
Let's make sure the auto-generated script looks right:

```cmd
$ cat recover.sh
metainit d51 1 1 c1t0d0s5
metattach d50 d51
metainit d31 1 1 c1t0d0s3
metattach d30 d31
metainit d21 1 1 c1t0d0s1
metattach d20 d21
metainit d11 1 1 c1t0d0s0
metattach d10 d11
metainit d41 1 1 c1t0d0s4
metattach d40 d41
```

Yep. That should work

```cmd
# ksh recover.sh
```

The only downside to this approach is that it attaches, and therefore
resyncs, all the mirrors at once, so there's a fair bit of thrashing. The
final UFS thing to do, because this is a boot disk, is install a bootblock.

```cmd
# installboot /usr/platform/$(uname -i)/lib/fs/ufs/bootblk /dev/rdsk/c1t0d0s0
```

Now, back to the zpool. All you have to do is

```cmd
# zpool replace space c1t0d0s6
```

and ZFS will do the rest. It's brilliant, isn't it?

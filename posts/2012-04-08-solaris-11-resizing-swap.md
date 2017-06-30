---
title: "Resizing swap on Solaris 11"
tags: [Solaris]
date: "2012-04-08"
layout: post
category: Solaris
---

I was doing the 11.0 to 11.1 upgrade, and `pkg` told me:

```
pkg: Insufficent disk space available (3.16 GB)for estimated need (4.42 GB) for
Root filesystem
```

So I need to find another Gb and a bit from somewhere, and it happens
that this box has way more swap space than it needs.

On any Solaris with ZFS root, swap is a ZFS dataset just like any other.
Well, almost any other. It's acutally a vdev, so it needs to be created
with `-V` and a size.

```cmd
$ swap -l
swapfile                  dev    swaplo   blocks     free
/dev/zvol/dsk/rpool/swap 171,2         8    12280    12280
```

The steps are to remove the swap space, destroy the dataset, recreate it
with a smaller size, then add it again.

```cmd
# swap -d /dev/zvol/dsk/rpool/swap
# zfs destroy rpool/swap
# zfs create -V 3G rpool/swap
# swap -a /dev/zvol/dsk/rpool/swap
```

If, like me, you have slow disks, it can take a while to intialize the
swap, but that's all you have to do. Beats messing about with swap
partitions doesn't it?

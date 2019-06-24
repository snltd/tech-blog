---
title: "Persisting madadm.conf"
tags: [Linux, AWS]
date: 2014-01-16
category: Linux
---

Scaling up a Graphite cluster, I was restarting the `carbon-cache`
nodes on more powerful EC2 instances. All was going well until I hit
a box which came back without all its storage. Turns out that the
previous sysadmin (or devops helicopter pilot or whatever he calls
himself) hadn't automated all of the things quite to the extent
where a box could restore its own disks. The `mdadm` config hadn't
been persisted to disk.

Setting aside for the moment how painful it is for me to have to do
disk and filesystem manipulation on Linux, with its awful 1980s
ideas and interfaces, here's what I did to fix it. I'll never
remember this.

To get `mdadm.conf` updated from the live config:

```cmd
# /usr/share/mdadm/mkconf force-generate /etc/mdadm/mdadm.conf
```

(This can take a little while: don't panic.)

Then, put the new config file into the `initramfs`:

```cmd
# update-initramfs -u
```

I also had to update the `fstab` because that hadn't been done
either.

```
/dev/md0    /opt/graphite/storage auto defaults,nobootwait 0    2
```

---
title: "NVRAM disk aliases"
tags: [Solaris install, disk, disksuite, svm]
date: 2009-10-27
category: Solaris
---

I inherited a T2000 which was configured to use hardware RAID. I know that's
Sun best practice, but I wanted to go back to two disks so I could split the
mirror for LiveUpgrades. (This was back before ZFS root.)

To get rid of the hardware mirroring:

```cmd
# raidctl -d c1t0d0
```

Then I set the following boot paths. I always use `disk0` and
`disk1` as my disk names. That's logical, isn't it?

```cmd
ok setenv use-nvramrc? true
ok nvedit
 0: devalias disk0 /pci@7c0/pci@0/pci@1/pci@0,2/LSILogic,sas@2/disk@0,0
 1: devalias disk1 /pci@7c0/pci@0/pci@1/pci@0,2/LSILogic,sas@2/disk@1,0
 2: <ctrl-c>
ok nvstore
ok setenv boot-device disk0 disk1 net
```

While we're at it, here are the boot paths for the other machines I've been
working on. Could save a bit of faffing around one day.

This is for a v245.

```cmd
ok nvedit
   0: nvalias disk0 /pci@1e,600000/pci@0/pci@a/pci@0/pci@8/scsi@1/disk@0,0:a
   1: nvalias disk1 /pci@1e,600000/pci@0/pci@a/pci@0/pci@8/scsi@1/disk@1,0:a
   2: <ctrl-c>
```

And this is for the old-school classic v210.

```cmd
ok nvedit
 0: devalias disk0 /pci@1c,600000/scsi@2/disk@0,0
 1: devalias disk1 /pci@1c,600000/scsi@2/disk@1,0
 2: <ctrl-c>
```

This is for the mighty Ultra 2. I still have a couple of these kicking
about.

```cmd
ok nvedit
   0: devalias disk0 /sbus/SUNW,fas@e,8800000/sd@0,0
   1: devalias disk1 /sbus/SUNW,fas@e,8800000/sd@1,0
   2: <ctrl-c>
```

Can't imagine I'll ever want this again, but here are the disk paths for the
hated v100.

```cmd
ok nvedit
 0: devalias disk0 /pci@1f,0/ide@d/disk@0,0
 1: devalias disk1 /pci@1f,0/ide@d/disk@2,0
 2: <ctrl-c>
```


Remember, when you've set your DiskSuite disk mirroring, to pop

```
set md:mirrored_root_flag = 1
```

into `/etc/system` so the thing will boot if it completely loses a
disk.

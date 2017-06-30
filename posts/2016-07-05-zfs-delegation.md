---
title: "ZFS Snapshotting for Users"
date: "2016-07-05"
tags: [Solaris, ZFS, RBAC]
layout: post
category: Solaris
---

One of my favourite things about Solarish operating systems is the
deep integration of RBAC, and principle of least privilege. Briefly,
the kernel knows about hundreds of distinct privileges, and a user
has a privilege set. Root is the set of all privileges. A normal
user has a set which makes it equivalent to the old concept of a
non-root user. Roles and profiles make it easy for us to grant or
remove privileges as they are required. (Or as they are not.)

I am playing around with a deployment model based on ZFS snapshots.
The first step, taking the snapshot traditionally would require
`root`. Or, granting the user something like the `ZFS File System
Management` profile and having it use `pfexec`. Even the ZFS profile
is too loose: we don't want to let the deployment user operate on
anything other than the one dataset it has too. What if the script
doing the job had a typo in a variable name or something, and we
deployed, or worse, *removed* the wrong thing?

One of, I think, the lesser-known `zfs` commands is `allow`. This
lets you grant any or all users the ability to perform a set of
options on any dataset(s).

I want my `deploy` user to be able to snapshot my `space/app_1`
dataset, send that snapshot, then remove it. Watch:

```cmd
$ id
uid=264(rob) gid=14(sysadmin)
$ zfs snapshot space/app_1@test
cannot create snapshot 'space/app_1@test': permission denied
# zfs allow rob snapshot,destroy,mount,send space/app_1
$ id
uid=264(rob) gid=14(sysadmin)
$ zfs snapshot space/app_1@test
$ zfs list space/app_1@test
NAME              USED  AVAIL  REFER  MOUNTPOINT
space/app_1@test     0      -   144K  -
$ zfs send space/app_1@test | gpg2 -e -r recip@test.com >fs_img.gpg
Warning: using insecure memory!
$ ls -lh fs_img.gpg
-rw-r--r--   1 rob      sysadmin    3.2K Jul  5 22:18 fs_img.gpg
$ zfs destroy space/app_1@test
$ zfs list space/app_1@test
cannot open 'space/app_1@test': snapshot does not exist
```

My non-root user has created a GPG-encrypted snapshot of the
filesystem which I can ship around and `receive` to my heart's
content.

When the snapshot file is read back in with `zfs recv`, the `allow`
property is blank: the grants are not carried over with the
snapshot.

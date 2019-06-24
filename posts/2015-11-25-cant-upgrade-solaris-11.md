---
title: "Failing to Upgrade Solaris 11.2"
tags: [Solaris, beadm, IPS]
date: 2015-11-25
category: Solaris
---

Wishing to upgrade a Solaris 11.2 box to 11.3, I ran

```cmd
# pkg update --accept
```
and went to do something else that also takes an extremely long
time. As is the way of IPS, after a very long time, it failed, with
no meaningful error message.

Having been in this situation before, I knew enough to

```cmd
# export BE_PRINT_ERR=true
```

Obvious, right? Because who would ever want to print errors? And if
they did, they certainly wouldn't want to see them in a log file, or use
a flag like `--verbose`.

Now, we're getting somewhere. After another really long time:

```
be_mount_callback: failed to mount dataset rpool/ROOT/s11.2-2/var at
/tmp/.be.5god2i/var: directory is not empty
be_mount: failed to mount BE (s11.2-2) on /tmp/.be.8say3q
be_copy: failed to mount newly created BE
```

Alright, let's try to manually create a new boot environment. All
that does is a bit of ZFS snapshottery, so it shouldn't take long.

```cmd
# beadm create test
be_mount_callback: failed to mount dataset rpool/ROOT/test/var at
/tmp/.be.8say3q/var: directory is not empty
be_mount: failed to mount BE (test) on /tmp/.be.8say3q
be_copy: failed to mount newly created BE
be_copy: destroying partially created boot environment
be_get_uuid: failed to get uuid property from BE root dataset user
properties.
Unable to create test.
Unable to find message for error code: 1
```

`beadm` cleans up after itself, so you can't go and investigate any
of the things mentioned in the error message. But, the failure to
mount `/var` seemed consistent, so I force-unmounted `/var` and had
a look what was underneath it.

```cmd
# zfs umount -f rpool/ROOT/s11.2-1/var
# find /var
/var/user
/var/user/root
/var/user/root/tpm
/var/user/root/tpm/userps
/var/user/root/tpm/userps/user.data
```

I've no idea where that came from, but after it had gone I was able
to create a new test boot environment.

After that, the upgrade worked perfectly.

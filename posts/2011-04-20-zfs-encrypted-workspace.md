---
title: "ZFS Encrypted Workspace"
date: 2011-04-20
tags: [Solaris, ZFS, encryption]
category: Solaris
---

I often work from home, and I've always been concerned that if my
computer were stolen, it would have my clients' data on it.

With my move to Solaris Express, I now have access to encrypted ZFS
filesystems, so I thought I'd use them to provide a bit more data
security.

In my experiments with ZFS, I'd found that scrubbing a zpool with
encrypted filesystem showed errors. I scrub my filesystems
regularly, and I don't want these "false" errors on my important
data pool.  Also, I'm completely new to ZFS crypto, so I created a
dedicated pool, called `crypto` as a safe area in which to
experiment, then keep, my encrypted filesystems.

```cmd
# zpool create -f crypto mirror c9d0s1 c10d0s1
# zfs set mountpoint=none crypto
# zfs set compression=on crypto
```

## Encrypted Workspace - Always Mounted

I decided to have two "levels" of security. The first is a temporary
workspace area, that's always mounted under `work/` in my home
directory.  It's mounted automatically at boot time, so if anyone
got hold of my machine, booted it up, and managed to log in, they'd
be able to see its contents.  But, as the data will never be stored
in the clear, once it's removed, it can't be recovered.

First I had to generate a key.

```cmd
$ pktool genkey keystore=file outkey=/etc/incomkey.file keytype=aes keylen=256
# chown root:root /etc/incomkey.file
# chmod 0400 /etc/incomkey.file
```

Then I could create the filesystem, encrypting it with the key I
just made

```cmd
# zfs create -o encryption=aes-256-ccm -o \
  keysource=raw,file:///etc/incomkey.file crypto/work/scratch
```

I set the mountpoint for the global zone, and used `zonecfg` to
loopback mount it in my workstation zone. Easy. It would be a nice
idea to put the key on a USB stick so the filesystem could only be
mounted by whoever had that stick, but I don't need that in this
instance.

## Encrypted Directory - Mounted on Request

Next I wanted to create a filesystem that was harder to get to. This
one is for more sensitive data, and can only be mounted by entering
a passphrase.  Pick a nice long one that you'll be able to remember.
I find long strings of normal words far easier to remember than
13375p34k type things, and they have much higher entropy.

```cmd
# zfs create -o encryption=aes-256-ccm -o keysource=passphrase,prompt crypto/sensitive
```

You'll have to mount this filesystem manually whenever you want to
use it. I have a couple of them, and I usually do

```cmd
# zfs mount -a
```

to mount all of them at once, then enter the passphrases.

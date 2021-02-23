---
title: "ZFS Encrypted Workspace"
date: 2021-02-16
tags: [Solaris, ZFS, encryption]
category: Solaris
---

This is an update of [a ten-year old
page](/post/2011-04-20-zfs-encrypted-workspace). describing a task I have to
do infrequently enough that I *always* forget the command syntax. The original
page was for Solaris, this one updates it for OmniOS, because once I looked up
how to do it on that original post, I always found it didn't work.

## Encrypted Workspace - Always Mounted

Here's a way to create an encrypted workspace which uses a keyfile. It could
be on a USB stick, an NFS mount, whatever you like.

Generate the key. This is the same on Solaris and OmniOS.

```cmd
# pktool genkey keystore=file outkey=/etc/mykey keytype=aes keylen=256
# chown root:root /etc/mykey
# chmod 0400 /etc/mykey
```

Then create an encrypted dataset which uses that key. I'll line break to
highlight the differences.

OmniOS:

```cmd
# zfs create \
  -o encryption=aes-256-ccm \
  -o keyformat=raw \
  -o keylocation=file:///etc/mykey
  tank/encrypted_dataset_1
```

Solaris:

```cmd
# zfs create \
  -o encryption=aes-256-ccm \
  -o keysource=raw,file:///etc/mykey \
  tank/encrypted_dataset_1
```

Obviously, if you lose the keyfile, you're hosed.

## Encrypted Directory - Mounted on Request

I use this for more client data, as it can only be mounted by entering a
passphrase. OmniOS enforces an eight-character minimum, but pick a nice long
one.

OmniOS:

```cmd
# zfs create \
  -o encryption=aes-256-ccm \
  -o keyformat=passphrase \
  -o keylocation=prompt \
  tank/encrypted_dataset_2
```

Solaris:

```cmd
# zfs create \
  -o encryption=aes-256-ccm \
  -o keysource=passphrase,prompt \
  tank/encrypted_dataset_2
```

You'll have to mount this filesystem manually whenever you want to
use it. I have a couple of them, and I usually do

```cmd
# zfs mount -a
```

to mount all of them at once, then enter the passphrases.

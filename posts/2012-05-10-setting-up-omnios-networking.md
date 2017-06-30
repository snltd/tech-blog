---
title: "Setting up networking on OmniOS"
tags: [Solaris, OmniOS]
date: "2012-05-10"
category: Illumos
layout: post
---

I installed OmniOS in a VirtualBox with a bridged network interface, and
when it came up, it hadno networking at all.

I have the hostname `lw-01-oo` mapped to `192.168.1.33` in my internal
DNS. The first part is different from Solaris 10 and earlier.

```cmd
# dladm show-link -o link
LINK
e1000g0
```

Great, I have a network interface. I need to make an IP interface on top
of that link:

```cmd
# ipadm create-if e1000g0
```

Then set an IPv4 address for that interface. I'll use the name `v4` in
case I ever want to add an IPv6 address. (lol)

```cmd
# ipadm create-addr -T static -a 192.168.1.33/24 e1000g0/v4
```

And my network's default route is `192.168.1.1`.

```cmd
# route -p add default 192.168.1.1
```

Nifty. [Unlike Solaris 11](/solaris/2011/11/22/solaris-11-dns.html),
the rest is the same as it's always been. To get DNS working I just
stick

```
domain localnet
nameserver 192.168.1.26
```

in `/etc/resolv.conf` and add `dns` to the end of the `hosts` line in
`/etc/nsswitch.conf`. My home directories are exported from `tap`, so I add

```
*    tap:/export/home/&
```

to my `/etc/auto_home` file, add my user, and restart the `autofs`
service. Done!

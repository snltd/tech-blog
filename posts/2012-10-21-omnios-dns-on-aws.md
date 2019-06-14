---
title: "DNS on OmniOS AWS Image (Learning about dhcpinfo)"
tags: [Solaris, OmniOS, DHCP, DNS, AWS, EC2]
date: 2012-10-21
category: Illumos
---

I was working away creating an Amazon EC2 OmniOS AMI, but Andrzej Szeszo
[beat me to the punch](http://omnios.omniti.com/wiki.php/Ec2Ami).
So, I've been messing about with his images.

You need to fire them up from the US East region, and the AMI ID I'm
using right now is `ami-e14dfe88`. It runs just fine as a `t1.micro`
image, which I believe puts it in free tier usage.

So, I'm all logged on and poking around when:

```cmd
$ ping google.com
ping: unknown host google.com
$ ping 173.194.41.135
173.194.41.135 is alive
```

Looks like DNS is broken. (`173.194.41.135 == google.com`).

```cmd
$ svcs -x
svc:/network/dns/client:default (DNS resolver)
 State: offline since Sun Oct 21 07:04:34 2012
Reason: Dependency file://localhost/etc/resolv.conf is absent.
```

Hm. Now, I've never really used DHCP on Solaris, but I do recall
`dhcpinfo` being somewhere in the mix. Turns out that it's a little
impenetrable, and the `man` page isn't particularly helpful. (Or at
least it wasn't to me.)

```cmd
$ dhcpinfo
usage: dhcpinfo [-c] [-i interface] [-n limit] [-v {4|6}] code
       dhcpinfo [-c] [-i interface] [-n limit] [-v {4|6}] identifier
```

Fine, `-i` is obviously my interface, which on EC2, which is Xen, means
`xnf0`; `-n` is the maximum number of results to return, and `-v` is the
IPv version. What the heck are `code` and `identifier`. Turns out that
all the possible identifiers are the first column of
`/etc/dhcp/inittab`, and there are loads of them:

```cmd
$ awk '/^[A-Z]/ { print $1 }' /etc/dhcp/inittab | sort
```

So let's have a look at what I've got. Note that I don't need to specify
the IP interface, because I've only got one.

```cmd
$ ipadm show-addr  xnf0/v4
ADDROBJ           TYPE     STATE        ADDR
xnf0/v4           dhcp     ok           10.29.223.50/26
$ dhcpinfo Ciaddr
10.29.223.50
$ dhcpinfo Subnet
255.255.255.192
$ dhcpinfo DNSdmain
ec2.internal
$ dhcpinfo DNSserv
172.16.0.23
```

So I opened up `/etc/resolv.conf` in `vi` and made it look like this:

```
domain ec2.internal
nameserver 172.16.0.23
```

Then added `dns` to the `hosts` line in `/etc/resolv.conf` and cleared the
DNS service

```cmd
# svcadm clear dns/client
$ ping google.com
google.com is alive
```

Given that OmniOS had all the correct information, I'm not sure why it
wasn't updating the files itself. I think that it's safe to hardwire
these values into the AMI.

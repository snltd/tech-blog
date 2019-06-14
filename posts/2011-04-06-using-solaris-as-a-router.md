---
title: "Building a Router With a Solaris Zone"
tags: [Solaris, routing, zones, s-zone.sh]
date: 2011-04-06
category: Solaris
---

I needed to integrate into my `192.168.1.0/24` home network, a machine
whose ALOM I knew to be on `10.10.8.0/24`. I don't have any fancy
routing hardware, so I thought it would be a good idea to try it in
Solaris. I'm using SXCE build 130, but all this will work on
OpenSolaris, Solaris Express, or anything based on either of those. All
you need is Crossbow, because it's based around VNICs. If you aren't
sure whether or not your system supports VNICs, run

```cmd
# dladm 2>&1 | grep create-vnic
```

And if you get output, it does.

The plan is to create a dedicated router zone which forwards traffic
between `192.168.1.0` and `10.10.8.0`. I only have one physical NIC
(`atge0`) in my workstation though.

I'm going to create a VNIC on top of `atge0` specifically for my routing
zone.  It'll be the `10.10.8.0` address. Because VNICs are free, I'll
also create one for `192.168.1.0`

```cmd
[global]
# dladm create-vnic -l atge0 vnic_rt0
# dladm create-vnic -l atge0 vnic_rt1
```

Now create the routing zone itself. Its IP addresses will be `10.10.8.1`
on `vnic_rt0` and `192.168.1.253` on `vnic_rt1`. I'm going to use [my
`s-zone.sh`
script](https://github.com/snltd/virtualization-tools/blob/master/s-zone.sh),
which can do most things automatically

```cmd
[global]
# print "10.10.8.0   255.255.255.0" >>/etc/netmasks
# ./s\-zone.sh create -e vnic_rt0=10.10.8.1,vnic_rt1=192.168.1.253 \
  -R rpool/zoneroot -D space/zonedata tap-router
```

Now, let's have a look at the zone.

```cmd
[global]
# zlogin tap-router
```

```cmd
[tap-router]
# ifconfig -a
vnic_rt0:1: flags=1000843<UP,BROADCAST,RUNNING,MULTICAST,IPv4> mtu 1500 index 4
      inet 10.10.8.1 netmask ffffff00 broadcast 10.10.8.255
vnic_rt1:1: flags=1000843<UP,BROADCAST,RUNNING,MULTICAST,IPv4> mtu 1500 index 5
      inet 192.168.1.253 netmask ffffff00 broadcast 192.168.1.255
```

Looks good. Let's see if we can ping the ALOM, which I happen to know is on
`10.10.8.7`.

```cmd
# ping 10.10.8.7
10.10.8.7 is alive
```

And can we ping my workstation?

```cmd
# ping tap-ws
tap-ws is alive
```

To make sure the zone comes up properly, that is that the VNICs are
plumbed, you've got to put `/etc/hostname.nic` entries in to the zone

```cmd
# print tapz-router >/etc/hostname.vnic_rt0
# print >/etc/hostname.vnic_rt1
```

Now we just have to tell Solaris to forward traffic between the two
VNICs.  Back in the day, this was a pain, messing about with `ndd`, but
modern Solaris gives you lots of ways to do it, via `ifconfig`,
`routeadm` and `svcadm`. I prefer `routeadm`

```cmd
# routeadm
              Configuration   Current              Current
                     Option   Configuration        System State
---------------------------------------------------------------
               IPv4 routing   disabled             disabled
               IPv6 routing   disabled             disabled
            IPv4 forwarding   disabled             disabled
            IPv6 forwarding   disabled             disabled

           Routing services   "route:default ripng:default"

Routing daemons:

                      STATE   FMRI
                   disabled   svc:/network/routing/ripng:default
                   disabled   svc:/network/routing/route:default
                   disabled   svc:/network/routing/rdisc:default
                   disabled   svc:/network/routing/legacy-routing:ipv4
                   disabled   svc:/network/routing/legacy-routing:ipv6
                   disabled   svc:/network/routing/ndp:default
```

No routing there. You have to enable routing with the `-e` option, then
update the routing configuration with `-u`. I'm not interested in IPV6.
(Is anybody? We should be.)

```cmd
# routeadm -ue ipv4-forwarding
```

`-u` makes the change effective immediately, `-e` enables.

Now I have to tell my workstation to use `192.168.1.253` to access the
`10.10.8.0` subnet.

```cmd
[tap-ws]
# route -p add net 10.10.8.0 192.168.1.253
```

The `-p` flag makes the route persistent. This is another Solaris 10
feature which saves us having to use custom scripts or services to set
routes.

And that's it. All done.

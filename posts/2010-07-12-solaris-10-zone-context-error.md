---
title: "svc.startd could not set context"
tags: [Solaris, SMF]
date: 2010-07-12
layout: post
category: Solaris
---

I migrated a Solaris 10 VirtualBox to an SXCE branded zone using [my
`s-zone.sh`
script](https://github.com/snltd/virtualization-tools/blob/master/s-zone.sh).
When I booted the zone, there were failed services.

```cmd
# svcs
...
online         23:35:15 svc:/system/console-login:default
offline        23:30:08 svc:/system/filesystem/autofs:default
maintenance    23:30:09 svc:/network/security/ktkt_warn:default
maintenance    23:30:09 svc:/system/sac:default
maintenance     0:05:20 svc:/system/cron:default
maintenance     0:07:08 svc:/network/rpc/bind:default
```

Checking out the `rpcbind` service:

```cmd
# svcs -xv rpc/bind
svc:/network/rpc/bind:default (RPC bindings)
 State: maintenance since Tue Jul 13 00:07:08 2010
Reason: Start method exited with $SMF_EXIT_ERR_CONFIG.
   See: http://sun.com/msg/SMF-8000-KS
   See: man -M /usr/share/man -s 1M rpcbind
   See: /var/svc/log/network-rpc-bind:default.log
Impact: 1 dependent service is not running:
        svc:/system/filesystem/autofs:default
```

and looking at the log file:

```
[ Jul 12 23:26:43 Executing start method ("/lib/svc/method/rpc-bind start") ]
svc.startd could not set context for method: chdir: No such file or directory
[ Jul 12 23:26:43 Method "start" exited with status 96 ]
```

A bit of searching showed that the "could not set context" error is
generally to do with missing home directories. In this instance, `/root`
hadn't been included in the `flar` I made of the original Solaris 10 VBOX.

```cmd
# mkdir /root
# init 6
```

And everthing is happy. Another pointless, annoying linux-ism bites me in
the arse. Thanks.

---
title: "A Minimal Solaris 8 Build Server"
tags: [Solaris, minimal, Sun Studio]
date: 2008-08-08
layout: post
category: Solaris
---

Of late I've had [a pet project which audits Solaris
systems](https://github.com/snltd/s-audit). I want it to be able to
understand old versions of the O/S, so I've been Jumpstarting and
working on Solarises &lt; 9.

Whilst doing this, I've found I wanted certain little tools that aren't
available on the older versions. Downloading things from SunFreeware
dropped me into dependency hell, and I hit storage problems on the
(very) old machines I've been using. So, I thought, wouldn't it be handy
to have binaries for common tools which have NO dependencies? No extra
libraries to download, no faffing with `LD_LIBRARY_PATH` , just
cp-and-go binaries?

The problem is, binaries compiled on Solaris 10 usually won't run on old
versions, due to `libc` cleverness. So I built a Solaris 8 build server.
Quick. Here's how.

I jumpstarted with the following `sysidcfg`

```sysidcfg
system_locale=en_GB
terminal=xterm
network_interface=PRIMARY{
  protocol_ipv6=no
  hostname=spare-210-3
  ip_address=10.10.4.13
  netmask=255.255.255.0}
timezone=GB
name_service=NONE
timeserver=localhost
security_policy=NONE
```

and this `profile`.

```jsprof
install_type            initial_install
system_type             standalone
cluster                 SUNWCreq
partitioning            explicit

filesys c1t0d0s0        1024            /
filesys c1t0d0s1        free            /opt
filesys c1t0d0s4        2048            swap
filesys c1t0d0s5        1048            /var
filesys c1t0d0s6        1024            /usr
filesys c1t0d0s7        64

package SUNWauda        delete
package SUNWftpr        delete
package SUNWftpu        delete
package SUNWsndmr       delete
package SUNWsndmu       delete
package SUNWudf         delete
package SUNWudfr        delete
package SUNWudfrx       delete
package SUNWxcu4        add
package SUNWlibC        add
package SUNWarc         add
package SUNWhea         add
package SUNWtoo         add
package SUNWbtool       add
package SUNWsprot       add
package SUNWlibm        add
package SUNWlibms       add
```

I have finish scripts that did all the network configuration and system
hardening for me, so that's a fully cooked system in next to no time.

Sun Studio 11 is the most recent compiler that works on Solaris 8, so I
installed the following packages from it:

```cmd
$ bzip2 -dc studio11-sol-sparc.tar.bz2 | tar -xf -
# pkgadd -d CD1/kits/ide/packages SPROdwrfb SPROlang SPROcc SPROcpl
```

Then I patched with PCA. Solaris 8 is only in vintage support now, so many
of the patches PCA wanted weren't available on our standard support
contract. It doesn't matter though, this machine's only going to be on our
internal LAN, and it now does what I want it to.

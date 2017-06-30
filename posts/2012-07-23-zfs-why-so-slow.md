---
title: "ZFS - Why So Slow?"
tags: [Solaris, ZFS, pkg]
date: "2012-07-23"
layout: post
category: Solaris
---

A regularly scheduled job was taking an age. It's a housekeeping task
which runs a big `find`, and it was sl-o-o-o-o-w. There was nothing much
on CPU, so I ran an `iostat`. Here's what I got, disregarding the
initial, cumulative since-boot, output.

```cmd
$ iostat -inx 3
...
                    extended device statistics
    r/s    w/s   kr/s   kw/s wait actv wsvc_t asvc_t  %w  %b device
    0.0   77.1    0.0  643.3  8.0  2.0  103.8   26.0 100 100 c10d0
    0.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   0 c1t0d0
    0.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   0 c1t0d1
    0.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   0 c1t0d2
    0.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   0 c1t0d3
    0.0    0.0    0.0    0.0  0.0  0.0    0.0    0.0   0   0 c4t0d0
    0.0   97.1    0.0  844.1  9.0  1.0   92.7   10.3 100 100 c3t0d0
```

This is a machine with two SATA disks, `c10d0` and `c3t0d0`. (One on the
main board, one on a PCI SATA card, hence the different name format.)
You can see they're both busy (which you'd expect, because they're
mirrors.) In the old days, I'd be kind of stuck where to look next, but
I'm on Solaris 11, so I have the DTrace toolkit.

```cmd
# /usr/dtrace/DTT/iotop
Tracing... Please wait.
...
2012 Jul 23 12:25:25,  load: 0.15,  disk_r:    572 KB,  disk_w:   1019 KB

  UID    PID   PPID CMD              DEVICE  MAJ MIN D            BYTES
    0      0      0 sched            cmdk1   246  64 R             6656
    0      5      0 zpool-rpool      sd12     98 768 R             7168
    0      0      0                  sd12     98 768              14336
    0      5      0 zpool-rpool      cmdk1   246  64 R            19456
    0      0      0 sched            sd12     98 768 R            23040
   97   5160      1 htcacheclean     sd12     98 768 R           247296
   97   5160      1 htcacheclean     cmdk1   246  64 R           266752
```

`htcachclean`? That's Apache, but I'm not running a webserver on this
machine am I? Hmm. I wish...

```cmd
# pargs 5160
5160:   /usr/apache2/2.2/bin/htcacheclean -d20160 -i -l 2048M -n -p /var/cache/pkg/sysr
argv[0]: /usr/apache2/2.2/bin/htcacheclean
argv[1]: -d20160
argv[2]: -i
argv[3]: -l
argv[4]: 2048M
argv[5]: -n
argv[6]: -p
argv[7]: /var/cache/pkg/sysrepo
argv[8]: -P
argv[9]: /var/cache/pkg/sysrepo/../sysrepo_htcacheclean.pid
argv[10]: -t
```

It's IPS doing its own housekeeping, killing my service performance
stone dead. Just when you think you hate IPS as much as you possibly
can, it always finds a way to make you hate it a little bit more.

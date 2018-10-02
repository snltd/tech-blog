---
title: "What is Solaris Doing with my Disks?"
date: "2018-09-22"
tags: [Solaris, DTrace, Wavefront]
layout: post
category: Wavefront
---

I recently upgraded a lab machine to Solaris 11.4. It all went
pretty well, and there are a surprising amount of new features for a
supposedly dead operating system.

My existing [Diamond metric
collector](https://sysdef.xyz/post/2017-03-03-solaris-proc-wavefront)
dropped in no problem, and all the charts looked good. Except one.

<script src="https://metrics.wavefront.com/embedded/yymDyPYLkJ/js"
id="wavefront-embedded-yymDyPYLkJ" width="700"
height="300"></script>

That's disk writes. And it never changed. What's it doing? The same
box, with the same workload, didn't do it on 11.3

The first thing I tried was `iotop`, from the DTrace toolkit.


```cmd
# /usr/dtrace/DTT/iotop
2018 Sep 22 14:14:45,  load: 0.29,  disk_r:      8 KB,  disk_w:   9460 KB

  UID    PID   PPID CMD              DEVICE  MAJ MIN D            BYTES
    0  28941      1 sstored          sd1     168  65 R             8192
    0    768      0 zpool-crypto     sd1     168  67 W           552960
    0    768      0 zpool-crypto     sd2     168 131 W           552960
    0    777      0 zpool-space      sd1     168  66 W           708608
    0    777      0 zpool-space      sd2     168 130 W           708608
    0      5      0 zpool-rpool      sd1     168  65 W          3592192
    0      5      0 zpool-rpool      sd2     168 129 W          3592192
```

Okay, that's not much help. The `zpool-*` processes belong to the
kernel, and they aren't keen to give up any more information on
themselves. They're writing something, but on whose behalf?

Next I tried `rwtop`, but that didn't tell me much more. The main
reader and writer was `diamond`, my metric collector, and I know
(because I wrote it) that that only deals with `/proc`.

At this point I started trying to dig with DTrace, but I never use
it now I live in AWS world, and it was a frustrating experience. I
tried various approaches with `syscall` and `io` providers, but I'd
entirely lost my tracing mojo. Frustrated, I posted a question on
the Oracle community forum, and I very quickly got an answer: use
`fsinfo`.

I didn't recognize that at all. It's so long since I DTraced in
anger that I thought that must be some new-fangled thing Oracle have
added. Then I found it in [my own notes from
2011](https://sysdef.xyz/post/2011-10-18-dtrace-notes-02-io).

`fsinfo` is perfect for a casual DTracer like me. It gives you a
view of the VFS layer, which is a simple, useful abstraction, and
doesn't have a million probes requiring in-depth kernel knowledge,
and it has two consistent arguments. `args[0]` is a `fileinfo_t`
structure,

```c
string   fi_name;     /* basename of file */
string   fi_dirname;  /* directory file is in */
string   fi_pathname; /* full path to file */
offset_t fi_offset;   /* offset within file */
string   fi_fs;       /* filesystem */
string   fi_mount;    /* filesystem's mount point */
```

and `args[1]` is the function return value. If you recall your basic C:

```c
ssize_t write(int fd, const void *buf, size_t count);
```

so `write` returns the number of bytes it wrote.

Adapting the one-liner I got from the support forum, I put together the
following script:

```dtrace
#!/usr/sbin/dtrace -qs

fsinfo:::write
/args[0]->fi_fs == "zfs"/
{
  printf("%s %s %s %d\n", zonename, execname, args[0]->fi_mount, args[1])
}
```

We ask for all the `write` operations the `fsinfo` provider sees,
then we use a `/predicate/` to select only this `write`s which go
to a `zfs` filesystem.

```
cube-cron sstored /system/zones/cron/root/var/share/sstore/repo 152
cube-cron sstored /system/zones/cron/root/var/share/sstore/repo 8536
cube-cron sstored /system/zones/cron/root/var/share/sstore/repo 8536
cube-wavefront sstored /system/zones/wavefront/root/var/share/sstore/repo 152
cube-wavefront sstored /system/zones/wavefront/root/var/share/sstore/repo 152
cube-wavefront sstored /system/zones/wavefront/root/var/share/sstore/repo 152
```

That's great, but I'm planning to chart this data, so I need to use
an aggregation. When you ask DTrace to make an aggregation, it fills
named "buckets" with data, using one of a number of arithmetic
operators. Most commonly you use aggregations to `count()` the
number of times something happens, but in this case we wanto to
`sum()` those write return codes.


```dtrace
nfo:::write
/args[0]->fi_fs == "zfs" && probename == "write"/
{
  @num[zonename, execname] = sum(args[1]);
}

profile:::tick-1sec
{
  printa("%@d %s %s\n", @num)
}
```
Let's put it in Wavefront.

```cmd
$ wf write --help
Usage:
...
  wf write file [-DnViq] [-c file] [-P profile] [-E proxy] [-H host]
          [-p port] [-F infileformat] [-m metric] [-T tag...] <file>
```

The `-F` option lets us define an input file format. We're just going to send a
value and bunch of point tags to the same metric.

```dtrace
#!/usr/sbin/dtrace -qs

fsinfo:::write
/args[0]->fi_fs == "zfs" && probename == "write"/
{
  printf("%i zone=%s execname=%s mountpoint=%s\n",
      args[1], zonename, execname, args[0]->fi_mount)
}
```



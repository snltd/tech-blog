---
title: "Getting a file out of a FLAR"
tags: [Solaris, install, flash archive]
date: "2009-09-22"
layout: post
category: Solaris
---

I was looking for some data relating to an old zone we long since
decommissioned, and I didn't want to have to start rummaging through the
fire safe for tapes. We had some old flar archives lying about from
roughly the time I was looking for, so I thought I'd see if what I
wanted was in any of those.

Sun don't give you anything so convenient as `unflar` or `flar -x`, so I
had to do a bit of digging. Here's the recipe.

```cmd
$ flar info cs-dev-01-2007-10-01.flar
archive_id=19b06a4bfe0b7e7200b8e1329adf06a1
files_archived_method=cpio
creation_date=20071001171819
creation_master=cs-dev-01
content_name=image created Mon Oct 1 18:18:19 BST 2007
creation_node=cs-dev-01
creation_hardware_class=sun4v
creation_platform=SUNW,Sun-Fire-T200
creation_processor=sparc
creation_release=5.10
creation_os_name=SunOS
creation_os_version=Generic_120011-14
files_compressed_method=compress
content_author=take_flar.sh script
content_architectures=sun4v
```

Right, that's handy. It tells me that my flar archive is a pretty much a
compressed `cpio` archive. `man flar` tells me that the `split`
sub-command will split the flar into sections, one of which is something
called the "cookie".  Sounds likely that one of those sections will be
that cpio archive. Let's give it a go. The man page also tells me `-d`
will instruct `flar` to split its files into the named directory.

```cmd
$ mkdir -p recovery/root
$ flar split -d recovery cs-dev-01-2007-10-01.flar
$ ls -l recovery
-rw-r--r--   1 root     root     165880915 Sep 22 15:21 archive
-rw-r--r--   1 root     root          18 Sep 22 15:21 cookie
-rw-r--r--   1 root     root         487 Sep 22 15:21 identification
drwxr-xr-x   2 root     root           2 Sep 22 15:21 root
```

It's pretty plain which one we're after, so let's extract it. I'm after
quite a bit of stuff, so I think I'll just dump the whole archive. I'm on a
nice fast 3510 with space to burn, after all. Remember, `flar info` told us
the archive was compressed.

```cmd
$ cd recovery
$ file archive
archive:        compressed data block compressed 16 bits
$ cd root
$ uncompress < ../archive | cpio -id
```

The last command is written that way because `uncompress` expects its input
to be called `something.Z`, so rather than rename the file, we'll just feed
it stdin.

Punchline: after all that, what I wanted wasn't in the flar.

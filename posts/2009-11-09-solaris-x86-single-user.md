---
title: "Single User mode on Solaris x86"
tags: [Solaris, x86]
date: 2009-11-09
layout: post
category: Solaris
---

The failsafe boot environment is great, but sometimes you just need good
old single-user.  (Or whatever fancy name it has now SMF runs the show.)

When you get the boot menu, select your normal Solaris BE, and hit `e`.
With the cursors, highlight the `kernel` line, then press `e` again and
add your `-s` at the end, with a carriage return, an you'll have
something like:

```
findroot(pool_rpool,0,a)
kernel$ /platform/i86pc/multiboot -B $ZFS_BOOTFS -s
module /platform/i86pc/boot_archive
```

Obviously, the exact information might vary, depending on your boot
device, and if you're using ZFS root, but you get the idea.

Now hit `b` and it'll boot to the single-user milestone.

So far as I can tell, you can add any of the standard Solaris boot
options in there. `-v`  is probably the most interesting, especially if
you're not entirely up-to-date on how SMF handles the boot process.

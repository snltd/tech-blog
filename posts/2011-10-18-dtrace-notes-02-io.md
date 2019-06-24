---
title: "DTrace notes 02: the io and syscall providers"
tags: [Solaris, DTrace]
date: 2011-10-18
category: Solaris
---

More written-up notes from my DTrace course. Might be useful. Today it's
the `io` provider.

# io

This is a fairly simple provider to master because it doesn't have many
probes.

However, the probes it does have provide give a lot of information. Each
element of the `args[]` array points to a data structure explaining the
I/O transaction. So the most useful things to know are what these
structures are and how they are laid out.

The `start`, `done`, `wait-start` and `wait-done` probes all use
`args[0]` to point a `buf` structure which describes the I/O request;
`args[1]` to point to the `devinfo_t` structure which describes the I/O
device; and `args[2]` to point to the `fileinfo_t` structure which
describes the file being operated on.

## `args[0]->buf`

This is taken from the `buf(9s)` man page

```c
int        b_flags;     /* Buffer status */
size_t     b_bcount;    /* # of bytes to transfer */
caddr_t    b_addr;      /* Buffer's virtual address */
daddr_t    b_blkno;     /* Block number on device */
diskaddr_t b_lblkno;    /* Expanded block number on device */
size_t     b_resid;     /* # of bytes not transferred */
size_t     b_bufsize;   /* size of alloc. buffer */
int        b_iodone     /* function called by biodone */
int        b_error;     /* expanded error field */
dev_t      b_edev;      /* expanded dev field */
```

in the `b_flags field`, these are the flags

* **`B_DONE`** - The data transfer completed.

* **`B_ERROR`** -
  indicates an I/O transfer error. It is  set  in conjunction with
	the `b_error` field.

* **`B_PAGEIO`** -
	indicates the buffer is being used in a paged I/O request

* **`B_PHYS`** -
	indicates the buffer header is being used for physical (direct)
	I/O to a user data area.

* **`B_READ`** -
	indicates that data is to be read from the peripheral device into
	main memory.

* **`B_WRITE`** -
	indicates that the data is to be transferred from main memory
	to the peripheral device.

## `args[1]->devinfo_t`

I don't know where to find this on an active Solaris system. It's in the
DTrace guide, but I'll put it here so I know where it is. It's a structure
which tells you all about the device being used for the I/O.

```c
int     dev_major;     /* major number */
int     dev_minor;     /* minor number */
int     dev_instance;  /* instance number */
string  dev_name;      /* device name */
string  dev_statname   /* device name + instance/minor */
string  dev_pathname   /* device pathname */
```

## `args[2]->fileinfo_t`

Again, taken from the DTrace guide.

```c
string   fi_name;     /* basename of file */
string   fi_dirname;  /* directory file is in */
string   fi_pathname; /* full path to file */
offset_t fi_offset;   /* offset within file */
string   fi_fs;       /* filesystem */
string   fi_mount;    /* filesystem's mount point */
```

`offset_t` is a signed 64-bit quantity. Note that not all filesystems are
very helpful here. For instance, if you run a trace like:

```cmd
# dtrace -n 'io:::start  /execname == "cat"/ { trace(args[2]->fi_pathname); }'
```

Then `cat`ting a file on a UFS filesystem will show up the filename, but
on a ZFS filesystem, you'll just get `&lt;none&gt;`.

The `fsinfo` provider also uses these structures, possibly in a
simpler-to-understand way. This aggregates files opened on a
per-filesystem
basis.

```cmd
# dtrace -qn 'fsinfo::fop_open:open { @[args[0]->fi_mount] = count(); }'
```

## iosnoop.d

This is my annotated version of the `iosnoop.d` script. I hope it
explains how things work in D.

```c
#!/usr/sbin/dtrace -qs

/* note that this doesn't work that well with ZFS filesystems. I think this
 * is because they used the zfs provider, not io. Filenames are always
 * reported as "none" on ZFS filesystems, though it works for UFS
 * filesystems created on top of ZFS (though the disk device is "zfsn" where
 * n is an integer */

BEGIN
{
  /*
   * Fires as soon as the script is run, so it's useful to print field
   * headers, which is what it does here.  This is a normal printf() like
   * you'd have in C, or ksh. The digit following the % is the length of
   * the string, and the letter is the datatype. s for string, d for digit
   * and so on
   */

  printf("%16s %5s %30s %10s %2s %7s\n", "COMMAND", "PID", "FILE",
  "DEVICE", "RW", "MS");
}

io:::start
{

  /*
   * When any "start" io probe fires (use 'dtrace -l -P io | grep  "
   * start$"' to see what they are), this function is called. It assigns
   * three variables, which can be called anything you want - there's
   * nothing special about start, command, or mypid, though mypid is used
   * instead of 'pid' because 'pid' is a reserved word in D.
   *
   * timestamp, execname and pid are automatic variables which give us
   * respectively the current system timestamp (accurate to the
   * nanosecond), the name of the executable which just caused this probe
   * to fire, and the pid of that executable.
   *
   * start, command, and mypid are associative arrays, and an element will
   * be added to each array whenever the probe fires. We have to store the
   * execname and pid now, because when the corresponding 'done' probe
   * fires, that infomation won't be available.
   *
   * The thing you can't work out for yourself here is that args[0] refers
   * to the buf structure. ('man buf' will tell  you all about it.) We
   * take out of it the b_edev and b_blkno elements.  The first refers to
   * the major and minor device numbers of the device being used for the
   * I/O; the second to the block number being accessed on that device.
   * Together these make a unique ID for any block access.
   */

  start[args[0]->b_edev, args[0]->b_blkno] = timestamp;
  command[args[0]->b_edev, args[0]->b_blkno] = execname;
  mypid[args[0]->b_edev, args[0]->b_blkno] = pid;
}

io:::done

/* the following conditional matches an element in the start[] array created
 * above, so we know we're closing an operation for which we have the time
 * it began, and the name and pid of the controlling process */

/start[args[0]->b_edev, args[0]->b_blkno]/
{
  /* work out how long the operation took by subtracting the timestamp
   * recorded in start[] from the current one */

  elapsed = timestamp - start[args[0]->b_edev, args[0]->b_blkno];

  /* now we can print a line of information. The printf() formats output
   * to line-up with the header in the BEGIN function, but note that the
   * second column is a number, and the final column gives the time of the
   * operation in milliseconds, via two separate decimal fields.
   */

  printf("%16s %5d %30s %10s %2s %3d.%03d\n",

    command[args[0]->b_edev, args[0]->b_blkno],
      /* a 16-char string of the execname stored earlier */

    mypid[args[0]->b_edev, args[0]->b_blkno],
      /* the PID stored earlier in a 5 digit field */

    args[2]->fi_pathname,
      /* as with args[0], you need to be told that in an io probe,
       * args[2] is the fileinfo_t structure. I don't know where you
       * get info on this structure from, other than the dTrace guide.
       * We get the full pathname of the file being operated on. You
       * could also have used fi_name or fi_dirname to get the
       * basename or directory name alone. This is a 30 character wide
       * field.
       */

    args[1]->dev_statname,
      /* args[1] is the devinfo_t structure. Again, this seems only to
       * be defined in the dTrace guide. statname gives you the name
       * of the device along with its major and minor numbers. If you
       * only wanted the name, you could use dev_name. It goes into a
       * 10 character wide field. */

    args[0]->b_flags&B_READ
      ? "R"
      : "W",

      /* use D's ternary operator to print an 'R' if the B_READ flag
       * is set in buf's b_flags field. If it isn't, print a 'W'
       * because this must be write */

    elapsed/1000000,
      /* We calculated the elapsed time in nanoseconds. Divide that
       * time by 1000000 to turn it into milliseconds and make it
       * easier to read. The printf() allocated three characters for
       * this number. */

    (elapsed/1000)%1000);
      /* get the elapsed time in microseconds, then use the % modulo
       * operator to get the remainder after dividing by 1000 again.
       * Look back at the printf() and you'll see it is expecting
       * three digits, which it just got, then it places a dot, and
       * expects three more digits, which it gets from here. */

  /* If you assign 0 to a dtrace variable, you clear the memory assigned
   * to it, so clear all the memory we just used */

  start[args[0]->b_edev, args[0]->b_blkno] = 0;
  command[args[0]->b_edev, args[0]->b_blkno] = 0;
  mypid[args[0]->b_edev, args[0]->b_blkno] = 0;
}
```

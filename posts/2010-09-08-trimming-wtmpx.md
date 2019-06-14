---
title: "Trimming wtmpx"
tags: [Solaris, sysadmin]
date: 2010-09-08
category: Solaris
layout: post
---

We don't use accounting on our systems, so `/var/adm/wtmpx` just
grows and grows, particularly as a result of monitoring software which runs
a lot of remote SSH commands. It's getting out of hand, and I wanted to
clear everything down.

`wtmpx` is a binary file, so it's not easy to edit it. I opened it up
in a hex editor, and the usernames which begin each record stand out fairly
clearly, 372 bytes apart. With that knowledge, it becomes trivial to trim
out the last 'n' records with `dd`, setting the block size to 372.

But, I thought it would be smarter to strip out all the logins from the
monitoring software, and leave everything else in place. (For now at
least.) To do this you need the proper tool, which is `fwtmp`. It
belongs to the `SUNWaccu` package, and once installed, is found in
`/usr/lib/acct`.

In normal usage `fwtmp` reads a `wtmpx` file as its standard
in, and outputs a fairly human-readable ASCII file on standard out. Opposite
to the output of `last`, it starts by printing the oldest entries and
finishes with the most recent. Invoking with `-ic` reverses the
behaviour, reading that same format ASCII file, and outputting a wtmpx
format file.

The output of `fwtmp` looks like this:

```
rob  ts/2 pts/2 27863  7 0000 0000 1283268217 707975 0 18 tap-login.localnet Tue Aug 31 16:23:37 2010
```

And [I found the following data
structure](https://github.com/illumos/illumos-gate/blob/master/usr/src/lib/libbc/libc/sys/common/compat.h) which explains each field.

```c
struct utmpx
     {
         char    ut_user[32];            /* user login name */
         char    ut_id[4];               /* inittab id */
         char    ut_line[32];            /* device name (console, lnxx) */
         long    ut_pid;                 /* process id */
         short   ut_type;                /* type of entry */
         struct exit_status ut_exit;     /* process termination/exit status */
         struct timeval ut_tv;           /* time entry was made */
         long    ut_session;             /* session ID, used for windowing */
         long    pad[5];                 /* reserved for future use */
         short   ut_syslen;              /* significant length of ut_host */
                                         /*   including terminating null */
         char    ut_host[257];           /* remote host name */
     } ;
```

Once you've got the output of `fwtmp`, it's easy to manipulate the
contents of `wtpmx` in whatever way you like. For instance, to strip out the
`monitor` and `nagios` user entries, I ran:

```cmd
# cd /var/adm
# /usr/lib/acct/fwtmp < wtmpx | egrep -v "^nagios|^monitor" | /usr/lib/acct/fwtmp -ic >wtmpx.new
# mv wtmpx.new wtmpx
```

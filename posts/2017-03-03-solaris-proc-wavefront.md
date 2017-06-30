---
title: "Wavefront and Solaris 04: /proc"
date: "2017-03-03"
tags: [Solaris, Wavefront, Diamond, /proc]
layout: post
category: Wavefront
---

### Previously on Twin Peaks

After some amount of (enjoyable!) work, I have very useful
Solaris-specific Wavefront dashboards. Most of the metrics come from
kstats, which has a very low overhead, and gives deep, accurate
introspection.

But, kstats consider the kernel's view of the system as a whole, and
sometimes it's handy to have a finer-grained view than that.

So, in this episode, I'm going to write something to look at
Solaris's `/proc` filesystem and produce metrics.

Linux `/proc` is a mess. Who knows what's in there. [Solaris
`/proc`](https://systemswe.love/videos/rogers-proc) isn't. It's very
clean, consistent, and, of course, well documented.  `man -s4 proc` will
tell you all you need to know.

### What the `/proc`?

You likely know that `/proc` contains one directory for each process
in the system. The name of the directory is the PID of the process.
Let's have a look at one.

```cmd
$ ls -l /proc/$$
-rw-------   1 rob      sysadmin 5877760 Mar  3 14:15 as
-r--------   1 rob      sysadmin     336 Mar  3 14:15 auxv
dr-x------   2 rob      sysadmin      32 Mar  3 14:15 contracts
-r--------   1 rob      sysadmin      32 Mar  3 14:15 cred
--w-------   1 rob      sysadmin       0 Mar  3 14:15 ctl
lr-x------   1 rob      sysadmin       0 Mar  3 14:15 cwd ->
dr-x------   2 rob      sysadmin     272 Mar  3 14:15 fd
-r--------   1 rob      sysadmin       0 Mar  3 14:15 ldt
-r--r--r--   1 rob      sysadmin     192 Mar  3 14:15 lpsinfo
-r--------   1 rob      sysadmin    1328 Mar  3 14:15 lstatus
-r--r--r--   1 rob      sysadmin    1072 Mar  3 14:15 lusage
dr-xr-xr-x   3 rob      sysadmin      64 Mar  3 14:15 lwp
-r--------   1 rob      sysadmin    2600 Mar  3 14:15 map
dr-x------   2 rob      sysadmin     544 Mar  3 14:15 object
-r--------   1 rob      sysadmin    4176 Mar  3 14:15 pagedata
dr-x------   2 rob      sysadmin     816 Mar  3 14:15 path
-r--------   1 rob      sysadmin      72 Mar  3 14:15 priv
-r--------   1 rob      sysadmin       0 Mar  3 14:15 prune
-r--r--r--   1 rob      sysadmin     440 Mar  3 14:15 psinfo
-r--------   1 rob      sysadmin    2600 Mar  3 14:15 rmap
lr-x------   1 rob      sysadmin       0 Mar  3 14:15 root ->
-r--------   1 rob      sysadmin    2304 Mar  3 14:15 sigact
-r--------   1 rob      sysadmin    1680 Mar  3 14:15 status
-r--r--r--   1 rob      sysadmin     504 Mar  3 14:15 usage
-r--------   1 rob      sysadmin       0 Mar  3 14:15 watch
-r--------   1 rob      sysadmin   40824 Mar  3 14:15 xmap
```

Unlike Linux, Solaris's `/proc` directory doesn't present all that
much from a simple `ls`. Beyond the user and group the process runs
as, there's not a lot of information at all. The timestamps on the
files are the time the process was launched. Also unlike Linux, none
of those files can be usefully accessed with simple tools like
`cat`.  Instead of just `cat`ting things, you're expected to use
tools like `pmap` or `pstack`, which are consumers of these binary
structures.  This is fine, and if we were writing instrumentation in
C, it would be trivially easy to read and use them. (I end up doing that
later.)

But, I'm writing a collector for Diamond, which means Python. And,
as this article will surely show, I'm not much of a Python
programmer.

One of the things I like about `/proc` is the careful use of file
permissions. Look at the example above and look at this:

```cmd
$ ls -ld /proc/$$
dr-x--x--x   5 rob      sysadmin     928 Mar  3 14:15 /proc/2208
```

Only a process owner can list the directories, and see other
senstive information. But the "other" execute bit is set on the
directory, and some files are world-readable, so if we're careful,
our unprivileged Diamond process will be able to see all system
processes.

First, I needed to decide what information I wanted. `/proc` gives
way more detail, particularly on LWPs, than I'm interested in. What
I want, at least for now, is to get the CPU and memory consumption
of the running processes, and I'd like to be able to aggregate and
filter that on process name and the zone in which the process run.

After a bit of though I decided to put the process name in the
metric path, then to tag each point with the PID of the process and
its zone. Tagging by PID forces Wavefront to separate multiple
processes with the same executable name, but it's trivial to wrap
them in a `sum()` if need be.  There's an equally valid
argument for dumping the whole lot on the same metric path and
having the exec name also be a tag, but this seemed a happy medium
to me. When I first started writing my Solaris collectors, I put the
zone name in the metric path, but it never quite seemed right having
to force `global` into things where it didn't really belong. So,
flatter namespace, more tags.  Tags are good. I'm a little concerned
about the PID tag being of too high cardinality, but I don't see
much alternative.

The `proc(4)` man page gives you the layout of the `/proc` data
structures, and they're also in `/usr/include/sys/procfs.h`, with a
little bit more annotation. From that file, here's
`psinfo`

```c
#define PRARGSZ   80  /* number of chars of arguments */
typedef struct psinfo {
  int pr_flag;  /* process flags (DEPRECATED; do not use) */
  int pr_nlwp;  /* number of active lwps in the process */
  pid_t pr_pid;   /* unique process id */
  pid_t pr_ppid;  /* process id of parent */
  pid_t pr_pgid;  /* pid of process group leader */
  pid_t pr_sid;   /* session id */
  uid_t pr_uid;   /* real user id */
  uid_t pr_euid;  /* effective user id */
  gid_t pr_gid;   /* real group id */
  gid_t pr_egid;  /* effective group id */
  uintptr_t pr_addr;  /* address of process */
  size_t  pr_size;  /* size of process image in Kbytes */
  size_t  pr_rssize;  /* resident set size in Kbytes */
  size_t  pr_pad1;
  dev_t pr_ttydev;  /* controlling tty device (or PRNODEV) */
      /* The following percent numbers are 16-bit binary */
      /* fractions [0 .. 1] with the binary point to the */
      /* right of the high-order bit (1.0 == 0x8000) */
  ushort_t pr_pctcpu; /* % of recent cpu time used by all lwps */
  ushort_t pr_pctmem; /* % of system memory used by process */
  timestruc_t pr_start; /* process start time, from the epoch */
  timestruc_t pr_time;  /* usr+sys cpu time for this process */
  timestruc_t pr_ctime; /* usr+sys cpu time for reaped children */
  char  pr_fname[PRFNSZ]; /* name of execed file */
  char  pr_psargs[PRARGSZ]; /* initial characters of arg list */
  int pr_wstat; /* if zombie, the wait() status */
  int pr_argc;  /* initial argument count */
  uintptr_t pr_argv;  /* address of initial argument vector */
  uintptr_t pr_envp;  /* address of initial environment vector */
  char  pr_dmodel;  /* data model of the process */
  char  pr_pad2[3];
  taskid_t pr_taskid; /* task id */
  projid_t pr_projid; /* project id */
  int pr_nzomb; /* number of zombie lwps in the process */
  poolid_t pr_poolid; /* pool id */
  zoneid_t pr_zoneid; /* zone id */
  id_t  pr_contract;  /* process contract */
  int pr_filler[1]; /* reserved for future use */
  lwpsinfo_t pr_lwp;  /* information for representative lwp */
} psinfo_t;
```

and here's `usage`:

```c
typedef struct prusage {
  id_t    pr_lwpid; /* lwp id.  0: process or defunct */
  int   pr_count; /* number of contributing lwps */
  timestruc_t pr_tstamp;  /* current time stamp */
  timestruc_t pr_create;  /* process/lwp creation time stamp */
  timestruc_t pr_term;  /* process/lwp termination time stamp */
  timestruc_t pr_rtime; /* total lwp real (elapsed) time */
  timestruc_t pr_utime; /* user level cpu time */
  timestruc_t pr_stime; /* system call cpu time */
  timestruc_t pr_ttime; /* other system trap cpu time */
  timestruc_t pr_tftime;  /* text page fault sleep time */
  timestruc_t pr_dftime;  /* data page fault sleep time */
  timestruc_t pr_kftime;  /* kernel page fault sleep time */
  timestruc_t pr_ltime; /* user lock wait sleep time */
  timestruc_t pr_slptime; /* all other sleep time */
  timestruc_t pr_wtime; /* wait-cpu (latency) time */
  timestruc_t pr_stoptime;  /* stopped time */
  timestruc_t filltime[6];  /* filler for future expansion */
  ulong_t   pr_minf;  /* minor page faults */
  ulong_t   pr_majf;  /* major page faults */
  ulong_t   pr_nswap; /* swaps */
  ulong_t   pr_inblk; /* input blocks */
  ulong_t   pr_oublk; /* output blocks */
  ulong_t   pr_msnd;  /* messages sent */
  ulong_t   pr_mrcv;  /* messages received */
  ulong_t   pr_sigs;  /* signals received */
  ulong_t   pr_vctx;  /* voluntary context switches */
  ulong_t   pr_ictx;  /* involuntary context switches */
  ulong_t   pr_sysc;  /* system calls */
  ulong_t   pr_ioch;  /* chars read and written */
  ulong_t   filler[10]; /* filler for future expansion */
} prusage_t;
```

Between them, those two structures reveal everything I want. And,
they're both universally accessible. So how the heck do I read a
binary `struct` in Python?

### Ruddy Python

I'm not the biggest Python fan. I don't think there's anything
*bad* about it, but it's never "clicked" with me in the way that
Ruby did. Writing Ruby, for me, is fun. Writing Python is work.
Rather dry work. But, I plough on, hopeful that one day I'll "get
it" and enjoy Python too.

It's straightforward to read a binary file into a variable, and once
that's done, you can use [Python's `struct`
module](https://docs.python.org/2/library/struct.html#module-struct)
to `unpack` the structure within. But, you need to know how to
describe that structure.

In C we define data types as, say, `char` or `int`, and the compiler
knows the sizes of those types. The `strutc` module requires you
define the incoming structures with characters, which are helpfully
listed in [a
table](https://docs.python.org/2/library/struct.html#format-characters).
With basic types like `ulong_t` or `int`, it's a simple lookup in
the table, but I had no idea what the underlying types of things
like `poolid_t` were, so I spent a fair amount of time hunting
through `/usr/include/sys/types.h` or running bits of C like

```c
#include <stdio.h>
#include <sys/types.h>

void main() {
  printf("%zu\n", sizeof(dev_t));
}
```

`timestruc_t` took a bit of tracking down, but it looks like this:

```c
typedef struct  timespec {    /* definition per POSIX.4 */
  time_t  tv_sec;   /* seconds */
  long    tv_nsec;  /* and nanoseconds */
} timespec_t;
```

So after a while, I had a format string identifying the whole of the
`usage` struct. `psinfo` was much more challenging, as it includes a
complex structure called `lwpsinfo_t`. I started trying to decode
this, but eventually realised I didn't want any of the information
in it, so I could discard it by telling my intial `read()` operation
to only read the file up to the point just before `lwpsinfo_t`
began.

I thought it would be nice to make a Python `dict` of each of the
`/proc` files I was interested in, so I ended up writing a "key"
`dict` to describe them:

```python
proc_parser = {
  'usage': {
    'fmt':  '=ii8s8s8s8s8s8s8s8s8s8s8s8s8s8s13L',
    'keys': ('pr_lwpid', 'pr_count', 'pr_tstamp', 'pr_create', 'pr_term',
             'pr_rtime', 'pr_utime', 'pr_stime', 'pr_ttime', 'pr_tftime',
             'pr_dftime', 'pr_kftime', 'pr_ltime', 'pr_slptime',
             'pr_wtime', 'pr_stoptime', 'pr_minf', 'pr_majf', 'pr_nswap',
             'pr_inblk', 'pr_oublk', 'pr_msnd', 'pr_mrcv', 'pr_sigs',
             'pr_vctx', 'pr_ictx', 'pr_sysc', 'pr_ioch'),
      'size': 172,
      'ts_t': ('pr_tstamp', 'pr_create', 'pr_term', 'pr_rtime', 'pr_utime',
               'pr_stime', 'pr_ttime', 'pr_tftime', 'pr_dftime',
               'pr_kftime', 'pr_ltime', 'pr_slptime', 'pr_wtime',
               'pr_stoptime')
  },
  'psinfo': {
    'fmt':  '=iiiiiiIIIIlLLLlHH8s8s8s16s80siills3siiiiiii',
    'keys': ('pr_flag', 'pr_nlwp', 'pr_pid', 'pr_ppid', 'pr_pgid',
             'pr_sid', 'pr_uid', 'pr_euid', 'pr_gid', 'pr_egid',
             'pr_addr', 'pr_size', 'pr_rssize', 'pr_pad1', 'pr_ttydev',
             'pr_pctcpu', 'pr_pctmem', 'pr_start', 'pr_time', 'pr_ctime',
             'pr_fname', 'pr_psargs', 'pr_wstat', 'pr_argc', 'pr_argv',
             'pr_envp', 'pr_dmodel', 'pr_pad2', 'pr_taskid', 'pr_projid',
             'pr_nzomb', 'pr_poolid', 'pr_zoneid', 'pr_contract'),
   'size': 232,
   'ts_t': ('pr_start', 'pr_time', 'pr_ctime'),
  },
}
```

The `ts_t` list is of all the `timestruc_t` fields. For my own
convenience I decided to turn all those into simple Python `float`s.

Then a simple method which uses that information to return a `dict`
which lets me easily access, say, `pr_zoneid`. (I've removed all the
error handling for brevity and clarity.)

```python
def proc_info(p_file, pid):
  parser = proc_parser[p_file]
  p_path = path.join('/proc', str(pid), p_file)
  raw = file(p_path, 'rb').read(parser['size'])

  ret = dict(zip(parser['keys'], struct.unpack(parser['fmt'], raw)))

  for k in parser['ts_t']:
    (s, n) = struct.unpack('lL', ret[k])
    ret[k] = (s * 1e9) + n

  return ret
```

I put all of this into a library, and went on to write the
collector.

### Collector

I saw my collector as closely analagous to `prstat(1)`, so I
frequently referred to that program's [source
code](https://github.com/illumos/illumos-gate/tree/master/usr/src/cmd/prstat).

The collector loops over every process in `/proc`, reading both
`psinfo` and `usage` and turning them into a single `dict`. The
person configuring Diamond is able to select any number of keys from
that dict and have them made into metrics under the `process`
namespace. Simple!

Except, of course, nothing's ever simple. A likely use for the new
`proc` collector is to show the busiest processes on a host, and
just how busy they are. Refer back to the `usage` structure, and you
can see that processes do keep track of that, using all those
`timestruc_t pr_*time`s. But they're cumulative, so the collector
has to do some sums. Diamond gives you a class variable,
`last_value` to memo things between runs, and using that and our
simple-to-work-with nanosecond times, it's easy to work out the time
each process spends on-CPU, literally, and as a percentage of
available time. Here's the CPU usage for the Java processes on one
of my hosts

<script src="https://metrics.wavefront.com/embedded/SsbW6tf7yf/js"
id="wavefront-embedded-SsbW6tf7yf" width="700" height="300"></script>

If you hover over that chart, you'll see the zone tags. These are
attached to every metric produced by the `proc` collector, using the
`pr_zoneid` value from `psinfo`. This  is the first field you see
when you do `zoneadm list -cv`; it's numeric, and it's not that
meaningful. (If you reboot a zone it will likely get a different
ID.) At the beginning of each collector run I shell out to `zoneadm`
and generate a map of zone ID to name. When it's time to send the
point, I look up the `pr_zoneid` value in the map, and tag with the
name.

Now on to memory, where I chose to follow `prstat(1)`, and offer the
RSS (resident set size) and SIZE columns. The latter is defined in
the `man` pages as
`The  total virtual memory size of the process, including all mapped
files and devices`. We can get the values from the `psinfo` struct's
`pr_rssize` and `pr_size` fields.

the The [`prstat` man page](https://illumos.org/man/1M/prstat) tells
us that memory sizes are displayed in K. I prefer to send all my
metrics as bytes, and let Wavefront handle the prefixes. Looking at
[the
source](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/prstat/prutil.c#L134-L147)
it seems that Sun chose to use "proper" K and M, not this Ki and Mi
nonsense. So, we multiply the raw figure by 1024.

f

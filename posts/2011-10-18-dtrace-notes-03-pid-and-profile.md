---
title: "DTrace notes 03: the pid and profile providers"
tags: [Solaris, DTrace]
date: "2011-10-08"
layout: post
category: Solaris
---

# pid

The main thing to remember here is the format of the probe name

```cmd
# dtrace -n pidx:library:function:entry/return
```

`pidx` means the literal string `pid` followed by the PID of the process
you're interested in. e.g. `pid482`. Library is as simple as `libc` or
`libsocket`.

You can get the objects in a running process by starting the debugger
with `mdb -p PID`, then doing `::objects`, or running `pldd` on the
process. The functions in a library can be got at with `nm
/path/to/library.so`. If you want to trace inside the executable itself
you use the executable name rather than a library name

PID probes are created dynamically, when you try to find them.

# profile

Profile probes fire at given time intervals. You can't choose any time
you can think of, but there are quite a few preset ones.

```cmd
$ dtrace -lP profile
```

lists them. By default the number after the dash means how many times
each second the probe will fire (so, Hz, I guess), but you can add on
`ms`, `us`, or `ns` to have them fire at an interval of that many
milli-, micro-, or nano-seconds. Or use `m`, `h` and `d` to have them
fire so many minutes, hours, or days.

The default numbers are chosen to as not to line-up with system clocks,
which tend to tick on frequency multiples of 10.

The `tick-` probes fire on a single CPU; the `profile-` probes fire on
all CPUs.

`arg0` and `arg1` store the program counter of the current instruction.
This is also called the instruction pointer, and it's a processor
register that keeps the memory address of the next instruction to be
executed. If the thread is in kernel space, the PC is in `arg0`, if it's
in user space, the PC is `arg1`.

# syscall


When a system call fails (i.e. returns `-1`), a global variable is set
to the value defined in `sys/errno.h`. These are the errors you look for
when you `truss` something. You know the kind of thing:

```cmd
$ truss ls /nosuchfile
...
lstat64("/nosuchfile", 0x080464E0)                Err#2 ENOENT
...
$ grep ENOENT /usr/include/sys/errno.h
#define ENOENT  2       /* No such file or directory            */
```

When the `syscall:::return` probe fires, and there's been an error,
`arg0` is set to `-1`, so if you're looking for them your predicate
would be `/arg0 == -1/`.

# Kernel Variables and data structures

It's important to know `curpsinfo`, which is a pointer to the `psinfo`
data structure for the current thread. You can find the full definition
for it in `sys/procfs.h`, but here it is anyway, because it's so useful.

```c
typedef struct psinfo {
    int       pr_flag;           /* process flags (DEPRECATED; do not use) */
    int       pr_nlwp;           /* number of active lwps in the process */
    pid_t     pr_pid;            /* unique process id */
    pid_t     pr_ppid;           /* process id of parent */
    pid_t     pr_pgid;           /* pid of process group leader */
    pid_t     pr_sid;            /* session id */
    uid_t     pr_uid;            /* real user id */
    uid_t     pr_euid;           /* effective user id */
    gid_t     pr_gid;            /* real group id */
    gid_t     pr_egid;           /* effective group id */
    uintptr_t pr_addr;           /* address of process */
    size_t    pr_size;           /* size of process image in Kbytes */
    size_t    pr_rssize;         /* resident set size in Kbytes */
    size_t    pr_pad1;
    dev_t     pr_ttydev;         /* controlling tty device (or PRNODEV) */
    ushort_t  pr_pctcpu;         /* % of recent cpu time used by all lwps */
    ushort_t  pr_pctmem;         /* % of system memory used by process */
    timestruc_t pr_start;        /* process start time, from the epoch */
    timestruc_t pr_time;         /* usr+sys cpu time for this process */
    timestruc_t pr_ctime;        /* usr+sys cpu time for reaped children */
    char      pr_fname[PRFNSZ];  /* name of execed file */
    char      pr_psargs[PRARGSZ];/* initial characters of arg list */
    int       pr_wstat;          /* if zombie, the wait() status */
    int       pr_argc;           /* initial argument count */
    uintptr_t pr_argv;           /* address of initial argument vector */
    uintptr_t pr_envp;           /* address of initial environment vector */
    char      pr_dmodel;         /* data model of the process */
    char      pr_pad2[3];
    taskid_t  pr_taskid;         /* task id */
    projid_t  pr_projid;         /* project id */
    int       pr_nzomb;          /* number of zombie lwps in the process */
    poolid_t  pr_poolid;         /* pool id */
    zoneid_t  pr_zoneid;         /* zone id */
    id_t      pr_contract;       /* process contract */
    int       pr_filler[1];      /* reserved for future use */
    lwpsinfo_t pr_lwp;           /* information for representative lwp */
} psinfo_t;
```

As you can see, that's the place to go for pretty much any information
on a process.

`curlwpsinfo` points  to the `lwpsinfo` structure, which is also in
`sys/procfs.h`. I haven't reprinted it here because I haven't had call
to use it. There's also a variable called `curcpu` which points to the
`cpuinfo` data structure. That tells you which CPU and processor set is
running your thread.

Though you can get to this same info by using `curthread`, which points
to `kthread_t`, these methods are considered "better" because they use a
proper API presented by the `proc` interface. (Check out `/proc`, it's a
bit like the Linux version, but only refers to processes. Each directory
has a bunch of files in which describe things to do with the process,
such as the open file descriptors or process map. Unlike Linux you can't
get things like the number of processors out of `/proc`, and it's
read-only.)

---
title: "DTrace notes 01: the vminfo and sysinfo providers"
tags: [Solaris, DTrace]
date: "2011-10-06"
layout: post
category: Solaris
---

I've been brushing up on my DTrace, and I thought it might be helpful to
someone somewhere if I wrote my notes up. They're more Solaris
background stuff that helped me understand what DTrace was doing than
any kind of DTrace HOWTO. Regular readers will know I hate the HOWTO
culture, so I've tried to flesh out my notes into a kind of noddy guide
to Solaris internals.

# `vminfo`

First, some definitions. And remember that the `vminfo` provider looks at
the same kinds of things as `vmstat`.

## Memory

* **a page** is a block of memory. 8kb on SPARCs, 4kb on my x86
  workstation, but can take on other sizes with modern MMUs.
  `pagesize` will tell you your, er, page size.

* **backup store/backing store**
  when physical memory starts getting tight, pages of memory are
  moved out to disk. The backup store for a page is location on disk
  where that page will be moved to.

When a process is started by `fork()`, memory is allocated. Memory
appears to the process as a contiguous block, but it isn't really - this
is a layer of abstraction provided by the MMU.

Each process has different areas (segments) of memory.

* **executable text**
  This is the machine code of the program - that which the compiler
  makes of all your instruction code. The backup store for these
  pages is the on-disk binary itself. This memory is read-only.  You
  can see executable pages being used with `execfree`, `execpgin`
  and `execpgout`. `vmstat` shows you how many kB of executables
  have been paged in, out, and freed in its `epi`, `epo` and `epf`
  fields.

* **initialized data/data/executable data**
  space for all the variables you initialize in your code with "`int
  i=0`" type instructions. This space is inside the on-disk
  executable, so again, the backup store is the on-disk binary.

* **uninitialized data/BSS**
  space for variables you initialize with no value.  (Though they're
  all set to 0 at runtime.)

the `size(1)` command shows you which parts of the binary are what.

```cmd
$ size /bin/ls
33576 + 2206 + 3894 = 39676

executable text + executable data + uninitialized data =
```


* **heap space**
  if you use `malloc()` to allocate memory in your program, it goes
  on the heap.

* **stack space**
  when the program calls a function information is stored which
  allows the program to resume after the function returns. (The
  address at which to resume excution etc.)

* **anonymous page**
  is memory not associated with a file - so it is that used for heap
  and stack spaces. When it's allocated for a heap, it's done with a
  `zfod` (zero fill on demand) operation, which maps `/dev/zero` to
  memory, filling the required space with zeroes.  Anonymous pages
  are also used for shared memory.  Watch them being paged in and
  out with the `anonpgin` and `anonpgout` probes, and see the
  running total with `vmstat`'s `api`, `apo` and `apf` columns.

* **freelist**
  when the system comes up, the physical memory is carved up into
  page sized chunks, and all those pages are put on the "freelist"
  to be used as required.

* **page freeing**
  the page scanner is constantly looking and recording which pages
  of physical memory are being used. (The `rev` probe fires each
  time it starts a scan, and `vmstat` shows you how many pages/sec
  it's scanning in the `sr` column.) When it thinks a page isn't
  being used, or at least not used enough to earn its keep, the
  scanner "reclaims" or "steals" that page from the holding process
  and adds it to the freelist. You can see when this happens with
  the `dfree` probe, and also one of `anonfree`, `execfree`, or
  `fsfree` probes, depending on what kind of page it was.  `vmstat`
  counts page reclaims in its `re` column, and the kB freed in the
  `fr` column. It also shows, under `de`, the anticipated shortfall
  in memory, which is how it works out how aggressively to steal
  pages back.

* **process swap**
  When memory gets tight, rather than putting the least-used pages
  in the swap device, an entire process can be moved from physical
  memory.  This is slow, and therefore not good. See this happening
  with `swapout` and `swapin`.

## page faults

Rather than allocate all the physical memory a program may require in
one go, which would be slow, and soon eat up all available memory, pages
are allocated "on demand". First all the spaces above are created as
virtual memory. When an address is accessed which doesn't have a
physical mapping, the MMU raises a "page fault" which tells the kernel
to send a trap to temporarily halt the process, give the process a page
of physical memory, or restore the page to physical memory from the
backup store ("swap it in"), then tell it to resume. So they're not
really faults, and definitely not errors. There are a few kinds:

* **major page fault/hard page fault**
  a page of memory is accessed which does not exist in physical
  memory. It normally means a disk access to get the missing page.
  The DTrace `maj_fault` probe fires with this happens. (Right after
  `pgin`, because, of course, we've paged data in.) Major page
  faults are counted in the `vm` counter of `kstat`, and can also be
  seen in the `majf` column when you run `mpstat`.

* **minor page fault/attach/soft page fault**
  a page is accessed which does exist in physical memory, but the
  process calling it doesn't know where, because there's no mapping
  in the MMU. This tends to happen when programs share the same
  memory space, so it's common for shared libraries. These show up
  as `minf` in the output of `mpstat`.

* **protection fault/page protection fault**
  occurs when a process tries to access a page in a way not allowed
  by its permissions. For example, writing to the text segment, or
  executing data on the stack if that operation has been disallowed.
  The `prot_fault` probe fires when this happens.

* **copy-on-write fault/COW fault**
  When a process spawns a child, the child can use the same
  exectuable text segment as the parent. Initially it may also use
  the same data segment. But if the child changes the data segment,
  its own private copy is created, raising a COW fault, and firing
  the `cow_fault` probe.

* **segmenation fault/invalid page fault**
  an error which occurs when a program tries to access memory at an
  address which is not mapped in any of the above segments.

# `sysinfo`

Again, more definitions so you know what you can look at. This provider
helps with the kinds of things we used to have to rely on `mpstat` to
tell us about.

* **traps**
  When a userland thread makes a system call, it temporarily runs in
  the kernel space. Access to the kernel is through "traps", which
  may be triggered as a result of an error such as a page fault, or
  a request for an interrupt. See them with the `trap` probe.

* **interrupts**
  are events generated by "important" things like hardware or the
  system clock, and when a CPU gets one, it temporarily stops what
  it's doing ("pins" the process) to deal with whatever the
  interrupting object had to say. Once its done that, execution of
  the orignal thread resumes.  Interrupts have different priority
  levels, so a higher priority interrupt thread can pin a lower one.
  You can disable interrupts to particular processors with processor
  sets, so workloads aren't interrupted. `intrstat` shows you which
  modules are interrupting which processors, and `mpstat`'s `intr`
  column shows you how many of them there are. Lower priority
  interrupts such as handling network or disk traffic are converted
  to threads, and the number of times that happens is shown by
  `mpstat` under `ithr`.

* **cross-calls**
  shown as `xcal` by `mpstat` and `xcalls` in `kstat -n sys`, are
  interrupts from one processor to another. They're caused by
  processors keeping synchronized caches as they unmap address
  space.  Therefore you get a lot of them when you're doing
  filesystem work.  (Particularly NFS.) Cross-calls are also used
  when a thread on one processor needs to tell a thread on another
  to enter kernel mode.  The `xcalls` probe fires just before a
  cross-call is made.

* **context switches and migrations**
  In this sense "context" refers to the set of processor registers
  associated with a thread. When a thread is blocked, say because
  it's waiting for data from a disk, the CPU is "idle" and looks for
  something else to do, so it gets a new thread and has to "switch
  context" so that new thread makes sense. `mpstat` counts these
  events in the `csw` column, and the `pswitch` probe fires whenever
  one occurs.

  Context switches can be "involuntary" (see `mpstat`'s `icsw`
  field) which means a thread is forced off the processor by one of
  higher priority, or that the thread's share of CPU time (called a
  "quantum") is up. DTrace probe `inv_switch` will catch these. The
  "switched out" context (like the stack pointer and program
  counter) goes into kernel registers.

  When a thread moves from one processor to another it's called a
  "migration". These are counted in `mpstat`'s `migr` column, and
  you need to use DTrace `sched` probes to find them.
  (`sched:::on-cpu` and `sched:::off-cpu`.)

* **locks**
  Because you've got multiple processors running kernel threads,
  it's vital that only one thread is able to alter kernel variables
  or data structures at once. So, the kernel has hundreds locks, and
  a thread must acquire the appropriate lock before it can alter a
  variable. This ensures all processors have the same --
  synchronized -- view of the system all the time. People talk about
  locks being "acquired", "set", "owned" or "held" - they all mean
  the same thing, and if you hold the lock, you can perform the
  operation.  DTrace has a specific `lockstat` provider, and there
  are two user commands, `lockstat` and `plockstat` which look at
  kernel and userland locks respectively. Since we're on an `mpstat`
  tip, the relevant columns there are `smtx`, which tells you how
  long the processor has been trying to acquire a mutex lock (a type
  of lock where, once you acquire it, you're the only one that can
  access the data), and `srw` counts the processor time spent trying
  to acquire readers/writer locks (which other threads can read, but
  only the lock owner can write).  Failed attempts to acquire these
  fire the `rw_rdfails` or `rw_wrfails` probe, depending on whether
  the thread wanted a read or write lock.  Mutex locks can be spin
  locks or adaptive locks. When you try to get a spin lock and
  can't, your thread "spins", trying the lock over and over again
  until it is acquired. The other approach is to "block", which
  means the thread leaves the processor, hopefully just until the
  lock can be acquired. This lets another thread run, but it means a
  context switch. Adaptive locks have some intelligent opinion on
  whether to spin or block, and when you try to acquire one, the
  `mutex_adenters` probe fires, followed by either `adaptive-block`
  or `adaptive-spin` -- both from the `lockstat` provider --
  depending on the action taken.

* **semaphores**
  A semaphore is a kind of counter which is bound to a resource.
  When a thread starts to use that resource, it increases by one the
  value of the associated semaphore. Other threads can look at that
  value and decide whether or not to access the resource. Once the
  original thread has finished with the resource, it decreases the
  value of the semaphore by one. When a semaphore operation is
  requested, the `sema` probe fires.

* **messages**
  Messages are used for interprocess communication. The `msg` probe
  fires when one is sent or received.

The main stuff in the `sysinfo` provider is looking at `fork`s and
`exec`s, but you can also (perhaps surprisingly?) get quite a lot of I/O
info through the `bread` and `bwrite` probes which are used for buffered
reading and writng. There's also some UFS stuff in there but hey, who's
using UFS these days? (In fact, who's using Solaris these days...?)

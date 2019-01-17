---
title: "Porting Crystal to Solaris and SmartOS"
date: "2019-01-16"
tags: [Crystal, Solaris, SmartOs, failure]
layout: post
category: programming
---

I like Ruby. I love its expressive nature and general Lisp-iness,
but I don't like its dependency chains and, sometimes, its speed. I
dislike Go. I love its single binaries and its speed, but I don't
like its boilerplate, type system, or its dictatorial ethos.

What I'm starting to really like, is
[Crystal](https://crystal-lang.org/).  Looks like Ruby (a *lot* like
Ruby. I've had -- admittedly small -- Ruby programs compile into
Crystal with no modifications at all!), runs very fast, and compiles
to a single binary.

Problem is, I have a Solarish addiction that I can't kick, and
Crystal does not support anything that reports as `SunOS`.

There are no native binaries for Solaris or Illumos, and it doesn't
even run in a SmartOS LX zone. (For the curious, I've opened [an
issue against
illumos-joyent](https://github.com/joyent/illumos-joyent/issues/186)
which describes this.)

So, as a dumb-ass sys-admin who last wrote C in anger in the 1990s, I
decided to try porting Crystal myself. (You can see where this is going,
can't you?)

## Set Up Linux

Crystal is written in Crystal, and backed by LLVM. Porting to a new
platform involves describing a set of C interfaces to Crystal using
its [rather elegant
syntax](https://github.com/crystal-lang/crystal-book/tree/master/syntax_and_semantics/c_bindings),
and cross-compiling. I chose Ubuntu Linux 16.04 as my starting
point, and Crystal 0.27, forked from
[Github](https://github.com/crystal-lang/crystal).

LLVM 6.x is supported by this version of Crystal, but there is a
show-stopping bug in 6.0.0.  (Which, frustratingly, is the version
shipped by default with every OS I looked at.) So I decided to play
it safe and use 5.0, even though this ended up making me more work.

I set up an Ubuntu 16.04 (6b47e1d9-36b8-4b6f-8764-5ff5fe6d120b) KVM
on a SmartOS box, and gave it 4Gb of RAM. I found that with 2Gb (my
default build), cross-compilation could fail.

Next I installed the needful packages. Because it's written in
Crystal, you obviously need Crystal to build Crystal. We also need
stuff to build the LLVM parts.

```cmd
$ curl -sL "https://keybase.io/crystal/pgp_keys.asc" | sudo apt-key add -
$ echo "deb https://dist.crystal-lang.org/apt crystal main" | \
  sudo tee /etc/apt/sources.list.d/crystal.list
$ sudo apt update
$ sudo apt install build-essential libgc-dev llvm-5.0 crystal
```

I did all the following as the default `ubuntu` user. You don't need
to do any further configuration of the host.

## Set Up Solaris

Though I much prefer SmartOS these days, I chose to target Solaris
11.4. I felt this offered the path of least resistance, as its C
library seems to be more on a par with modern Linux than SmartOS's.
I figured that Linux to Solaris was step one, then Solaris to
SmartOS step two. I very much need to make this as easy for myself
as I can.

We'll be building object files on Linux, then linking them on
Solaris, so we'll need GCC.

```cmd
# pkg install developer/gcc-7 developer/build/gnu-make
```

Crystal requires [the Boehm GC](http://www.hboehm.info/gc/). Solaris
doesn't have a native package for that, but it's written properly,
so compiles without fuss.  You need the `libatomic_ops` source too.
I'll stick it in `/usr/local/gc`.

```cmd
$ wget http://www.hboehm.info/gc/gc_source/gc-7.6.8.tar.gz
$ tar zxf gc-7.6.8.tar.gz
$ cd gc-7.6.8
$ wget http://www.hboehm.info/gc/gc_source/libatomic_ops-7.6.6.tar.gz
$ tar zxf libatomic_ops-7.6.6.tar.gz
$ mv libatomic_ops-7.6.6 libatomic_ops
$ ./configure --prefix=/usr/local/gc
$ gmake -j4
...
# gmake install
```

We also need LLVM. Oracle give us 6.0.0, (as do Ubuntu) but there's
the aforementioned bug which pushes us back to 5.0. (Also, when I
began this work with Crystal 0.24, 6.x was not supported.) Back to
the compiler. This was a bit more effort.

```cmd
$ wget https://releases.llvm.org/5.0.2/llvm-5.0.2.src.tar.xz
$ gtar xf llvm-5.0.2.src.tar.xz
$ mkdir OBJDIR
$ cd OBJDIR
$ CC=gcc cmake -G "Unix Makefiles" -DLLVM_BUILD_LLVM_DYLIB=true \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXE_LINKER_FLAGS="-z gnu-version-script-compat" \
  -DCMAKE_INSTALL_PREFIX=/usr/local/llvm ../llvm-5.0.2.src
$ gmake -j4
```

The build fails with

```
[ 31%] Linking CXX shared module ../../LLVMHello.so
ld: fatal: option --version-script requires option -z gnu-version-script-compat to be specified
collect2: error: ld returned 1 exit status
```

I'm not much of a `cmake` guru, but I eventually worked out that the
way to pass that option to `ld` was to modifly LLVM's top-level
`CMakeLists.txt`. (Line-break for formatting purposes.) This is
probably a gross hack, but it works.

```
if (UNIX AND NOT APPLE AND NOT ${CMAKE_SYSTEM_NAME} MATCHES
 "SunOS|AIX")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} \
  -Wl,-allow-shlib-undefined -z gnu-version-script-compat")
endif()
```

Then I was able to configure and build cleanly. I had to specify GCC because
my build box has Studio CC on it, and `cmake` defaulted to that.

```cmd
$ CC=gcc cmake -DCMAKE_INSTALL_PREFIX=/usr/local/llvm ../llvm-5.0.2.src
$ gmake
...
# gmake install
...
```

The build takes ages, and doing it parallel exhausted all the memory
in the zone at the linking phase!

## Porting Crystal -- Bindings and if-ladders

The main job is to define what Solaris "looks like". Every supported
operating system is described through a bunch of Crystal files under
`src/lib/lib_c`. The name of the directory containing them must be whatever
LLVM calls your platform.

```cmd
$ /usr/local/llvm/bin/llvm-config --host-target
x86_64-pc-solaris2.11
```

I figured that Linux is probably the most similar platform, so I
copied its directory and started hacking.

Crystal has its own types which align with the basic C types.
They're denoted by a capital letter, so an `Int` maps to the
underlying `int`. For the `_t` types we expect to see in our libC
headers, the convention is to CamelCase. So `sock_addr_t` is
`SockAddrT`. Structs and unions look a little like Ruby blocks. For
example:

```c
struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};
```

becomes

```ruby
struct Timezone
  tz_minuteswest : Int
  tz_dsttime     : Int
end
```

Functions are defined in a similar way. `man connect` gives us the
function signature

```c
int connect(int socket, const struct sockaddr *address, socklen_t address_len);
```

and we can create a Crystal binding to that with

```ruby
fun connect(fd : Int, addr : Sockaddr*, len : SocklenT) : Int
```

All of this happens in the `LibC` namespace: that is to say that all
the definitions are inside a

```ruby

lib LibC
...
end
```

block. In this way we build a bridge between Crystal and the
underlying operating system.

After much `ggrep -r`-ing of `/usr/include`, and much consultation
of [Solaris Systems
Programming](https://wordery.com/solaris-systems-programming-paperback-rich-teer-9780768682236),
I had something that looked fairly okay. It's [in a Git
branch](https://github.com/snltd/crystal/tree/feature/solaris-smartos_support).

I also had to make a few changes to the Crystal source. It's
sprinkled with `if` ladders to handle various OS specifics, and I
had to add another clause [here and
there](https://github.com/crystal-lang/crystal/compare/master...snltd:feature/solaris-smartos_support).

There are a number of things I'm unsure of.

* [`errno`
  handling](https://github.com/snltd/crystal/blob/feature/solaris-smartos_support/src/errno.cr).
  I chased this through `/usr/include` until my brain melted. I may
  well have done this wrong.
* [the pthread bindings](https://github.com/snltd/crystal/blob/feature/solaris-smartos_support/src/lib_c/x86_64-pc-solaris2.11/c/pthread.cr)
  and  [the
  types](https://github.com/snltd/crystal/blob/feature/solaris-smartos_support/src/lib_c/x86_64-pc-solaris2.11/c/pthread.cr)
  they use. Though I'm as certain as I can be, some of them got a
  bit complicated.
* In `c/signal.cr` I need to define `SigsetT`. `/usr/include/sys/signal.h`
  defines this type as
  ```c
  typedef struct {    /* signal set type */
        unsigned int  __sigbits[4];
  } sigset_t;
  ```
  I am unsure how to correctly represent the implementation-specific
  `__sigbits[]`.
* Illumos, as I mentioned, lacks `dprintf()`. In an earlier
  iteration of this work I put if-ladders in the code to use
  `sprintf()` instead, but I haven't done that this time around. It
  felt dirty, and I'm not sure what the "correct" fix should be. I'm
  also sure I heard `dprint()` was coming to Illumos...

There's a [posix binding
generator](https://github.com/ysbaddaden/posix) to generate the
`lib_c` stuff for you, presumably, with less guesswork than I used.
But, it needs a working Crystal port to build it. As soon as I get a
Solaris Crystal binary I'll revisit the bindings with this tool.
It's an iterative process.

## Build a Solaris-aware Crystal

Now the bindings are -- to some degree -- in place, we have to build
a version of Crystal which can use them. So, in the checked-out
`crystal` directory on the Linux box:

```cmd
$ make
```

This makes a new `.build/crystal` executable. You run this through the
`bin/crystal` wrapper.

```cmd
$ bin/crystal --version
Using compiled compiler at `.build/crystal'
Crystal 0.27.1-dev [b2b3b36] (2019-01-16)

LLVM: 5.0.0
Default target: x86_64-pc-linux-gnu
```

## Cross-compile Something

I wrote a one-liner: `test.cr`.

```cmd
echo '1.upto(5) { |i| puts i }' >test.cr
$ crystal run test.cr
1
2
3
4
5
```

And cross-compiled it to `test.o` with

```cmd
$ bin/crystal build --cross-compile --target x86_64-pc-solaris2.11 test.cr
Using compiled compiler at `.build/crystal'
cc 'test.o' -o 'test'  -rdynamic  -lpcre -lgc -lpthread \
/home/ubuntu/crystal/src/ext/libcrystal.a -levent -L/usr/lib -L/usr/local/lib
$ ls -l test.o
-rw-rw-r-- 1 ubuntu ubuntu 406904 Jan 17 11:44 test.o
```

Any Crystal program needs `setup_sigfault_handler`, which is in
`./src/ext/libcrystal.a`.  Copy that to the Solaris box along with
`test.o`.

Then, on the Solaris box, link.

```cmd
$ gcc -L/opt/local/lib -m64 -o test test.o -lpcre -levent libcrystal.a \
  -lpthread -lssp -L /usr/local/gc/lib -lgc -R/usr/local/gc/lib
$ ./test
1
2
3
4
5
```

First success! A Crystal program running on Solaris.

The linking did not work for me when I tried it on SmartOS. The error was:

```cmd
ld: fatal: relocation error: file libcrystal.a(sigfault.o): section [2].rela.text: invalid relocation type: 0x2a
```

## Cross Compiling Crystal Itself

Now things start to get difficult.

On the Linux box, compile the compiler. This will create a `crystal.o`
object file.

```cmd
$ bin/crystal build --cross-compile --target x86_64-pc-solaris2.11 \
  src/compiler/crystal.cr -D without_openssl -D without_zlib
Using compiled compiler at `.build/crystal'
cc 'crystal.o' -o 'crystal'  -rdynamic /home/ubuntu/crystal/src/llvm/ext/llvm_ext.o
`/usr/bin/llvm-config-5.0 --libs --system-libs --ldflags 2> /dev/null`
-lstdc++ -lpcre -lgc -lpthread /home/ubuntu/crystal/src/ext/libcrystal.a
-levent -L/usr/lib -L/usr/local/lib
$ ls -l crystal.o
-rw-rw-r-- 1 ubuntu ubuntu 26602456 Jan 16 12:12 crystal.o
```

Copy `crystal.o` to Solaris, and link it.

```cmd
$ gcc -o crystal crystal.o -L/usr/local/gc/lib -lgc libcrystal.a \
  -lssp -lm -lstdc++ -lncurses -lpcre -levent -lz \
  $(llvm-config --ldflags) $(llvm-config --libs) llvm_ext.o -R \
  /usr/local/gc/lib
$ ls -l crystal
-rwxr-xr-x 1 rob sysadmin 69698136 Jan 17 12:07 crystal
$ file crystal
crystal: ELF 64-bit LSB executable AMD64 Version 1, dynamically linked, not stripped
$ ./crystal version
Crystal 0.27.1-dev (2019-01-17)

LLVM: 5.0.0
Default target: x86_64-pc-solaris2.11
```

Looks promising, right?

```cmd
$ ./crystal eval "puts 123"
flags is Set{"x86_64", "pc", "solaris2.11"}
environment is solaris2.11
environment is solaris2.11
while requiring "prelude" (Exception)
  from Crystal::TopLevelVisitor@Crystal::SemanticVisitor#visit<Crystal::Require>:Bool
  from Crystal::ASTNode+@Crystal::ASTNode#accept<Crystal::TopLevelVisitor>:Nil
  from Crystal::TopLevelVisitor#visit<Crystal::Expressions>:Bool
  from Crystal::ASTNode+@Crystal::ASTNode#accept<Crystal::TopLevelVisitor>:Nil
  from Crystal::Program#top_level_semantic<Crystal::ASTNode+>:Tuple(Crystal::ASTNode+, Crystal::TypeDeclarationProcessor)
  from Crystal::Program#semantic<Crystal::ASTNode+, Bool>:Crystal::ASTNode+
  from Crystal::Compiler#compile<Array(Crystal::Compiler::Source), String>:Crystal::Compiler::Result
  from Crystal::Command#eval:NoReturn
  from Crystal::Command#run:(Bool | Crystal::Compiler::Result | Nil)
  from Crystal::Command::run<Array(String)>:(Bool | Crystal::Compiler::Result | Nil)
  from Crystal::Command::run:(Bool | Crystal::Compiler::Result | Nil)
  from __crystal_main
  from Crystal::main_user_code<Int32, Pointer(Pointer(UInt8))>:Nil
  from Crystal::main<Int32, Pointer(Pointer(UInt8))>:Int32
  from main
  from _start
Caused by: can't find file 'prelude'
```

This isn't actually a problem. It just means Crystal can't find its standard
library (I don't know why this is: I didn't have this problem with 0.24.)
It's easily worked around, for now. I'll work out the proper, permanent fix
if I ever get Crystal running properly.

```cmd
$ ./crystal env
CRYSTAL_CACHE_DIR="/home/rob/.cache/crystal"
CRYSTAL_PATH=""
CRYSTAL_VERSION="0.27.1-dev"
$ export CRYSTAL_PATH=lib
```

Now things get properly bad.

```cmd
$ ./crystal eval "puts 123"
Memory fault(coredump)
```

[Here's a gist of `truss` following that
command](https://gist.github.com/snltd/55160961798481d28703055a7e006f98).

And here's what `pstack` knows.

```cmd
core 'core' of 277:     ./crystal eval puts 123
------------  lwp# 1 / thread# 1  ---------------
 00007fffbdbb16f8 errno ()
------------  lwp# 2 / thread# 2  ---------------
 00007fffbda4eb07 __lwp_park () + 17
 00007fffbda47713 cond_wait_queue () + 63
 00007fffbda47cef __cond_wait () + 7f
 00007fffbda47d3d cond_wait () + 1d
 00007fffbda47d79 pthread_cond_wait () + 9
 00007ffef932f6b7 GC_wait_marker () + 17
 00007ffef9326352 GC_help_marker () + 32
 00007ffef932f68c GC_mark_thread () + 5c
 00007fffbda4e7e4 _thrp_setup () + a4
 00007fffbda4eac0 _lwp_start ()
------------  lwp# 3 / thread# 3  ---------------
 00007fffbda4eb07 __lwp_park () + 17
 00007fffbda47713 cond_wait_queue () + 63
 00007fffbda47cef __cond_wait () + 7f
 00007fffbda47d3d cond_wait () + 1d
 00007fffbda47d79 pthread_cond_wait () + 9
 00007ffef932f6b7 GC_wait_marker () + 17
 00007ffef9326352 GC_help_marker () + 32
 00007ffef932f68c GC_mark_thread () + 5c
 00007fffbda4e7e4 _thrp_setup () + a4
 00007fffbda4eac0 _lwp_start ()
------------  lwp# 4 / thread# 4  ---------------
 00007fffbda4eb07 __lwp_park () + 17
 00007fffbda47713 cond_wait_queue () + 63
 00007fffbda47cef __cond_wait () + 7f
 00007fffbda47d3d cond_wait () + 1d
 00007fffbda47d79 pthread_cond_wait () + 9
 00007ffef932f6b7 GC_wait_marker () + 17
 00007ffef9326352 GC_help_marker () + 32
 00007ffef932f68c GC_mark_thread () + 5c
 00007fffbda4e7e4 _thrp_setup () + a4
 00007fffbda4eac0 _lwp_start ()
```

I [updated the original Github
issue](https://github.com/crystal-lang/crystal/issues/3173) with
this, and the Crystal devs pointed me to the assembler code which
does fiber context switching. I've been on and beyond the limits of
my knowledge right through this exercise, and
[this](https://github.com/crystal-lang/crystal/blob/master/src/fiber/x86_64.cr)
is way off my radar. The last assembly code I looked at was for the
Z80, on a Spectrum, more than thirty years ago. Though I know what
the words mean, I couldn't make any connection between what I know
of Solaris, or could find buried in man pages or `/usr/include`, and
fiber assembler.

So here, sadly, ends my adventure trying to port Crystal to Solaris.
Possibly some of what I've done could help someone smarter than me,
but I've had to stretch myself on every aspect of this, and I am not
altogether confident in the quality of the work. That said, the fact
that a basic one-liner links and runs suggests I've got *something*
right.

I have a feeling that the intersect of "people who want to write
Crystal" and "people who want to use SmartOS" might be just me, so
this port will likely never work. But at least I tried, eh? And
learnt a couple of things on the way.

## Bibliography and Useful Links

* ["Add Illumos/Solaris support"
  issue](https://github.com/crystal-lang/crystal/issues/3173)
* [OpenBSD support PR](https://github.com/crystal-lang/crystal/pull/3369)
* [initial OpenBSD support PR](https://github.com/crystal-lang/crystal/pull/3326)
* [my experimental branch of Crystal](https://github.com/snltd/crystal/tree/feature/solaris-smartos_support)
* [truss output running cross-compiled
  crystal](https://gist.github.com/snltd/55160961798481d28703055a7e006f98)

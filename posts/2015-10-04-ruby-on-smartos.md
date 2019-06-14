---
title: "Building Ruby 2.2 for SmartOS"
tags: [SmartOS, Ruby]
date: 2015-10-04
category: Illumos
layout: post
---

SmartOS's `pkgin` support is great, but, if you're an
obsessive-compulsive minimalist, (which I am) things like the
following can upset you:

```cmd
$ pkgin show-full-deps ruby22
full dependency tree for ruby22-2.2.2
        expat>=2.0.0nb1
        png>=1.6.0nb1
        bzip2>=1.0.3
        libxcb>=1.8.1
        libXdmcp>=0.99
        libXau>=1.0
        libXrender>=0.9.2
        freetype2>=2.4.11
        fontconfig>=2.10.93nb2
        libXft>=2.3.1nb3
        libXext>=0.99.0
        libX11>=1.1
        ncurses>=5.4nb1
        gettext-lib>=0.18
        pkg_install-info-[0-9]*
        gcc47-libs>=4.7.0
        zlib>=1.2.3
        openssl>=1.0.1c
        libyaml>=0.1.4
        libiconv>=1.9.1nb4
        db4>=4.8.30
        libffi>=3.0.11
        gdbm>=1.10nb3
        readline>=6.0
        tk>=8.6.1
        tcl>=8.6.1nb1
        ruby22-tk>=2.2.2
        ruby22-readline>=2.2.2
        ruby22-gdbm>=2.2.2
        ruby22-fiddle>=2.2.2
        ruby22-base>=2.2.2
```

I asked for Ruby, not TCL, and I strongly object to needing X
libraries to run a Ruby script. So, I chose to build it myself. I
spun up a native zone, and installed the needful:

```cmd
# pkgin gcc48 gmake
```

Then downloaded the Ruby 2.2.3 source code, unpacked it, and configured
with:

```cmd
$ ./configure \
  --with-opt-dir=/opt/local \
  --prefix=/opt/local/ruby \
  --disable-install-doc
```

`configure` failed, telling me

```
configure: error: cannot compute sizeof (long long)
```

Digging into `config.log` I found that `libgmp` wasn't being found.
This being SmartOS, that's in `/opt/local/lib`, which isn't, by
default, looked in by the linker. So:

```cmd
# crle -64 -u -l /opt/local/lib
```

and everything is happy.

I ended up building and rebuilding Ruby sufficient times to have to
[write a
script](https://github.com/snltd/smartos-gubbins/blob/master/misc_scripts/build_ruby.sh)
to automate the process.

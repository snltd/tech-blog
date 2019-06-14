---
title: "Solaris, uPNP, Linn, and MiniDLNA"
tags: [Solaris, music, audio]
date: 2014-10-22
category: Solaris
layout: post
---

Years ago I built a media server on Solaris 11 11/11 with Fuppes. It
worked great, until I upgraded to 11.1, when it broke. As that was
pretty much all the box did, I rolled back to 11/11 and everything was
fine. But recently I decided that a three year old OS wasn't on, and
moved to 11.2. Again, Fuppes broke. So much for binary compatibility. I
spent a weekend in `mdb` and `scat`, but with next to no C++ knowledge
and severely rusty debugging skills, I wasn't able to fix the problem.
(A segfault caused by the HTTP server part of Fuppes.)

I messed about with alternatives, but I couldn't get anything working on
Solaris which I liked, so I was without a media server. I set one up on
a Linux box, but that was too many boxes, and I don't like Linux. Then I
thought about getting a Raspberry Pi, and running that as a media
server, NFS mounting the content from the Solaris box. Before I did
that, I looked to make sure I could run a UPnP server on Raspberry Pi,
and that led me to MiniDLNA. I looked at the source, and I thought "I
bet that runs on Solaris". It does. In fact, it turns out to be smaller,
more stable, and with better functionality than Fuppes.

## Building `ffmpeg`

MiniDLNA is a full-fledged media server. It deals in all manner of
things, and to do that, it uses `ffmpeg`. So, get that and build it. At
the time of writing the latest and (presumably) greatest is 2.4.2, so I
got that.

`ffmpeg` can deal with all the audio and video codecs under the Sun, but
all I want is something to stream FLACs to my DS. So, I'm going to
disable pretty much all functionality.  If you want to serve video, that
will work just fine.

I'm building with GCC. Years ago I would have fought the good fight and
done what I could to get it built with Sun Studio, but that war's been
lost, I'm too old to care these days.

I want FLAC and MP3 support, and I also want to display JPEG cover art,
so I'm going to need those libraries.

```cmd
# pkg install image/library/libexif codec/ogg-vorbis codec/flac
```

Don't worry: they won't pull in a load of junk and pollute your system.

We're going to need the shared libraries later, and you have to ask for them.

```cmd
$ ./configure --prefix=/usr/local/ffmpeg \
  --enable-shared \
  --disable-static \
  --disable-ffmpeg \
  --disable-ffplay \
  --disable-ffprobe \
  --disable-ffserver \
  --disable-doc \
  --disable-swscale-alpha \
  --disable-swresample \
  --disable-swscale \
  --disable-postproc \
  --disable-avfilter \
  --disable-network \
  --disable-dct \
  --disable-dwt \
  --disable-lsp \
  --disable-mdct \
  --disable-rdft \
  --disable-fft \
  --disable-faan \
  --disable-pixelutils \
  --disable-everything \
  --disable-xlib \
  --disable-debug
$ gmake -j4
```

That, shock of shocks, compiles cleanly for me first time and, as we're
compiling so little, it's very quick. Installation, however, doesn't work:

```cmd
# gmake install
INSTALL libavdevice/libavdevice.a
find: cycle detected for /lib/secure/32/
...
find: cycle detected for /usr/lib/link_audit/32/
install: libavdevice.a was not found anywhere!
gmake: *** [install-libavdevice-static] Error 2
```

This is an easy fix though:

```cmd
$ vim +101 config.mak
```

and change the `=install` to `=ginstall`. Then, assuming you have GNU
`install`, you can `gmake install` and all will be good.

## Building MiniDLNA

Now, get MiniDLNA. I used version 1.1.4. I'd have like to have built a
static binary, and just dropped that into its own zone, but as Oracle
don't give us static versions of `libjpeg`, `libsqlite3` and so on, that
would require a fair bit of legwork.

There are a couple of things I wanted to change. First, I *hate* that
stupid Linux penguin and, by default, that is the icon you'll get for
your MiniDNLA server if you build on Solaris. Let's honour SunOS's BSD
heritage by forcing it to usethe BSD daemon instead.

```cmd
$ vi +1104 icons.c
```

and change the `elif` to `#elifdef __Solaris__`.

Next, stop MiniDLNA resizing cover art to 160x160 pixels. I believe the
UPnP spec caps cover art at 500x500px, so let's use that.

```cmd
$ gsed -i 's/160/500/g' albumart.c
$ CFLAGS="-I/usr/local/ffmpeg/include" \
  LDFLAGS="-L/usr/local/ffmpeg/lib" \
  ./configure --prefix=/usr/local/minidlna \
  --with-os-name=Solaris --with-os-version=11.2
```

Now you have `config.h`, add

```c
#define __Solaris__
```

somewhere near the top, and try a `gmake`. It will pretty quickly hit
the buffers with:

```
gmake[2]: Entering directory `/build/minidlna-1.1.4'
CC       image_utils.o
image_utils.c:39:20: error: endian.h: No such file or directory
```

Which is a perfectly valid error, as Solaris doesn't have `endian.h`. Instead,
it keeps its definitions of endianness, alignment and whatnot, in `isa_defs.h`.
So:

```cmd
$ ggrep -rl '<endian.h>' . | while read f
> do
> gsed -i 's|<endian.h>|<sys/isa_defs.h>|' $f
> done
```

No, I'm not doing this properly. I'm not making patch files or adding proper
includes. This is a purely selfish "make it work" approach.

Run `gmake` again, and it'll crap out with a load of undefined symbols. As is
so often the case with Solaris, we'll have to tell the linker to use the socket
libraries. Less usually, we have to tell it to link against `libsendfile`.

```cmd
$ vim +407 Makefile
```

And add

```
-lsocket \
-lnsl \
-lsendfile \
```

to the `minidlnad_LDADD` line.  Run `gmake` again, and it still won't work:

```
Undefined                       first referenced
 symbol                             in file
MAX                                 minidlna.o
MIN                                 upnphttp.o
```

What? I don't recall those being in the standard library. Remember: we're in
the world of Linux here, where bad code and no thought of side-effects rule.
You're going to have to add macros for `MAX` and `MIN` which, I presume,
already exist in `glibc`. (Though, of course, glibc is technically
nothing to do with Linux.)

The block of code which will do the fix needs to look something like this

```c
#define MAX(a,b) ((a) > (b) ? a : b)
#define MIN(a,b) ((a) < (b) ? a : b)
```

and if you pop it into the top of `config.h` it'll get everywhere it
needs to.  Run `gmake` one last time and everything will be built.
`gmake install` as root, and you have everything you need in
`/usr/local/minidlna` and `/usr/local/ffmpeg`. Pick those up, drop them
in a zone, and you're pretty much done. Alternatively, package them up
with `fpm`.

```cmd
$ fpm -s dir -t solaris  -v 2.4.2 -n SNLTDffmpeg /usr/local/ffmpeg
$ fpm -s dir -t solaris  -v 1.1.4 -n SNLTDminidlna /usr/local/minidlna
```

## Installing and Configuring

I moved my binaries to a clean, minimal zone, and I found a bunch of shared
libs were missing, even after telling the runtime linker where FFMPEG was:

```cmd
# crle -u -l /usr/local/ffmpeg/lib
$ find /usr/local/minidlna -follow -type f | xargs ldd 2>/dev/null | grep "not found" | sort -u
libexif.so.12 =>    (file not found)
libFLAC.so.8 =>     (file not found)
libid3tag.so.0 =>   (file not found)
libogg.so.0 =>      (file not found)
libvorbis.so.0 =>   (file not found)
```

To fix this, I just had to run the `pkg` command from the top of the page.

I created a config file at `/config/minidlna/minidlna.conf` with the
following contents:

```
media_dir=A,/storage/flac
friendly_name=tap-media
album_art_names=front.jpg
db_dir=/var/cache/minidlna
log_dir=/var/log
inotify=no
```

Then imported the following service manifest:

```xml
<pre>
<?xml version='1.0'?>
<!DOCTYPE service_bundle SYSTEM '/usr/share/lib/xml/dtd/service_bundle.dtd.1'>
<service_bundle type='manifest' name='export'>
  <service name='snltd/minidlna' type='service' version='0'>
    <create_default_instance enabled='true'/>
    <single_instance/>
    <dependency name='filesystem' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/system/filesystem/local'/>
    </dependency>
    <dependency name='network' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/network/initial'/>
    </dependency>
    <exec_method
      name='start'
      type='method'
      exec='/usr/local/minidlna/sbin/minidlnad -u minidlna -f /config/minidlna/minidlna.conf'
      timeout_seconds='30'/>
    <exec_method name='stop' type='method' exec=':kill' timeout_seconds='30'>
    </exec_method>
    <stability value='Unstable'/>
    <template>
      <common_name>
        <loctext xml:lang='C'>minidlna UPnP server</loctext>
      </common_name>
    </template>
  </service>
</service_bundle>
</pre>
```

And I was off.

## Update

I've written [a Puppet
module](https://github.com/snltd/puppet/tree/master/modules/minidlna) to
do the installation.

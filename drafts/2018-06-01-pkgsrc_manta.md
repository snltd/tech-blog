---
title: "Making a pkgsrc server with Manta"
date: "2018-06-01"
tags: [Manta, Serverless]
layout: post
category: Serverless
---

## There's More to Life than AWS

About five years ago Joyent [announced
Manta](https://www.joyent.com/blog/hello-manta-bringing-unix-to-big-data).
From a distance it looked like just another S3-style object store,
but the twist was that by spinning up a
[zone](https://wiki.smartos.org/display/DOC/Zones) around any of
your objects, it allowed you to operate on the data *in place*. In
fact, it went further than that, offering a map-reduce pattern: run
any operation on any number of files, in parallel, and use any other
operation to combine the output of those tasks.

By "any operation", I mean any *program*. You don't write a function,
you run, on Unix, anything which runs on Unix.
That might be as obvious as `grep`ping a hundred logs in your map
phase and `awk`ing the results together. But if you're tired of
waiting for Amazon to support
[Malbolge](https://esolangs.org/wiki/Malbolge) Lambdas, Manta might
be able to help you out.

I run my cloud stuff in Triton, and like everyone else I want to
keep my data close to my compute. So for some years I've used Manta
as a straight object store; a function it performs admirably. Though
I loved the *idea* of doing something with that data, I never really
needed to.

For a long time now I've been deploying from a Github hook, even
though I don't particularly like the approach, and would prefer to
deliver code code to my hosts as native OS packages. I've done this
lots of times in the past on various platforms, and it works well.

As I said, I'm running on Triton, and I use native SmartOS zones.
You can preach to me all you like about Docker and K8s and call me
any names you want, but this is *my stuff*, and I *like* running
Unix hosts, so I'm not listening.

SmartOS uses [pkgsrc](https://www.netbsd.org/docs/pkgsrc/), a very
simple tarfile-plus-metadata packaging system that comes from
NetBSD. It's very easy to build the packages (no need for
[fpm](https://github.com/jordansissel/fpm)),
and the update/install phase on the host is sufficiently lightweight
that I've no qualms running it frequently. There's just one problem.

## No One Offers pkgsrc Hosting

If you run an apt- or rpm-based bedroom-hobbyist type OS, there are
various third parties who will host your packages for very
reasonable prices. You stick a token in your CI config, and at the
end of the build phase, an API call pushes your freshly built
package to the repo, where it's stored, indexed, and subsequently
served. It couldn't be simpler.

In common with much SmartOS tech, pkgsrc is lean, well-engineered,
straightforward, and somewhat obscure.  Obscure to the point that,
so far as I can tell, none of the package-repo hosting platforms
support it. So no "chuck it at an endpoint" quick-fix for me.

A pkgsrc repo though, is a simple thing. Any old HTTP server will
do, so long as the directory holding the packages also contains an
index file called `pkg_summary.gz`.  To generate this you run
`pkg_info -X` on each package, concatenating and compressing the
results.

Successfully hosting packages isn't a problem of generating indices.
It's a problem of availability, which Manta has solved.
I only need to make that index, and the Manta model couldn't be a
more obvious fit.  Clearly, `pkg_info -X` is my map phase, and
`cat`ting them altogether and compressing is my reduce. Simple,
right?

Looking back, yes it was simple, but the path was, I think, just
about tricky enough that it's worth writing up.

## Manta is Object Storage

As I said, I already had a few packages in a publicly accessible
directory. They were mostly builds of open source software, so there
was no reason to put them somewhere private and have to pass tokens
around to make them accessible. Let's have a look, using the Manta
CLI tools. These are written in Node, and you get them with `npm
install -g manta`.

```cmd
$ mls ~~/public/pkgsrc
caddy-0.10.14.tgz
filebeat-7.0.0-alpha1.tgz
snltd-ruby-2.5.1.tgz
telegraf-1.7.0.tgz
wavefront-proxy-4.26-1.tgz
```

Manta commands start with an "m", and generally echo the names of
similar Unix commands, or the HTTP methods they wrap. So you put
objects into the store with `mput`, and download them with `mget`,
you get checksums with `mmd5`, and you make directories with
`mmkdir` (Unlike S3, Manta has a proper hierarchical filesystem.)

`~~` is shorthand for the root of your storage. Under
there everyone has `public/`, which the world can see, and `stor/`,
which requires credentials. (There are other things too, but they
aren't relevant to this story.)

The first thing I needed to know is, can I run `pkg_info` as a Manta
job? Joyent tell you that the environment which comes up around your
file is very much like a real SmartOS instance, but really?  Even
packaging tools?  I thought it seemed a bit much to hope for.

## Manta is a Proper Computer

It's easy to explore that environment though. The `mlogin` command
drops you into an interactive Manta job. Here I specify the object
you wish to work on, but running `mlogin` on its own simply gives
you a shell on a box somewhere, which is kind of cool.

```cmd
$ mlogin ~~/public/pkgsrc/telegraf-1.7.0.tgz
 * created interactive job -- c70b38e0-f572-4c6f-cecb-b858060294e1
 * waiting for session... | established
```

I now have a shell in my object storage! Your move, S3! But where am
I? What can I do? Where's the thing I asked to look at?

```cmd
snltd@manta # prtconf
System Configuration:  Joyent  i86pc
Memory size: 1024 Megabytes
...
snltd@manta # ls
assets  checkpoints  etc   lib    media  proc  sbin    tmp  var
bin     dev          home  manta  opt    root  system  usr
snltd@manta # find manta
manta
manta/snltd
manta/snltd/public
manta/snltd/public/pkgsrc
manta/snltd/public/pkgsrc/telegraf-1.7.0.tgz
```

Remember I said you could run anything against your object?  That
`assets/` directory is ready to receive any program you wish to send
it, as part of the job. So any binary from your SmartOS system will
drop in there and run. (Assuming it doesn't need any off-piste shared
libraries... Go, er, Go.) But what if that program were written in
a higher-level language? Could we even do that? Let's push Manta to
the absolute limit with some full-stack-10x-rockstar-ninja polyglot
programming.

```cmd
snltd@manta # ruby -e 'puts RUBY_VERSION'
1.9.3
snltd@manta # python -c 'import sys; \
               print '.'.join([str(x) for x in sys.version_info[0:3]])'
2.7.3
snltd@manta # node -e 'console.log(process.version.substring(1));'
0.10.28
snltd@manta # php -r 'print phpversion() . "\n";'
5.4.20
snltd@manta # echo '(println (clojure.string/join "." \
               (take 3(vals *clojure-version*))))' | clj -
1.5.1
snltd@manta # echo 'puts $tcl_version' | tclsh
8.5
snltd@manta # erl -eval 'erlang:display(erlang:system_info(otp_release)), \
               halt().' -noshell
"R16B"
```

I'll be honest, I had to look that last one up, and though `gchi`
runs, I couldn't tackle Haskell at all. Clearly I'm not the ninja I
thought I was. Some of those versions could do with a bump (though
there are newer alternatives hiding under names like `ruby200` and
`python3.3`), but it's clear that pretty much anything you write is
going to work in Manta without a lot of effort. (And if you are
writing batch-processing software in PHP, an odd part of me salutes
you.)

We're getting off track though. I only need to run `pkg_info`, and I
think I said I didn't expect it to be there.

```cmd
snltd@manta # pkg_info -X manta/snltd/public/pkgsrc/telegraf-1.7.0.tgz
PKGNAME=telegraf-1.7.0
COMMENT=Agent for collecting and reporting metrics and data
MACHINE_ARCH=x86_64
OPSYS=SunOS
OS_VERSION=5.11
PKGTOOLS_VERSION=20091115
FILE_NAME=telegraf-1.7.0.tgz
FILE_SIZE=7549471
DESCRIPTION=Modified version of Telegraf built to understand Solaris/SmartOS systems
```

Shows you what I know. It is, and it works. So, as promised, I have
a full Unix installation, and access to just that one object that I
asked for. There are even special environment variables that let us
refer to said object. (Shortened here, to fit the page.)

```cmd
snltd@manta # env | grep MANTA
MANTA_JOB_ID=c70b38e0-f572-4c6f-cecb-b858060294e1
MANTA_USER=snltd
MANTA_OUTPUT_BASE=/snltd/jobs/.../stor/snltd/public/pkgsrc/telegraf-1.7.0.tgz.0.
MANTA_NO_AUTH=true
MANTA_URL=http://localhost:80/
MANTA_INPUT_FILE=/manta/snltd/public/pkgsrc/telegraf-1.7.0.tgz
MANTA_INPUT_OBJECT=/snltd/public/pkgsrc/telegraf-1.7.0.tgz
snltd@manta # exit


 * remote process exited
 * cleaning up resources...
 * session complete
```

## Manta is "Serverless"

Knowing Manta would give me everything I needed with no extra
effort, I set about creating a "job". The canonical first step when
learning Manta is to count the words in a file. These are binaries,
so that doesn't make a lot of sense, but I could at least run `wc -c`
against them, just to make sure everything was set up correctly.

```cmd
$ echo ~~/public/pkgsrc/telegraf-1.7.0.tgz | mjob create -o -m 'wc -c'
added 1 input to c9326b26-afa2-6269-8c01-ca55c3a73a6b
7549471
```

Clearly we're on the right lines. To explain, `-o` tells `mjob` I
want to see the output, and `-m 'wc -c'` tells it that `wc -c` is
the map operation. The next step, I thought, was obvious.

```cmd
$ echo ~~/public/pkgsrc/telegraf-1.7.0.tgz | mjob create -o -m 'pkg_info -X'
added 1 input to 189b3ce6-51ec-43c6-8fee-bbb41ecbe03e
mjob create: error: job 189b3ce6-51ec-43c6-8fee-bbb41ecbe03e had 1 error
```

What? Why?

## Manta is (briefly) Puzzling

Where Amazon's docs are way, way too long, Joyent's can be too
short. [The Manta documentation](https://apidocs.joyent.com/manta/)
is thorough, but terse. And, as ever when working in the
Joyent/SmartOS world, there aren't many other sources of
information. Yes, Joyent support is good, and the mailing
lists are extremely helpful, but I'm *English*, and I don't like to
go round *bothering people*.

This can be an advantage though, because the only way to truly
understand anything is to beat it single-handedly. I am pig-headed,
and I am happy to sit up all night trying things in a semi-random
fashion, or wading through source code.  There's a part of me that
even *likes* it when things don't work and I know I have to unravel
it myself. I wanted to quietly work out what was going on, Miss
Marple style.

There was an error, but what was it? The output above doesn't give
much of a clue. But, Manta remembers its errors, and keeps them in
Manta! Very meta. (In the following output I've shortened the object
path for formatting reasons.)

```cmd
$ mjob errors 189b3ce6-51ec-43c6-8fee-bbb41ecbe03e | json
{
  "phase": "0",
  "what": "phase 0: input \"/snltd/public/pkgsrc/telegraf-1.7.0.tgz\"",
  "code": "UserTaskError",
  "message": "user command exited with code 1",
  "stderr": "/snltd/jobs/189b.../stor/snltd/public/pkgsrc/telegraf-1.7.0.tgz.0.err.948c90...",
  "input": "/snltd/public/pkgsrc/telegraf-1.7.0.tgz",
  "p0input": "/snltd/public/pkgsrc/telegraf-1.7.0.tgz"
}
```

Progress. Though I still didn't know what the error *was*, I knew
*where* it was: in the Manta object defined in the `stderr` field.

```cmd
$ mget $(mjob errors 189b3ce6-51ec-43c6-8fee-bbb41ecbe03e | json stderr)
pkg_info: missing package name(s)
usage: pkg_info [-BbcDdFfhIikLmNnpqRrSsVvX] [-E pkg-name] [-e pkg-name]
                [-K pkg_dbdir] [-l prefix] pkg-name ...
       pkg_info [-a | -u] [flags]
       pkg_info [-Q variable] pkg-name ...
```

What? That's the `pkg_info` usage information, which is what you get when
you run the command incorrectly!

It took me a while to twig this. I tried other commands, hoping to
spot a pattern. `wc` and `strings` worked, but `stat` and `ls`
didn't. Eventually the penny dropped: the map job *reads stdin*.
Indeed, [the
documentation](https://apidocs.joyent.com/manta/jobs-reference.html#jobs-overview)
says

> Each map task has read-only access to a local file
> representing the contents of that input object, and stdin is
> redirected from that object.

I think the wording of this is a little unclear, and I didn't quite
"get" it when I first read it, but a little experimentation made it
clear.

This explains why I got the usage message. The failed command wasn't
`pkg_info -X telegraf-1.7.0.tgz` it was more like `cat
telegraf-1.7.0.tgz | pkg_info -X`.

I tried messing about with `xargs`, and with a little wrapper
script, but it all felt wrong. I kept coming back to what I said
earlier: *this task is a perfect fit for Manta*. If I'm trying to
trick it, I'm Doing it Wrong™.

Eventually I thought of those env vars, and tried this.

```cmd
$ echo ~~/public/pkgsrc/telegraf-1.7.0.tgz | \
  mjob create -o -m 'pkg_info -X $MANTA_INPUT_FILE'
added 1 input to 63f7edd2-379e-60f7-cdc1-8e85186dd49a
PKGNAME=telegraf-1.7.0
COMMENT=Agent for collecting and reporting metrics and data
MACHINE_ARCH=x86_64
OPSYS=SunOS
OS_VERSION=5.11
PKGTOOLS_VERSION=20091115
FILE_NAME=telegraf-1.7.0.tgz
FILE_SIZE=7549471
DESCRIPTION=Modified version of Telegraf built to understand Solaris/SmartOS systems
```

Yes! And making it work on all the files in the directory is not
unlike using `find` on a Unix box. (Though `mfind` rejects proper
`find`'s rogue syntax, opting for something more Unix-ey.)

```cmd
$ mfind -t o -n '\.tgz$' /snltd/public/pkgsrc | \
  mjob create -o -m 'pkg_info -X $MANTA_INPUT_FILE'
added 5 inputs to 2a952d63-5e3b-65ba-8609-d1f07227727b
PKGNAME=snltd-ruby-2.5.1
COMMENT=vanilla Ruby 2.5.1
MACHINE_ARCH=x86_64
OPSYS=SunOS
...
```

## Manta is Map-Reduce

I'll spare you the rest of the output, but I promise all five
packages were described. Now I just needed to do the reduce phase:
concatenate and compress.  This time I didn't use `-o` because I
didn't want a load of binary data streamed to my console. (Though
consoles handle that far better than they used to.)

```cmd
$ mfind -t o -n '\.tgz$' /snltd/public/pkgsrc | \
  mjob create -w -m 'pkg_info -X $MANTA_INPUT_FILE' -r 'cat | gzip'
32dee2d2-a658-cdec-b7cf-c260983071a0
added 5 inputs to 32dee2d2-a658-cdec-b7cf-c260983071a0
$
```

If I didn't ask for the output on the console, where the heck did it
go? We saw above that stderr is stored in Manta, and so, when you
don't request it, is stdout. Instead of asking for `errors`, we ask
for `outputs`.

```cmd
$ mjob outputs 32dee2d2-a658-cdec-b7cf-c260983071a0
/snltd/jobs/32dee2d2-a658-cdec-b7cf-c260983071a0/stor/reduce.1.d336aa76-9a04-4ac9-9f09-0c7c8f9ee50d
```

And get them.

```cmd
$ mget -o pkg_summary.gz $(mjob outputs 32dee2d2-a658-cdec-b7cf-c260983071a0)
...9f09-0c7c8f9ee50d [=======================>] 100%     622B
$ gzip -dc pkg_summary.gz | head -3
PKGNAME=telegraf-1.7.0
COMMENT=Agent for collecting and reporting metrics and data
MACHINE_ARCH=x86_64
```

This is great. Nearly there. Clearly that file is being stored in/by
Manta already, so I only needed to tell it to store it in the right
place, with the right name. For this, there's a Manta internal
command, `mpipe`.  Back to that `mlogin` session:

```cmd
snltd@manta # mpipe --help
usage: mpipe [-f file] [-p] [-r reducer] [-H header:value ... ]
             [objectkey]

mpipe is a distributed pipe for compute jobs.  This command reads data
from stdin and saves it as a new object called "objectkey".
```

Though I'd say it's more of a `>` than a `|`, `mpipe` is exactly
what I needed.

```cmd
$ mfind -t o -n '\.tgz$' /snltd/public/pkgsrc | \
  mjob create -w -m 'pkg_info -X $MANTA_INPUT_FILE' \
                               -r 'cat | gzip | mpipe ~~/public/pkgsrc/pkg_summary.gz'
b12106ff-4f9f-6d56-ca6a-f0584cae172f
added 5 inputs to b12106ff-4f9f-6d56-ca6a-f0584cae172f
$ mls -l ~~/public/pkgsrc
-rwxr-xr-x 1 snltd       7096212 May 03 00:34 caddy-0.10.14.tgz
-rwxr-xr-x 1 snltd       8959049 May 03 00:47 filebeat-7.0.0-alpha1.tgz
-rwxr-xr-x 1 snltd           621 Jun 02 00:02 pkg_summary.gz
-rwxr-xr-x 1 snltd      19184926 May 01 12:48 snltd-ruby-2.5.1.tgz
-rwxr-xr-x 1 snltd       7549471 May 03 18:15 telegraf-1.7.0.tgz
-rwxr-xr-x 1 snltd      27680628 May 01 12:47 wavefront-proxy-4.26-1.tgz
```

## Manta is a Package Repository

Now that is neat. Time to see if it actually worked. (I've cheated
here, and temporarily disabled checking GPG singatures -- my
packages weren't being signed at this point.)

```cmd
# echo "https://us-east.manta.joyent.com/snltd/public/pkgsrc" \
  >>/opt/local/etc/pkgin/repositories.conf
# pkgin -fy up
processing remote summary (https://pkgsrc.joyent.com/packages/SmartOS/2018Q1/x86_64/All)...
cleaning database from https://pkgsrc.joyent.com/packages/SmartOS/2018Q1/x86_64/All entries...
pkg_summary.xz                      100% 2126KB 708.6KB/s 653.7KB/s   00:03
processing remote summary (https://us-east.manta.joyent.com/snltd/public/pkgsrc)...
cleaning database from https://us-east.manta.joyent.com/snltd/public/pkgsrc entries...
pkg_summary.gz                      100%  618     0.6KB/s   0.6KB/s   00:00
# yes | pkgin in snltd-ruby
calculating dependencies... done.
...
installing packages...
installing snltd-ruby-2.5.1...
...
$ pkgin pkg-descr snltd-ruby
pkg_info: can't find package
`https://pkgsrc.joyent.com/packages/SmartOS/2018Q1/x86_64/All/snltd-ruby-2.5.1.tgz', skipped
Information for https://us-east.manta.joyent.com/snltd/public/pkgsrc/snltd-ruby-2.5.1.tgz:
Description:
Ruby 2.5.1 with no dependencies. Includes gems:
puppet ruby-shadow wavefront-cli sinatra kramdown rouge puma slim
$ ruby -v
ruby 2.5.1p57 (2018-03-29 revision 63029) [x86_64-solaris2.11]
```

So there we are: a fully functioning, highly available pkgsrc server
in one line of code. Pats on the back all round.

The astute reader will notice, though, that this is only a start.

The most obvious puzzle is how the job should be invoked. Ideally
we would want it to happen automatically, whenever a package is
uploaded, but Manta lacks an equivalent of Lambda's triggers.

We may also wish to start distributing private packages in this way,
so we'd need to stop using the `~~/public` path, which means
distributing credentials. We'd probably also like to GPG sign those
packages.

I'll look at these (and more! -- there are always more) problems
next time, and explain how I went about integrating my new pkgsrc
repo into my CI-CD pipelines.



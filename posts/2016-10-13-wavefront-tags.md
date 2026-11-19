---
title: "Managing Wavefront Source Tags from the CLI"
tags: [Wavefront, Ruby]
date: 2016-10-13
category: Wavefront
---

Once again I've been back into [the Wavefront
CLI](https://github.com/wavefrontHQ/ruby-client/blob/master/README-cli.md)
and Ruby SDK, adding more functionality. This time, the work was driven
by a wish to have our EC2 instances tag themselves with things like
account, instance type, the repository from which they take their
configuration management code, or maybe the version of that code.

The Ruby SDK didn't give you any help in doing this, so the first job
was to extend [the class offering wrappers around the appropriate API
calls](https://github.com/wavefrontHQ/ruby-client/blob/master/lib/wavefront/metadata.rb).

Once that was done (including
[tests](https://github.com/wavefrontHQ/ruby-client/blob/master/spec/wavefront/metadata_spec.rb)
of course!), I added a new `source` command to the CLI. As we use
[docopt](http://docopt.org/) to parse input, the hardest part of the job
was coming up with a sensible interface. After a lot of thought and a
couple of rewrites, I ended up with this.

```cmd
$ wavefront source --help
Usage:
  wavefront source list [-f format] [-at] [-T tag ...] [-s source] [-l limit] <pattern>
  wavefront source show [-f format] <host> ...
  wavefront source describe <description> [<host>] ...
  wavefront source undescribe [<host>] ...
  wavefront source tag add [-H host ... ] <tag> ...
  wavefront source tag delete [-H host ... ] <tag> ...
  wavefront source untag [<host>] ...

Options:
  -a, --all            including hidden sources in 'human' output
  -t, --tags           show tag counts in 'human' output
  -s, --start=STRING   start the list after the named source
  -l, --limit=NUMBER   only list NUMBER sources
  -H, --host=STRING    source to manipulate
  -f, --format=STRING  output format (ruby, json, human)
                       [default: human]
```

For the sake of clarity I've removed the global options from the output.
These let you define your Wavefront endpoint, authentication token and
so-on. (The beauty of docopt is that you only have to write the help
message shown above as a block of text in your code, and it all those
options and subcommands get magically populated.)

The general principle of the `source` command is to have the things you
are setting (tags and descriptions) be arguments, and the things you are
setting them on (hosts, or, technically, "sources"), options. This way
you can set multiple tags on multiple hosts with a single command.

If, when manipulating a tag or description, you don't specify a source
(or sources), then the CLI will assume you wish to refer the machine on
which it is running. That way automated "tagging myself" jobs don't need
to keep shelling out to `uname(1)` or whatever.

Let's do a few examples.

In my home lab I have a Solaris server called `shark`. It has a number
of zones on it, whose names all begin `shark-`. Let's list everything
with `shark` in the name.

```cmd
$ wavefront source list shark
HOSTNAME                  DESCRIPTION                    TAGS
shark
shark-media
shark-wavefront
shark-ws
```

The argument `shark`, is a pattern, which is passed straight through
to Wavefront. It seems that there it is matched as a general
regex, because without having to put `.*` or similar on the end of
it, I've got all the `shark` zones for free. It's not clear from
that what's what, so let's quickly describe them

```cmd
$ wavefront source describe -H shark 'general-purpose server'
setting 'shark' description to 'general-purpose server'
$ wavefront source describe -H shark-media 'minidlna server'
setting 'shark-media' description to 'minidlna server'
$ wavefront source describe -H shark-wavefront 'wavefront proxy'
setting 'shark-wavefront' description to 'wavefront proxy'
$ wavefront source list shark
HOSTNAME                  DESCRIPTION                    TAGS
shark                     general-purpose server
shark-media               minidlna server
shark-wavefront           wavefront proxy
shark-ws
```

That's fine, but descriptions aren't particularly useful. As far as
I know you can't do anything with them in the timeseries language.
Let's do some tags.

```cmd
$ wavefront source tag add -H shark physical solaris
Tagging 'shark' with 'physical'
Tagging 'shark' with 'solaris'
$ wavefront source tag add -H shark-media -H shark-wavefront -H
shark-ws zone
Tagging 'shark-media' with 'zone'
Tagging 'shark-wavefront' with 'zone'
Tagging 'shark-ws' with 'zone'
$ wavefront source list shark
HOSTNAME                  DESCRIPTION                    TAGS
shark                     general-purpose server         physical
shark-media               minidlna server                zone
shark-wavefront           wavefront proxy                zone
shark-ws                                                 zone
```

Now, we can filter our `ts()` queries. Putting `tag=physical` to any
`ts()` statement (as the second argument, just before closing the
brackets) will only show data for the physical host. Zones will be
ignored. Sources can have as many tags as you want, so you can
create all manner of ways to cross-reference.

We incorporate our host's product, environment, and role into our
metric paths, but you might feel tagging is a better way to do that.
Also tag by AZ, instance-type and it's trivial to pull out JVM stats
just for t2-medium Cassandra boxes in the eu-west-1 production
environment.

You can take tags away just as you added them, by swapping `add` for
`delete`, or remove all a source's tags in one go with `untag`.
Similarly, there's an `undescribe` command, which doesn't
*technically* remove a description (the API doesn't provide a method
for that) but does set it to an empty string.

To see everything Wavefront knows about a particular source, ask the
CLI to `show` it to you.

```cmd
$ wavefront source show shark
shark
  description    general-purpose server
  tags           physical
```

Revisiting the `list` command, you are likely to have a lot of
sources. (We have over 150,000.) So, if you're `list`ing, you likely
want to be careful with your pattern, or paginate. To help you do
this, the `list` command provides `--limit`, to limit the number of
sources it returns, and `--start`. The latter takes requires a
source name, and when it is used, the command will return sources
starting with the one *after* that which you supplied.

Requesting a source list in `raw` or `json` format will include
hidden sources, but `human` format will not, unless you supply the
`-a` option. The same goes for the tag count summary included in
`list` output: to turn that on in human-readable mode, add `-t`.

```cmd
$ wavefront source list -at shark
HOSTNAME                  DESCRIPTION                    TAGS
shark                     general-purpose server         physical
shark-media               minidlna server                zone
shark-wavefront           wavefront proxy                zone
shark-ws                                                 zone
shark-wslab                                              hidden

TAG                      COUNT
hidden                   339
physical                 1
zone                     3
```

It's also possible to have the human-readable output only display
sources which have a particular tag, or tags. To do this, use `-T`.

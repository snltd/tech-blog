---
title: "Sending Wavefront Data from the CLI"
tags: [Wavefront, Ruby, DTrace]
date: "2018-08-08"
layout: post
category: Wavefront
---

> Note: This article was originally published in July 2016. It has
> been updated to cover the new `report` feature, and the 2.x
> syntax. I have also written [a complete guide to the Wavefront
> CLI](/post/2017-07-26-wavefront-cli).

Most Wavefront users have agents, like Telegraf or Collectd running
on their hosts or alongside their containers, streaming metrics in
via proxies.

Sometimes though it's useful to be able to send metrics in a more
ad-hoc way, and my [Wavefront
CLI](https://github.com/snltd/wavefront-cli) can fill that gap.

The CLI has always had the `write` sub-command, which writes
points to a proxy.  But now Wavefront can receive metrics via its
API, bypassing the proxies altogether. The CLI has grown a `report`
subcommand which uses this new feature.

Let's have a look at data ingestion from the command-line. All the
examples use version 2.4.0 of the `wavefront-cli` gem, and talk to a
`2018-10` Wavefront cluster  or later. Any `report` operations
require a token which holds the "direct data ingestion" privilege.

## Single, Arbitrary Points

Sometimes -- trust me -- you want to poke just the odd point into
Wavefront. The `write point` and `report point` sub-commands do just
that. Here's their syntax.

```
wf write point [-DnVq] [-c file] [-P profile] [-E proxy] [-p port]
               [-t time] [-H host] [-T tag...] <metric> <value>

wf report point [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
               [-s time] [-H host] [-T tag...] <metric> <value>
```

Pretty simple, right? The first form, `wf write` uses a proxy,
specified by the `-E` option. The second, `wf report` is new, and
specifies an *endpoint* with `-E`. This is because it writes directly
to the API: no proxy required.


```cmd
$ date
Mon Apr 09 15:55:38 BST 2018
$ wf write point dev.cli.example 1
          sent 1
      rejected 0
        unsent 0
$ wf report point dev.cli.example 1
Point received.
$ wf query --granularity=s --start=15:55 'ts("dev.cli.example")'
name         ts("dev.cli.example")
query        ts("dev.cli.example")
timeseries
  label      dev.cli.example
  host       box
  data       2018-04-09   15:56:19    20.0
             ---------------------------------------------------------------
  label      dev.cli.example
  host       box
  tags
    env      lab
  data       2018-04-09   15:55:58    10.0
```

Note that the query results are in two sections, even though we sent
two values on the same metric path. The directly ingested point
(value `20`) has no tags, but the one we sent via the proxy is
tagged with `env=lab`. This is because my lab proxy has a
preprocessor rule which tags everything going through it, and it
shows that sending points directly, though useful in many cases, is
not a straight substitute for using a proxy.

Most obviously, API calls are far more expensive. Sending a metric
via `report` takes about a second for me, because that metric's got
to get from England to `us-west-1`, over HTTPS. Sending to a proxy
listening on a Unix socket on the same subnet is pretty much
instantaneous.

And the Wavefront proxy is not a thing you want to avoid. Even a
modestly sized one can handle insane amounts of metrics, and it
gives you great reliability through its buffering and retrying, and
efficiency through batching and compressing of the data it sends. It
lets you manipulate, mangle, or block points based on sophisticated
rules. It can extract metrics from log files, tag things on the fly,
understand all kinds of different formats. And it generates rich
metrics of everything it does, which can be very useful when things
don't go as they should.

That's not to say direct ingestion is without value. For instance,
we made an IoT biscuit tin, and we wanted its metrics to go to
Wavefront. That turned out to be a huge pain, because all our
proxies, and indeed, all our *hosts* were in AWS, and our biscuit
tin was in the office. Direct ingestion would have been perfect for
a little job like that. We've also, at times, wanted to
put a small amount of data from Lambda functions into Wavefront, but
the Lambdas were running in VPCs without proxy access. We
could peer, or stand up proxies, but direct ingestion would have
been easier all round.

In both the `write` and `report` commands, we didn't specify a
timestamp for the point, so the CLI assumed "now". There is a way to
tiemstamp a point manually, but it's the one difference between
`write` and `report`.

When I wrote the original `write` command, direct ingestion did not
exist and, since writing via a proxy didn't require a token, I used
`-t` for the timestamp of a point. "Why on earth not?", I thought.
It seemed like good common sense.  Then `report` came along, and it
uses the API, so it needs a token, and every other command uses `-t`
for that. Gah!

Rather than break the existing `write` options, I chose to use `-s`
for the timestamp on the report command, as it's the other half of
`ts`, which is the internal variable for a timestamp. I'm sorry if
that annoys you: at least know that annoys me too.

When you set a timestamp, as in all `wf` subcommands, you can use
epoch seconds or, anything naturally parseable by Ruby's
`strptime()` method.

```cmd
$ wf write point -t 14:20:33 dev.cli.example 98.76
          sent 1
      rejected 0
        unsent 0
```

The "points sent" summary might get on your nerves after a while,
but it can be silenced with `-q`. If anything goes wrong, even with
`-q` specified, `wf` will exit nonzero and print the summary anyway.

You can write points with tags, using `-T`. Multiples are allowed.

```cmd
$ wf write point -q -t 14:25 -T cmd=wf -T subcmd=write dev.cli.example 99.999
```

If I don't specify a source (or "host"), the CLI will use what it
thinks is the hostname of my machine. Up to now that's been `box`.

```cmd
$ wf write point -q -H made-up-host dev.cli.example 99
```

Tags and source names work exactly the same whether you are
`write`-ing or `report`-ing.

Here are the points we just sent. Hover over them and you'll see the
tags.  (If you can't see the chart, you'll have to enable
third-party cookies for this page, because the embedded graphs use
Typekit.)

<script src="https://metrics.wavefront.com/embedded/tGKr1whgQV/js"
id="wavefront-embedded-tGKr1whgQV" width="700"
height="300"></script>

I did not specify a proxy endpoint or port in any of the above
examples. The `write` command respects the `.wavefront` config file,
so I have my proxy stowed away in there:

```cmd
$ grep -v token ~/.wavefront
[default]
endpoint = metrics.wavefront.com
format = human
proxy = wavefront.localnet
```

`report` uses the proxy and token just like any other `wf` command.

## Multiple Points, From a File

Writing one point at a time is fine, and may well be just what you
need, but it's more likely that you want to push in a batch of
points.

A while ago, I needed to push retrospective data into Wavefront. At
the time I had to hack together some Ruby to do it, but now I could
use the CLI.

Here's an example file.

```cmd
$ cat file1
1469008889 dev.cli.file1 10511
1469008890 dev.cli.file1 26042
1469008892 dev.cli.file1 20384
1469008893 dev.cli.file1 20326
1469008894 dev.cli.file1 21355
1469008895 dev.cli.file1 20997
```

It should be obvious that the three fields are epoch timestamp,
metric path, and value. I can load in that file with the following
'write file' command. Supplying `-V` will show me the points in
Wavefront wire format, as they go in.

```cmd
$ wf write file -V -F tmv file1
Connecting to wavefront:2878.
Sending: dev.cli.file1 9105.0 1470327894 source=box
Sending: dev.cli.file1 12298.0 1470327895 source=box
Sending: dev.cli.file1 30598.0 1470327896 source=box
Sending: dev.cli.file1 31797.0 1470327897 source=box
Sending: dev.cli.file1 22708.0 1470327898 source=box
Sending: dev.cli.file1 766.0 1470327899 source=box
Sending: dev.cli.file1 25143.0 1470327900 source=box
Sending: dev.cli.file1 2993.0 1470327901 source=box
Sending: dev.cli.file1 29433.0 1470327902 source=box
Sending: dev.cli.file1 12263.0 1470327903 source=box
Closing connection to proxy.
Point summary: 10 sent, 0 unsent, 0 rejected.
```

And here's the chart.  Hover over the points and you'll see the
values from the file.


<script src="https://metrics.wavefront.com/embedded/dTjFQkX3XB/js"
id="wavefront-embedded-dTjFQkX3XB" width="700"
height="200"></script>

The key part of the `wf write file` command is the `-F` option. This
lets the user describe the format of the file they wish `wf`
to parse. `t` stands for `timestamp`; `m` for `metric`, and `v` for
`value`. So, `tmv`, describes the format of `file1`.

The `v` column is mandatory, but the time and metric path can be set
in other ways. For instance, the `-m` option allows you to define
a metric path which will be applied to all data points in the file.
So, the following file and command would be an identical data load
to the example above.

```cmd
$ cat file1
1471025043 144
1471025167 185
1471025253 157
1471025350 129
1471025384 48
1471025540 67
1471025549 172
$ wf write file -F tv -m dev.cli.file1 file1
```

You can also use `-m` to set a metric prefix, and have the final
portion of the metric in your file. If you do that, the two parts
will be concatenated. I'll show you that later.

If you wish, you can even add point tags to a data load. For
fine-grained control, put them at the end of each line to which they
apply. To tag everything uniformly, use the `-T key=val` option. If
you do both, you get both sets of tags. Tags have to be at the end
of the line because there can be arbitrarily many for each data
point, and the number may not be constant.

Oh, and all this works identically for `wf report`.

## Multiple Points, from a Live Source

Though it's more useful than sending a single point, I still think
loading data in from a static file is something most people would
use rarely, if ever.  Far more useful to, in proper Unix style, set
the input file to `-`, and read from standard in.

Maybe the simplest illustration is to generate some (pseudo) random
data. (Disregarding the fact that  Wavefront has a perfectly capable
`random()` function.)

```cmd
$ while true; do echo $RANDOM; sleep 1; done | wf write file -V -m dev.cli.demo -Fv -
Connecting to wavefront.localnet:2878.
Sending: dev.cli.demo 18718.0 source=box
Sending: dev.cli.demo 13481.0 source=box
Sending: dev.cli.demo 18154.0 source=box
Sending: dev.cli.demo 7834.0 source=box
Sending: dev.cli.demo 19986.0 source=box
Sending: dev.cli.demo 7418.0 source=box
Sending: dev.cli.demo 20295.0 source=box
Sending: dev.cli.demo 20602.0 source=box
...
```

Producing:

<script src="https://metrics.wavefront.com/embedded/XW3CfP7jYc/js"
id="wavefront-embedded-XW3CfP7jYc" width="700" height="300"></script>

That's fine, but you're more likely to want to plot the output of a
command, so to illustrate that, here's a little script which
generates the points for a parabola.  You can see it outputs pairs
of numbers: the first is the abcissa, as a timestamp, and the second
is the ordinate.

```ruby
#!/usr/bin/env ruby

h, k, a = 25, 1000, 10

1.upto(49) do |x|
  $stdout.puts "#{Time.now.to_i} #{a * (x - h) ** 2 + k}"
  $stdout.flush
  sleep 1
end
```

The `$stdout` stuff is necessary because otherwise the script will
flush all its output when it exits, and I wanted to use
`wf`'s `-V` option to watch the points flowing through when I
was testing. (`wf` has a `--noop` flag which will not make a
connection to the proxy, and will show you the points in Wavefront
wire format, in real-time.)

Anyway, run the script, and pipe its output into `wf`,
supplying a metric path and a description of the file format.

```cmd
$ ./parabola.rb | wf write file -m dev.cli.demo -F tv -
```

<script src="https://metrics.wavefront.com/embedded/KN09RPxH6J/js"
id="wavefront-embedded-KN09RPxH6J" width="700"
height="200"></script>

[Back in a previous article, I wrote some Ruby to wire DTrace into
Wavefront](http://sysdef.xyz/post/2016-06-26-dtrace-wavefront). Now,
I can use the `write file` command for simple D scripts.

Revisiting `intr.d`, I can describe the field format I expect, and
`wf` will ignore lines which don't match. The first field is
the CPU ID, which I want as the final part of the metric path, and
the second is the value to send (in this case, the total number of
interrupts handled by that CPU). Because I am not supplying any
timestamps, `wf` will use the current UTC time whenever it
sends a point. `-V` is for verbosity.

```cmd
# ./intr.d | wf write file -V -m dev.cli.d1 -F mv -
Connecting to proxy at wavefront:2878.
dtrace: script '/expor/home/rob/intr.d' matched 2 probes
WARNING: wrong number of fields. Skipping.
WARNING: wrong number of fields. Skipping.
Sending: dev.cli.d1.1 265 1469136415 source=shark
Sending: dev.cli.d1.3 268 1469136415 source=shark
Sending: dev.cli.d1.2 331 1469136415 source=shark
Sending: dev.cli.d1.0 647 1469136415 source=shark
WARNING: wrong number of fields. Skipping.
WARNING: wrong number of fields. Skipping.
Sending: dev.cli.d1.3 517 1469136416 source=shark
Sending: dev.cli.d1.1 550 1469136416 source=shark
Sending: dev.cli.d1.2 887 1469136416 source=shark
...
```

and, with the whole thing wrapped in a `deriv()` to turn a counter
into a gauge, I see:

<script src="https://metrics.wavefront.com/embedded/yBX4SxWjT0/js"
id="wavefront-embedded-yBX4SxWjT0" width="700"
height="200"></script>

Or how about kstats? Say I'd like to see a chart of network
throughput when I do an NFS copy between a couple of machines.
That's now a one-liner. (Or it would be if I didn't have to break it
because of formatting issues!) Let's use direct ingestion, just to
show that it works the same.

```cmd
$ while true; do kstat link:0:net0:obytes64 | grep obytes; sleep 1; done | \
  wf report file -Fmv -m dev.cli.network -
```

<script src="https://metrics.wavefront.com/embedded/BBp5gt9gJk/js"
id="wavefront-embedded-BBp5gt9gJk" width="700" height="300"></script>

That required no setting up, and nothing beyond a local installation
of the `wavefront-cli` gem. Now you have no excuse for not putting
everything in Wavefront!

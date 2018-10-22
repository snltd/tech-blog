---
title: "Sending Wavefront Data from the CLI"
tags: [Wavefront, Ruby, DTrace]
date: "2018-04-08"
layout: post
category: Wavefront
---

> Note: This article was originally published in July 2016. It has
> been updated to cover the new `report` feature, delta metrics,
> histograms, and the 2.x syntax. I have also written [a complete
> guide to the Wavefront CLI](/post/2017-07-26-wavefront-cli).

Though Wavefront has a remarkable ability to relentlessly consume
huge amounts of metrics, from agents like Telgraf or CollectD, it is
sometimes useful to be able to send data in a more ad-hoc way.
My [Wavefront CLI](https://github.com/snltd/wavefront-cli) can
be useful for that.

This article looks at data ingestion from the command-line. All the
examples work with version 2.10.0 of the `wavefront-cli` gem, going
into a `2018-30-39` cluster, via a 4.29 proxy.

## Single, Arbitrary Points

Sometimes you want to poke just the odd point into Wavefront. The
`write point` and `report point` sub-commands do just that. Here's
their syntax.

```
wf write point [-DnViq] [-c file] [-P profile] [-E proxy] [-t time]
               [-p port] [-H host] [-T tag...] [-u method] <metric> <value>

wf report point [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
                [-s time] [-H host] [-T tag...] [-iq] <metric> <value>

```

Pretty simple, right? The first form, `wf write` uses a proxy,
specified by the `-E` option. The second, `wf report`, specifies an
*endpoint* with `-E`. This is because it writes directly to the API:
no proxy required.


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
instantaneous. (The proxy batches points and compresses the bundle
before sending to your cluster, so the actual delay may be longer,
though it will "feel" faster to your client.)

The Wavefront proxy is not a thing you want to avoid. Even a
modestly sized one can handle insane amounts of metrics, and it
gives you great reliability through its buffering and retrying, and
efficiency through batching and compressing of the data it sends. It
lets you manipulate, mangle, or block points based on sophisticated
rules. It can extract metrics from log files, tag things on the fly,
understand all kinds of different formats. And it generates rich
metrics of everything it does, which can be very useful for
debugging and tuning.

That's not to say direct ingestion is without value. For instance,
when we made an IoT biscuit tin, we wanted its metrics to go to
Wavefront. That turned out to be a huge pain, because all our
proxies, and indeed, all our *hosts* were in AWS, and our biscuit
tin was in the office. Direct ingestion -- which didn't exist at the
time -- would have been perfect for a little job like that. We've
also, at times, wanted to put a small amount of data from Lambda
functions into Wavefront, but the Lambdas were running in VPCs
without proxy access. We could peer, or stand up proxies, but direct
ingestion would have been easier all round. Now direct ingestion is
available, we're starting to use it all over the place.

In both the `write` and `report` commands, we didn't specify a
timestamp for the point, so the CLI assumed "now". There is a way to
tiemstamp a point manually, but it's the one difference between
`write` and `report`.

When I made the original `write` command, direct ingestion did not
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

If you find yourself wondering whether, or how, `wf` will parse a
time you enter, open up `irb` and find out.

```cmd
$ irb -r time
irb(main):003:0> Time.parse('12:00')
=> 2018-10-22 12:00:00 +0100
irb(main):004:0> Time.parse('13/03/2016')
=> 2016-03-13 00:00:00 +0000
```

Note that when you send points, you get a summary of how many were
sent, rejected, or unsent. Depending on your viewpoint, this is
useful and reassuring, or irritating, so you have the option to make
the `write` command quiet with `-q`. If anything goes wrong, even
with `-q` specified, `wf` will exit nonzero and print the summary
anyway.

If you are not irritated by summaries, and demand EVEN MORE
verbosity when writing points, you're in luck. `--verbose` (AKA
`-v`) will print make `wf` print out every point it sends in native
Wavefront wire format.

```cmd
$ wf write point -t 14:20:33 dev.cli.example 98.76 --verbose
SDK INFO: dev.cli.example 98.76 1540214433 source=box
          sent 1
      rejected 0
        unsent 0
$ wf report point -t 14:20:33 dev.cli.example 98.76 --verbose
SDK INFO: dev.cli.example 98.76 source=box
SDK INFO: uri: POST https://metrics.wavefront.com/report
SDK INFO: body: dev.cli.example 98.76 source=box
Point received.
```

There's `--debug` too, but that will take you into the innards of
`wf`.

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

Note that `write` now has a `-u`, or `--using` option. At the moment
there are two ways to write points via a proxy. Up until very
recently we have always sent points to a Unix socket on the proxy.
This is quick and efficient, but it's a one-way process. If the
proxy doesn't get the points, or they get mangled on the way in, it
can't ask the client to send them again.

The proxy now accepts HTTP POSTed points, on the same port the
socket uses. This is simple HTTP - there's no authentication or
authorization yet, but it works, and the CLI supports it.

```cmd
$ wf write point dev.cli.example 123 --verbose --using http
SDK INFO: dev.cli.example 123.0 source=box
SDK INFO: uri: POST http://wavefront:2878/
SDK INFO: body: dev.cli.example 123.0 source=box
          sent 1
      rejected 0
        uunsent 0
```

The other currently-supported `using` method is `api`. The `report`
command is simply a shim to `write` which forces `-u api`. Look.

```cmd
$ wf report point dev.cli.example 123 --verbose
SDK INFO: dev.cli.example 123.0 source=box
SDK INFO: uri: POST https://metrics.wavefront.com/report
SDK INFO: body: dev.cli.example 123.0 source=box
$ wf write point dev.cli.example 123 --verbose --using api
SDK INFO: dev.cli.example 123.0 source=box
SDK INFO: uri: POST https://metrics.wavefront.com/report
SDK INFO: body: dev.cli.example 123.0 source=box
```

As other transport mechanisms appear, I will add them to the CLI.

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
1540227210 dev.cli.file1 10511
1540227211 dev.cli.file1 26042
1540227212 dev.cli.file1 20384
1540227213 dev.cli.file1 20326
1540227214 dev.cli.file1 21355
1540227215 dev.cli.file1 20997
```

It should be obvious that the three fields are epoch timestamp,
metric path, and value. I can load in that file with the following
'write file' command. Supplying `-V` will show me the points in
Wavefront wire format, as they go in.

```cmd
./wf write file -V -F tmv file1
SDK INFO: dev.cli.file1 10511.0 1540227210 source=box
SDK INFO: dev.cli.file1 26042.0 1540227211 source=box
SDK INFO: dev.cli.file1 20384.0 1540227212 source=box
SDK INFO: dev.cli.file1 20326.0 1540227213 source=box
SDK INFO: dev.cli.file1 21355.0 1540227214 source=box
SDK INFO: dev.cli.file1 20997.0 1540227215 source=box
          sent 6
      rejected 0
        unsent 0
```

And here's the chart.  Hover over the points and you'll see the
values from the file.

<script src="https://metrics.wavefront.com/embedded/NjqLjql3fr/js"
id="wavefront-embedded-NjqLjql3fr" width="700" height="300"></script>

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
data. (Ignoring the fact that  Wavefront has a perfectly capable
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

## Histograms

Wavefront now has an add-on [histogram
feature](https://docs.wavefront.com/proxies_histograms.html).  For
this to work you need to have a histogram-enabled endpoint. Speak to
your sales person.

Histograms are a way around Wavefront's one-second resolution limit,
and a way of intepreting millions of points per second without it
costing the earth. They work like a global statsd. You send
points to a proxy, which buckets them all, and flushes a
mathematical description of said bucket up to your cluster at a
predefined interval. These intervals are every minute, hour, and
day.

You must configure your proxy to allow histogram ingestion, and each
of the intervals I mentioned has its own port. By default the
"minute" bucket listens on 40001, the hourly one on 40002, and the
daily on 40003. To send metrics with the CLI and have them bucketed
in one minute intervals is exactly as I described above, but pop `-p
40001` in the command. Watch.

```cmd
$ while true
> do
> wf write point -qV -p 40001 demo.cli.histogram_1 $RANDOM
> sleep 0.1
> done
SDK INFO: demo.cli.histogram_1 1028.0 source=box
SDK INFO: demo.cli.histogram_1 11952.0 source=box
SDK INFO: demo.cli.histogram_1 12442.0 source=box
SDK INFO: demo.cli.histogram_1 26243.0 source=box
SDK INFO: demo.cli.histogram_1 17687.0 source=box
...
```

produces:

<script src="https://virunga.wavefront.com/embedded/sMpSvBHXPD/js"
id="wavefront-embedded-sMpSvBHXPD" width="700"
height="300"></script>

Once the results are in Wavefront, you can view them with an `hs()`
(as opposed to `ts()`) expression, and apply various statistical
functions. The chart above uses, `max()`, `median()`, `min()`, and
uses `percentile()` to show the 95th percentile. As this is analysis is
performed on data from all hosts, it's a true 95th percentile, not an
average view of the 95th percentile from each host.

There is another way of writing histogram data to Wavefront, which
is to use a "distribution". A distribution assigns multiple values
to a single metric over a given time range. So, if you were
recording web server response codes, and had 150 "200"s and 6 "404"s
in a minute, you could send a distribution which looked like `#150
200 #6 404`.

The CLI lets you send distributions just like normal points.
Wavefront describes distributions in the way I just showed you, with
`#a b` where `a` is the number of times `b` occurred during the time
range. To save you the trouble of counting your individual values,
the CLI lets you describe a distributin "in the raw".

```cmd
$ wf write distribution -V demo.dist 3 1 4 1 1 2 3 6 4 1 3 2
SDK INFO: !M 1539780323 #3 3.0 #4 1.0 #2 4.0 #2 2.0 #1 6.0 demo.dist source=box
       sent 1
   rejected 0
     unsent 0
```

But if you *have* gone to the trouble of counting up the values, it
would be rude of me to expect you to break them up again. So this
will work too.

```cmd
$ wf write distribution -V test.dist 3x3 4x1 2x4 2x2 1x6
SDK INFO: !M 1539781868 #3 3.0 #4 1.0 #2 4.0 #2 2.0 #1 6.0 test.dist source=box
       sent 1
   rejected 0
     unsent 0
```

I chose `3x1` rather than Wavefront's `#3 1` format to save you
having to escape the hash. You can even mix and match, so `3x1
2 3` is fine.

When you send a distribution, you must define the time interval it
covers. The `-I` option lets you do this, and its value can be `m`,
`h` or `d`. If you don't specify, `m` is chosen. When the CLI
detects a distribution it will automatically send it to port 40000.
If you need to use a different port, `-p` will help you out.

You can even take distributions from a file, as we saw above.
When you describe the input file format, just use `d` for
distribution instead of `v` for value. And instead of a single value
in the file, use a comma-separated list of values. Values can be
straight numbers, or they can be duplicated with an `x` in the way
you already saw. All the other rules of `write file` apply.

Note that distribution and histogram data cannot be sent via the API.
They must go through a proxy. This is a design decision of Wavefront
itself, not of the CLI. They also don't currently appear to work if
you send them to the proxy over HTTP.

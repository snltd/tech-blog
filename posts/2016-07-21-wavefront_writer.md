---
title: "Sending Wavefront Data from the CLI"
tags: [Wavefront, Ruby, DTrace]
date: "2016-07-21"
layout: post
category: Wavefront
---

Normally something like collectd, StatsD, Dropwizard or Diamond
sends a constant stream of metrics into Wavefront, but sometimes you
want to do more "one-shot", or ad-hoc things.

With this in mind, I've been back into [the Wavefront CLI
code](https://github.com/wavefrontHQ/ruby-client), this time to add
commands which let you put data into Wavefront.

The `write` command, available in version 3.3.0 of the Gem, sends
points *to a proxy*. You can't write directly to
`metrics.wavefront.com`, or whatever your API endpoint is. Proxies
are inside your firewalls or VPCs, locked down by appropriate rules
or security groups. They do not require or expect authentication,
authorization, or encryption.

## Single, Arbitrary Points: `wavefront write point`

```
wavefront write point [-DV] [-c file] [-P profile] [-E endpoint] [-t time]
          [-p port] [-H host] [-n] [-T tag...] <metric> <value>
```

Wavefront's Ruby SDK provides [a
class](https://github.com/wavefrontHQ/ruby-client/blob/master/lib/wavefront/writer.rb)
which facilitates sending points to a proxy. We used that some time
ago to build a Puppet reporter, which we now use to alert on failed,
particularly long, or unexpectedly-changeful runs. It wasn't
enormously difficult to extend the CLI to use that same class to allow
things like this:

```cmd
$ wavefront write point dev.cli.example 123456
$ wavefront ts -P sysdef -S 'ts("dev.cli.example")'
query               ts("dev.cli.example")
timeseries          0
label               dev.cli.example
host                box
2016-07-21 17:28:21 123456.0
```

Note that I haven't specified a proxy endpoint or port. The `write`
command respects the `.wavefront` config file, so I have my proxy
stowed away in there:

```cmd
$ grep -v token ~/.wavefront
[default]
endpoint = metrics.wavefront.com
format = human
proxy = wavefront.localnet
```

## Multiple Points, From a File

```
wavefront write file [-DV] [-c file] [-P profile] [-E endpoint] [-H host]
          [-p port] [-n] [-F format] [-m metric] [-T tag...] <file>
```

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
$ wavefront write file -V -F tmv file1
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

Here are the points, displayed via an embedded chart. (If you can't
see the chart, you'll have to enable third-party cookies for this
page, because the embedded graphs use Typekit.) Hover over the
points and you'll see the values from the file.

<script src="https://metrics.wavefront.com/embedded/dTjFQkX3XB/js"
id="wavefront-embedded-dTjFQkX3XB" width="700"
height="200"></script>

The key part of the `wavefront write file` command is the `-F`
option. This lets the user describe the format of the file they wish
`wavefront` to parse. `t` stands for `timestamp`; `m` for `metric`,
and `v` for `value`. So, `tmv`, describes the format of `file1`.

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
$ wavefront write file -F tv -m dev.cli.file1 file1
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

## Multiple Points, from a Live Source

Though it's more useful than sending a single point, I still think
loading data in from a static file is something most people would
use rarely, if ever.  Far more useful to, in proper Unix style, set
the input file to `-`, and read from standard in.

Maybe the simplest illustration is to generate some (pseudo) random
data.

```cmd
$ while true; do echo $RANDOM; sleep 0.1; done | wavefront write file -V -m dev.cli.demo -Fv -
Sending: dev.cli.demo 22070.0 1470327276 source=box
Sending: dev.cli.demo 12595.0 1470327276 source=box
Sending: dev.cli.demo 7883.0 1470327276 source=box
Sending: dev.cli.demo 14735.0 1470327276 source=box
Sending: dev.cli.demo 27405.0 1470327277 source=box
Sending: dev.cli.demo 16576.0 1470327277 source=box
Sending: dev.cli.demo 5199.0 1470327277 source=box
Sending: dev.cli.demo 6646.0 1470327277 source=box
Sending: dev.cli.demo 1324.0 1470327277 source=box
Sending: dev.cli.demo 10709.0 1470327277 source=box
...
```

Producing:

<script src="https://metrics.wavefront.com/embedded/S6x9J54m9g/js"
id="wavefront-embedded-S6x9J54m9g" width="700"
height="200"></script>

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
`wavefront`'s `-V` option to watch the points flowing through when I
was testing. (`wavefront` has a `--noop` flag which will not make a
connection to the proxy, and will show you the points in Wavefront
wire format, in real-time.)

Anyway, run the script, and pipe its output into `wavefront`,
supplying a metric path and a description of the file format.

```cmd
$ ./parabola.rb | wavefront write file -m dev.cli.demo -F tv -
```

<script src="https://metrics.wavefront.com/embedded/KN09RPxH6J/js"
id="wavefront-embedded-KN09RPxH6J" width="700"
height="200"></script>

[Back in a previous article, I wrote some Ruby to wire DTrace into
Wavefront](http://sysdef.xyz/post/2016-06-26-dtrace-wavefront). Now,
I can use the `write file` command for simple D scripts.

Revisiting `intr.d`, I can describe the field format I expect, and
`wavefront` will ignore lines which don't match. The first field is
the CPU ID, which I want as the final part of the metric path, and
the second is the value to send (in this case, the total number of
interrupts handled by that CPU). Because I am not supplying any
timestamps, `wavefront` will use the current UTC time whenever it
sends a point. `-V` is for verbosity.

```cmd
# ./intr.d | wavefront write file -V -m dev.cli.d1 -F mv -
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
because of formatting issues!)

```cmd
$ while true; do kstat link:0:net0:obytes64 | grep obytes; sleep 1; done | \
  wavefront write file -Fmv -m dev.cli.network -
```

<script src="https://metrics.wavefront.com/embedded/QT8pF8rKR7/js"
id="wavefront-embedded-QT8pF8rKR7" width="700"
height="200"></script>

That required no setting up, and nothing beyond a local installation
of the `wavefront-client` gem.

---
title: "Writing Metrics with the Wavefront SDK"
date: 2019-04-18
tags: [Wavefront, Ruby]
layout: post
category: Wavefront
---

In version 3.0.0 [my Wavefront SDK]() gained the ability to write
metrics. But it wasn't good enough. So, I've rewritten that part.
It's a breaking change from 3.0.0, hence version 4.0.0.

The big new feature is that when you write a metric it goes on a queue,
which means you get a very quick `return` and can carry on with whatever
important work you're doing. Points are bundled up and flushed by worker
threads, without you having to worry about it. The code handles retrying,
chunking, and point validation, so you don't have to.

## Getting Started

Assuming you've installed the `wavefront-sdk` gem, and have a
Wavefront account and whatnot, you only need to `require` the
`Wavefront::MetricHelper` class. Its initializer looks like this.

```ruby
def initialize(creds, writer_opts = {}, metric_opts = {})
   ...
end
```

`creds` is a mandatory argument, and it must be a hash of things
which will enable a `Wavefront::Writer` to talk to Wavefront.  The
easiest way to get this object is via `Wavefront::Credentials`.
`Wavefront::Writer` will need different information depending on how
you ask it to send the points. If you're using a proxy, use the
credential object's `proxy` method, or `creds` if you want to use
the API. Or play it safe and use `all` to pass in both.

The `writer_opts` argument lets you pass objects to
`Wavefront::Writer`. We'll talk more about this later.

The final `metric_opts` option lets you control the way metrics are
bundled up before being sent to Wavefront. The things you're most
likely to set are `flush_interval`, and `delta_interval`. Metrics go
into an in-memory buffer, and are flushed to Wavefront every
`flush_interval` seconds. This defaults to five seconds, but you can
change it if you wish. We'll come to `delta_interval` when we look
at counters.

This, then, is all it takes to set up a metric helper.

```ruby
require 'wavefront-sdk'

creds   = Wavefront::Credentials.new
metrics = Wavefront::MetricHelper.new(creds.all)
```

If you examine the `metrics` object, you'll see it's exposed some
new methods. The ones we're interested in are `gauge`, `counter`,
and `dist`. If you look at those, say in `irb`, you'll see
that they're all independent objects.

```ruby
irb(main):021:0> metrics.class
=> Wavefront::MetricHelper
irb(main):022:0> metrics.gauge.class
=> Wavefront::MetricType::Gauge
irb(main):023:0> metrics.counter.class
=> Wavefront::MetricType::Counter
irb(main):024:0> metrics.dist.class
=> Wavefront::MetricType::Distribution
```

All those classes offer the same public interface. They expose a
Ruby `SimpleQueue`, and your main interaction will be to put points
on those queues via public methods called `q`, and `qq`.

> I had a lot of trouble picking method names: nothing seemed right.
> `write` would get mixed up with `Wavefront::Writer#write`, `send`
> is already a Ruby method, and then I ran out of synonyms. (My
> cheap thesaurus is rubbish, and rubbish, and also rubbish.) I
> tried overloading `#<` and `#<<`, but that seemed wrong and dirty,
> so it's `#q` to queue in short form, and `#qq` to do it in a
> longer fashion.

Throw points at the relevant objects, short-form or longhand, and
they will periodically be flushed to Wavefront. It couldn't (I hope)
be simpler.

## Gauges

Gauges are the simplest metric. They're a path, a value, and maybe
some tags. That's a point in Wavefront. There are, as I just
mentioned, two ways to to that.

`q` takes two or three arguments, and lets you very quickly describe
a point.

```ruby
metric.gauge.q('my.metric.path', 123)
metric.gauge.q('my.metric.path', 123 { tag1: 'value 1', tag2: 'value 2' })
```

Wavefront needs to know the source and the timestamp, and `#q`
fills those in for you. It sets the source as your local hostname,
and the timestamp as "now", however your environment describes it.

If you need more control over your metric descriptions, that is, you
need to set the timestamp or the source, you can use `#qq`. This
takes a hash, which fully describes a point.

```ruby
metric.gauge.qq(path: 'my.metric.path',
                value: 123,
                source: 'blog_example',
                ts:     Time.now.to_i,
                tags:   { tag1: 'value 1', tag2: 'value 2' })
```

You can also send `qq` an array of these points, and it will deal
with them all. Some people might prefer to always use `#qq`, as it
makes your code more explicit.

## Counters

Wavefront has a one-second resolution, so if you send two gauge
points with the same path and tags in the same wallclock second,
only one will end up in Wavefront.

Often though, you want to count these fast moving events, and
Wavefront gives you delta metrics to do that. But using deltas in a
very busy application can really push your point rate up, and if
they're coming in very fast, may not play nicely with direct
ingestion. To help you out, here is `Wavefront::MetricHelper::Counter`.

You can send as many counter metrics as you like, using exactly the
same `#q` and `#qq` syntax as we saw for gauges. When the buffer
flushes, the `MetricHelper` class will bundle up all counters with
the same path, source, and tags, and turn them into a single delta
metric. By default they're rolled-up over a five-second window, which
is the same as the flush interval, but you can change this using
`delta_interval` in the `metric_opts` hash when you create the
`MetricHelper` class. The only rule is that `delta_interval` must be
an exact divisor of `flush_interval`. If it is not, you'll get a
`Wavefront::Exception::InvalidInterval`.

Let's make a little example. I'm going to deliberately set a short
flush interval, and an even shorter delta interval so you can see
the mechanics of the thing.

```ruby
#!/usr/bin/env ruby

require 'wavefront-sdk/credentials'
require 'wavefront-sdk/metric_helper'

creds   = Wavefront::Credentials.new(profile: :beta)
metrics = Wavefront::MetricHelper.new(creds.all,
                                      { verbose: true },
                                      flush_interval: 15,
                                      delta_interval: 5)

1.upto(5).each do |i|
  puts "[#{Time.now}] --> gauge 1"
  metrics.gauge.q('metric_helper.example.001.gauge', i,
                  { type: 'gauge', method: 'q' })

  3.times do
    puts "[#{Time.now}] --> counter"
    metrics.counter.q('metric_helper.example.001.counter', 1,
                      { type: 'counter', method: 'q' })
    sleep 0.1
  end

  puts "[#{Time.now}] --> gauge 2"
  metrics.gauge.qq({ path:  'metric_helper.example.001.gauge',
                     value: i * 2,
                     tags:  { type: 'gauge', method: 'qq' } })
  sleep 10
end

puts "[#{Time.now}] loops have finished. Shut down the helper"
metrics.close!
```

Here's the output, pretty much. I've removed a couple of wordy debug
messages which aren't relevant.

```cmd
$ ./example_001
[2019-04-26 00:16:37 +0100] --> gauge 1
[2019-04-26 00:16:37 +0100] --> counter
SDK DEBUG: started thread for Wavefront::MetricType::Counter
SDK DEBUG: Wavefront::MetricType::Counter sleeping for 15
SDK DEBUG: started thread for Wavefront::MetricType::Distribution
SDK DEBUG: started thread for Wavefront::MetricType::Gauge
SDK DEBUG: Wavefront::MetricType::Gauge sleeping for 15
SDK DEBUG: Wavefront::MetricType::Distribution sleeping for 15
[2019-04-26 00:16:38 +0100] --> counter
[2019-04-26 00:16:38 +0100] --> counter
[2019-04-26 00:16:38 +0100] --> gauge 2
[2019-04-26 00:16:48 +0100] --> gauge 1
[2019-04-26 00:16:48 +0100] --> counter
[2019-04-26 00:16:48 +0100] --> counter
[2019-04-26 00:16:48 +0100] --> counter
[2019-04-26 00:16:48 +0100] --> gauge 2
SDK DEBUG: flushing 6 points [Wavefront::MetricType::Counter]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK DEBUG: flushing 4 points [Wavefront::MetricType::Gauge]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK INFO: ∆metric_helper.example.001.counter 3 1556234212 source=box type="counter" method="q"
SDK INFO: ∆metric_helper.example.001.counter 2 1556234202 source=box type="counter" method="q"
SDK INFO: ∆metric_helper.example.001.counter 1 1556234197 source=box type="counter" method="q"
SDK DEBUG: Closing connection to proxy.
SDK INFO: metric_helper.example.001.gauge 1 1556234197 source=box type="gauge" method="q"
SDK INFO: metric_helper.example.001.gauge 2 1556234198.2589605 source=box type="gauge" method="qq"
SDK INFO: metric_helper.example.001.gauge 2 1556234208 source=box type="gauge" method="q"
SDK INFO: metric_helper.example.001.gauge 4 1556234208.5702245 source=box type="gauge" method="qq"
SDK DEBUG: Closing connection to proxy.
SDK DEBUG: Wavefront::MetricType::Counter sleeping for 15
SDK DEBUG: Wavefront::MetricType::Gauge sleeping for 15
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Distribution]
SDK DEBUG: Wavefront::MetricType::Distribution sleeping for 15
[2019-04-26 00:16:58 +0100] --> gauge 1
[2019-04-26 00:16:58 +0100] --> counter
[2019-04-26 00:16:58 +0100] --> counter
[2019-04-26 00:16:58 +0100] --> counter
[2019-04-26 00:16:58 +0100] --> gauge 2
SDK DEBUG: flushing 2 points [Wavefront::MetricType::Gauge]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK DEBUG: flushing 3 points [Wavefront::MetricType::Counter]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK INFO: metric_helper.example.001.gauge 3 1556234218 source=box type="gauge" method="q"
SDK INFO: metric_helper.example.001.gauge 6 1556234218.878954 source=box type="gauge" method="qq"
SDK DEBUG: Closing connection to proxy.
SDK DEBUG: Wavefront::MetricType::Gauge sleeping for 15
SDK INFO: ∆metric_helper.example.001.counter 3 1556234222 source=box type="counter" method="q"
SDK DEBUG: Closing connection to proxy.
SDK DEBUG: Wavefront::MetricType::Counter sleeping for 15
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Distribution]
SDK DEBUG: Wavefront::MetricType::Distribution sleeping for 15
[2019-04-26 00:17:08 +0100] --> gauge 1
[2019-04-26 00:17:08 +0100] --> counter
[2019-04-26 00:17:08 +0100] --> counter
[2019-04-26 00:17:09 +0100] --> counter
[2019-04-26 00:17:09 +0100] --> gauge 2
[2019-04-26 00:17:19 +0100] --> gauge 1
[2019-04-26 00:17:19 +0100] --> counter
[2019-04-26 00:17:19 +0100] --> counter
[2019-04-26 00:17:19 +0100] --> counter
[2019-04-26 00:17:19 +0100] --> gauge 2
SDK DEBUG: flushing 4 points [Wavefront::MetricType::Gauge]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK DEBUG: flushing 6 points [Wavefront::MetricType::Counter]
SDK DEBUG: Connecting to wavefront-beta:2878.
SDK INFO: metric_helper.example.001.gauge 4 1556234228 source=box type="gauge" method="q"
SDK INFO: metric_helper.example.001.gauge 8 1556234229.190071 source=box type="gauge" method="qq"
SDK INFO: metric_helper.example.001.gauge 5 1556234239 source=box type="gauge" method="q"
SDK INFO: metric_helper.example.001.gauge 10 1556234239.5010407 source=box type="gauge" method="qq"
SDK DEBUG: Closing connection to proxy.
SDK DEBUG: Wavefront::MetricType::Gauge sleeping for 15
SDK INFO: ∆metric_helper.example.001.counter 3 1556234242 source=box type="counter" method="q"
SDK INFO: ∆metric_helper.example.001.counter 3 1556234232 source=box type="counter" method="q"
SDK DEBUG: Closing connection to proxy.
SDK DEBUG: Wavefront::MetricType::Counter sleeping for 15
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Distribution]
SDK DEBUG: Wavefront::MetricType::Distribution sleeping for 15
[2019-04-26 00:17:29 +0100] loops have finished. Shut down the helper
SDK DEBUG: closing Wavefront::MetricType::Gauge queue
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Gauge]
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Gauge]
SDK DEBUG: closing Wavefront::MetricType::Counter queue
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Counter]
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Counter]
SDK DEBUG: closing Wavefront::MetricType::Distribution queue
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Distribution]
SDK DEBUG: flushing 0 points [Wavefront::MetricType::Distribution]
```

That all looks pretty much as we expected. The "extra" flush at the
end looks a bit odd because the buffers happened to be already
empty. We always force a final flush, regardless of the buffer
state. ("Flushing" an empty buffer is a no-op, so it doesn't cost us
anything.) Note that we ran `metrics.close!` at the end: this is
what triggered the flush. If you don't close down the metrics
object, you risk losing points. You can also force a flush any time
with `metrics.flush!`.

Here's the chart of those points.

<script src="https://metrics.wavefront.com/embedded/vKZqmDPPrZ/js"
id="wavefront-embedded-vKZqmDPPrZ" width="700" height="300"></script>

The blue delta line points start way up in the air, and late, because, well,
that's how delta metrics work. Wavefront accumulates points
periodically, and it just happened that this time all our delta
points landed in the same bucket. You could re-run the script, hit
the aggregation point, and get a stepped line, though it would
finish at the same point. The delta points continue for some time
because deltas are repeated every thirty seconds until, I
think there have been no new points in half an hour.

## Distributions

You can also write distributions. These have a slightly different
`q` and `qq` syntax, because distributions are not the same as
points. They accept multiple values, and they need to be told a
bucket size. So:

```ruby
def q(path, interval, value, tags = nil)
..
end
```

A distribution can be written in two ways. Firstly, as an array of what
Wavefront calls "centroids". They are pairs of numbers where the second
number is the value and the first is how many times that value ocurred. For
instance:

```ruby
[[3, 1], [1, 2], [4, 3], [2, 4]]
```

But say you have some code which spits out numbers you want to plot as a
distribution, it's a bit of an inconvenience to have to write code to turn
that random data into centroids. So `dist.q` will accept the a array of
values. So the data above could also be represented as

```ruby
[1, 1, 1, 2, 3, 3, 3, 3, 4, 5]
```

and you'd get exactly the same thing.

Let's have a look. This time we'll use the default flush interval.

```
#!/usr/bin/env ruby

require 'wavefront-sdk/credentials'
require 'wavefront-sdk/metric_helper'

creds   = Wavefront::Credentials.new(profile: :beta)
metrics = Wavefront::MetricHelper.new(creds.all, { verbose: true })

10.times do
  random_dist = Array.new(10).map { |a| rand(10) }

  puts "[#{Time.now}] distribution is #{random_dist}"

  metrics.dist.q('metric_helper.example.002', :m, random_dist)
  sleep 50
end

puts "[#{Time.now}] loops have finished. Shut down the helper"
metrics.close!
```

The script, you can probably tell, makes up a random ten-element
distribution every fifty seconds. It does this ten times. The default flush
time is three minutes, so we'll get one somewhere near in the middle, then
have to force one at the end.

```cmd
$ ./example_002
[2019-04-26 09:57:20 +0100] distribution is [9, 6, 6, 0, 8, 6, 4, 2, 4, 0]
[2019-04-26 09:58:10 +0100] distribution is [5, 5, 5, 7, 8, 5, 1, 2, 5, 7]
[2019-04-26 09:59:00 +0100] distribution is [8, 2, 3, 1, 5, 6, 2, 5, 3, 3]
[2019-04-26 09:59:50 +0100] distribution is [4, 5, 9, 8, 4, 9, 4, 5, 6, 7]
[2019-04-26 10:00:40 +0100] distribution is [7, 2, 4, 0, 3, 4, 2, 2, 7, 9]
[2019-04-26 10:01:30 +0100] distribution is [6, 9, 1, 8, 2, 4, 4, 9, 7, 2]
SDK INFO: !M 1556269040 #1 9.0 #3 6.0 #2 0.0 #1 8.0 #2 4.0 #1 2.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269090 #5 5.0 #2 7.0 #1 8.0 #1 1.0 #1 2.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269140 #1 8.0 #2 2.0 #3 3.0 #1 1.0 #2 5.0 #1 6.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269190 #3 4.0 #2 5.0 #2 9.0 #1 8.0 #1 6.0 #1 7.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269240 #2 7.0 #3 2.0 #2 4.0 #1 0.0 #1 3.0 #1 9.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269290 #1 6.0 #2 9.0 #1 1.0 #1 8.0 #2 2.0 #2 4.0 #1 7.0 metric_helper.example.002 source=box
[2019-04-26 10:02:20 +0100] distribution is [3, 7, 3, 5, 3, 7, 5, 1, 1, 5]
[2019-04-26 10:03:10 +0100] distribution is [7, 6, 6, 2, 2, 4, 3, 3, 8, 7]
[2019-04-26 10:04:00 +0100] distribution is [0, 2, 4, 7, 3, 5, 2, 1, 0, 4]
[2019-04-26 10:04:50 +0100] distribution is [0, 3, 3, 2, 5, 0, 2, 4, 5, 6]
[2019-04-26 10:05:40 +0100] loops have finished. Shut down the helper
SDK INFO: !M 1556269340 #3 3.0 #2 7.0 #3 5.0 #2 1.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269390 #2 7.0 #2 6.0 #2 2.0 #1 4.0 #2 3.0 #1 8.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269440 #2 0.0 #2 2.0 #2 4.0 #1 7.0 #1 3.0 #1 5.0 #1 1.0 metric_helper.example.002 source=box
SDK INFO: !M 1556269490 #2 0.0 #2 3.0 #2 2.0 #2 5.0 #1 4.0 #1 6.0 metric_helper.example.002 source=box
```

You can see in the SDK `INFO` messages that the raw arrays of numbers have
been converted into Wavefront format centroids.

Here's the chart, applying the `max()`, `avg()` and `min()` functions to
those distributions.

<script src="https://virunga.wavefront.com/embedded/r6NknF75Bx/js"
id="wavefront-embedded-r6NknF75Bx" width="700" height="300"></script>

## Things Always Go Wrong

What happens if the queue is full? That's up to you. By default,
writes to Ruby `SizedQueue`s, which do the real work, block. That
is, if the queue is full and your thread tries to add something to
it, your thread will block until the queue becomes available.
Chances are, whatever your main thread is doing is more important
than your metrics, so I decided to make all writes to the queue
default to be *non blocking*. Ruby raises a `ThreadError` exception
it makes a non-blocking call to an unavailable queue, and by default
the SDK will also handle that for you, simply logging a warning.

Naturally, you can control all this, through fields in the
`MetricHelper#new`'s `metric_opts` hash. If you want to handle the
`ThreadError` yourself, set `{ suppress_errors: false }`, and if you
want the normal blocking behaviour, set `{ nonblock: true }`.

If your Wavefront endpoint suddenly becomes unavailable, the writer
class will throw a `Wavefront::Exception::InvalidEndpoint`. This
would normally kill the metric sending thread, so you'd lose all
your metrics even if your endpoint came back. Thus, we catch that
exception, log an error, and carry on.

What happens to your points when they can't be written? They're put
back in the queue for next time. Counter points are put back on the
queue in their aggregated form, which helps keep the size of the
queue down during an endpoint outage.

Another thing to know about counter points is that, like our
attitudes, they should never be negative. This follows convention:
Wavefront deltas are monotonic. If you send a negative value, you'll
get a `Wavefront::Exception::InvalidCounterValue`. All sorts of
validation is done on the points you send. If you wish to turn it
off, include `no_validation: true` in your metric options hash. I
don't know why you would, though, and I haven't really tested the
way the code handles totally insane data, so *caveat emptor*.

## Writer is Your Friend

`Wavefront::MetricHelper` doesn't actually send any metrics
anywhere.  For that it uses `Wavefront::Write`. This is good,
because `Wavefront::Write` has some nice features.

Firstly, you can write to different endpoints. In the examples above
we sent our points to a proxy, using the standard Unix socket
protocol. If we'd added `writer` to the first options hash, we could
have sent the points directly to Wavefront (`writer: :api`); to a
proxy over HTTP (`writer: :http`); or to a local Unix socket
(`writer: :unix`).

We can also pass in a hash of point tags. Then, any points, of any
kind, written through your `MetricHelper` will get those tags, *as
well as* any you send when you write an individual metric.

The following will set up a `MetricHelper` which will write directly
to Wavefront, and tag every point with an entirely pointless
`global_tag`.

```ruby
metrics = Wavefront::MetricHelper.new(creds.all,
                                      { verbose: true
                                        writer:  :api,
                                        tags:    { global_tag: 'yes!' }
                                      })
```

`Wavefront::Write` also takes care of breaking large amounts of
metrics up into manageable chunks, so you don't have to worry about
sending unmanageable payloads if your application suddenly gets very
busy.

That's pretty much all for now, but the `MetricHelper` code is very
modular, so it should be straghtforward to add other metric types,
should you be able to think of any. Why not have a go, and send me a
PR?

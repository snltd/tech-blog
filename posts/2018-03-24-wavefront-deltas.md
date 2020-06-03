---
title: "Wavefront Deltas - Let Me Count the Ways"
date: 2018-03-24
tags: [Wavefront, Ruby]
layout: post
category: Wavefront
---

When you have Wavefront, you want to put *everything* in Wavefront.
But you find some things don't fit well. For instance, we had a
seemingly simple requirement to produce a metric of SSH logins.
(We'll set aside the argument that SSH shouldn't even be running on
anything outside dev for a moment.)

The first solution that came up for review was a collectd plugin
which counted the number of active sessions. No good. If you're not
logged in right at the moment the plugin runs, you're safe. Someone
could be `scp`ing small files on or off, or poking a local command
from a remote session, and it's very unlikely they'd be caught by
that method. This method also created an absolutely huge number of
metrics. (One per potential user, per host, and a point every ten
seconds. It adds up fast.) Next!

We already collect logs with Fluentd, and shovel them over to a
centralised service. That seemed the natural place to look, and the
logging service has good, rich data. Not only can you see *that*
someone logged in, but you can see who it was, when, and where they
came from. But, that was no good either, because the requirement was
for a *metric*. The logging info was a bonus, but whoever opened the
original ticket wanted a chart in Wavefront, probably linked to an
alert. Next!

My colleague and I got involved at this point, and we came up with
the idea of hooking into PAM, and triggering an event from there.
This was easy to do, and we bumped a counter in the statsd
instance that each of our hosts already runs. But statsd works on a
ten-second roll-up. Someone logging in has up to ten seconds to
escalate their privilege, kill statsd, and get away with it.
Furthermore, statsd doesnt start until the end of the bootstrap
Puppet run, so if you can get on the box before Puppet starts the
daemon, your presence will not be noticed. (The PAM hook script
would be baked into the AMI that instances are launched on, so you
can't be there before that is active.) Next!

We needed to get rid of that ten-second interval. What about if the
PAM hook fired a metric straight off to Wavefront? That way you'd
always be noticed unless you had the foresight (and ability) to kill
the proxies first, and we have alerts for that. Problem is, we have
been asked for *the number* of logins, and Wavefront's one-second
resolution means that multiple logins in the same second would be
squashed to one. So that's close, but not quite enough.

What we needed, was a counter in Wavefront. Every login would
trigger a script which immediately bumped that remote counter, and
no one -- short of compromising our Wavefront cluster -- would be
able to tamper with that information.

I spoke to Wavefront about this feature, and it turned out they were
already working on it. "Deltas" have landed in beta, and are coming
to a release shortly. Here's a summary of my experience with them so
far.

## How Do They Get There?

Deltas aren't a class of metrics with their own functions in the way
that histograms are. You can send a delta to any metric by prefixing
the metric name with a `∆`.

That's pretty simple, but you can always make things simpler, so the
first thing I did was extend [the Wavefront Ruby
SDK](https://github.com/snltd/wavefront-sdk)'s
[`Write`](https://github.com/snltd/wavefront-sdk/blob/master/lib/wavefront-sdk/write.rb)
class with a [`write_delta()`
method](https://github.com/snltd/wavefront-sdk/blob/52a9ef66b5af03fcde6eb464f47d4b86cdd1677c/lib/wavefront-sdk/write.rb#L112-L122).
Because deltas aren't separate, it would be easy to forget you were
writing to a counter, omit the `∆` and overwrite the stored value
with a new one.  I thought a separate method would make this less
likely. It's only a wrapper to the existing `write()`, which
prefixes all the points it receives.

Next I added an option to [the
CLI](https://github.com/snltd/wavefront-cli/) which used the new SDK
method. When you send one or more values with `wf write point` (or
`wf write file`), and you set the `-i` option (as in "increment")
those metrics will be sent as deltas.

```cmd
$ wf write point -n delta.test 1
No-op requested. Not opening connection to proxy.
Would send: delta.test 1.0 source=box
$ wf write point -n -i delta.test 1
No-op requested. Not opening connection to proxy.
Would send: ∆delta.test 1.0 source=box
```

The first time I tried it, it didn't work. My proxy threw

```
[PostPushDataTimedTask:logBlockedPoints] [2878] blocked input:
[WF-300 Cannot parse: "?delta.test 2.0 source=box", reason: "Syntax
error at line 1, position 0: token recognition error at: '?'";
remote: 192.168.1.8]
```

because the delta I got from my Unix compose key (Δ U0394 "Greek
Capital Letter Delta", Unicode fans) was not the same as the delta
the developers got when they hit alt-j on a Mac (∆ U2206
"increment"). I changed mine to align with theirs, but I think both
may work when the feature goes live.

## How Do They Look?

With the CLI working, it was time to send some points and see what
came out.

```cmd
$ for i in $(seq 100)
> do
> wf write point -i dev.delta_1 1
> sleep 1
> done
```

<script src="https://longboard.wavefront.com/embedded/JDKZjRT2g2/js"
id="wavefront-embedded-JDKZjRT2g2" width="700"
height="300"></script>

There are a couple of things to note about this chart. First,  the
long tail continues after we stopped sending numbers.  If it
receives no data, a delta metric will report its last value each
minute, for an hour. After an hour without being added to, it goes
quiet.  (Though the previous values, of course, are still there and
always will be.)

Notice also that there's a change in rate of the incrementing data,
even though we sent uniformly spaced points. This is because
Wavefront bundles up all the deltas it receives and generates an
aggregate point every minute.  This means that it's not possible to
accurately gauge the rate at which a delta increases. This is
illustrated by the orange line, which is a calculated `rate()` of
the blue series.  So, no time information is preserved

Are counters global, or per-source? I tried sending that same
incremental series from two hosts at (almost) the same time.

<script src="https://longboard.wavefront.com/embedded/r1C0WFRlh0/js"
id="wavefront-embedded-r1C0WFRlh0" width="700" height="300"></script>

As you see, I got a series for each source, so if you want multiple
sources to write to a single counter, you'll have to fake it with a
`sum()` function, which is the green line on my chart. (This, I
think, is much better than all source contributing anonymously to a
single counter, which is the behaviour I expected.)

You can, of course, see how many deltas your proxies are receiving and
accepting. Here's the proxy's view of the previous examples. I added the
events by hand afterwards.

<script src="https://longboard.wavefront.com/embedded/g3fKrhv33j/js"
id="wavefront-embedded-g3fKrhv33j" width="700" height="300"></script>

Do deltas solve the issue of one login in the same second
overwriting the first? Let's give one a bit of hammer and find out.

Due to the overhead of starting Ruby, loading dependencies,
validating input, opening a new socket and so-on, the CLI can't send
individual points at much in excess of one per second, so to be a
bit more aggressive we'll have to drop down a level. This little
script uses the SDK to open a socket to a proxy and shovel a
thousand identical points through it as fast as possible.

```ruby
require 'wavefront-sdk/write'

wf = Wavefront::Write.new(proxy: 'shark-wf-test')

1000.times do
  wf.write_delta([{ path: 'dev.delta.splurge', value: 1 }])
end
```

Here's the output.

<script src="https://longboard.wavefront.com/embedded/pFJzkZGLwG/js"
id="wavefront-embedded-pFJzkZGLwG" width="700"
height="300"></script>

Nice. all the thousand increments are bundled up together into a
single step. So clearly we can throw deltas at a proxy as fast as
any other kind of point. (The observant reader may notice the chart
actually jumps from 1 to 1001. I sent a single increment through
first so you could see the jump, and the line wouldn't just start at
1000.)

At this point I was curious where in the chain the delta aggregation
was happening. Based on nothing, my assumption was that it happened
on the proxy. Of course, it was easy to find out.

A quick comparison of `~proxy.points.2878.received` and
`~proxy.points.2878.sent` showed no difference: *the proxy forwards
delta metrics to the Wavefront service exactly as it does normal
ones*. This makes sense, but I had briefly hoped that sending huge
amounts of deltas wouldn't count much towards our aggregate point
rate, as they'd be boiled down to almost nothing on the proxies.
Never mind!

## How Do I Break Them?

Having seen how it works, my ops pessimism kicked in, and I was curious
to see how it *breaks*.

I wonder what happens if I sent a "real" value in the middle of some
deltas?

```cmd
$ for i in 1 2 3 4 5
> do
>   wf write point -i dev.delta_3 10
> sleep 20
> done

$ wf write point dev.delta_3 5

$ for i in 1 2 3 4 5
> do
>   sleep 20
>   wf write point -i dev.delta_3 10
> done
```

<script src="https://longboard.wavefront.com/embedded/4GrPy9PBMw/js"
id="wavefront-embedded-4GrPy9PBMw" width="700"
height="300"></script>

The value drops to one just sent, then recovers to where it should
have been on the next aggregation cycle. This correcting behaviour
happens even if you don't send another delta metric. Note that even
though the value "should have been" 50 when we sent the 5, it was
actually only 40. This is because the 5 went straight through,
whilst the deltas were being bundled and flushed every minute.

Though mixing deltas and absolute values is clearly not a very smart
thing to do, Wavefront's behaviour in the face of such abuse seems
pretty robust and sensible to me.

## Negatives? Negative.

My original use-case was incrementing a counter as part of a
security view. Anything even vaguely security-related has to be
watertight, and an obvious way around the proposed system is to log
in and decrement the delta by one.

I tried sending -ve deltas to my proxy. (Remembering to quote the
value, because [docopt](https://github.com/docopt/docopt.rb) can't
really handle arguments with minus signs in them.)

```cmd
$ wf write point-i dev.delta_3 "\-1"
```

The proxy didn't complain, and the point was accepted, but the value
didn't change. This, for my problem at least, is good. Deltas are
monotonically increasing. In the future the proxy will, it appears,
reject delta metrics with negative values, but at the time of
writing they are accepted, but ignored.

## Aggregate Value?

Deltas are a very useful addition to Wavefront, and I can
think of several areas where we will start using them as soon as
they are made properly available.

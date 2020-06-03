---
title: "ELK Sucks Logs"
date: 2017-09-28
tags: [opinion, logs]
layout: post
category: Rants
---

About two years ago, a colleague and I built an internal product known as the
CLS -- the Centralised Logging Service. Our remit was to supply the business'
product teams with everything they needed to collect logs from EC2 and
Cloudwatch, and put those logs in a central, searchable location.

We chose to build this on top of Amazon's Elasticsearch service. All the
product teams had to do was add a Puppet module to their runs, and drop a
Lambda into their accounts, and it all happened as if by magic. Adoption was
good, and the service has been successful.

Over the course of running the service, seeing how people use it, and what it
takes to maintain, I've come to the general view that logs are the enemy.

I'm talking primarily about operation and application logs. Things like
security logs required by a regulatory body are a separate issue.
There's a hard-core of logging information we need, but I think there's a
whole galaxy of junk we don't.

I'll try to explain.

## No One Looks at Them

How can you? We have appications streaming in thousands of messages per second
under normal load. I'm a quick reader, but I can't keep up with that. And even
if I could, what sense could I draw from it beyond "wow, there are a lot of
errors here"?  The more logs you have, the less use they are.

Think of a Puppet run.  Even though Puppet's logging is pretty rotten, and
sometimes downright confusing, it's invaluable when you're writing a module.
You need to see the things happening that you wanted to happen, or know if
they're not. But get that module written, push it to the repo, see it pass the
tests and go out into the wide world, and who cares about those thousand
(probably) identical logs being written every fifteen or twenty minutes. When
was the last time you looked at the log of a successful Puppet run?

Many devs seem not to think about this. They write code which logs profusely
on their laptop. This is natural, and it makes sense. When you're writing the
code that monitors the battery level of your IoT device, it's not unreasonable
to log `battery at 95%`. But that code nearly always gets left in, and you
might end up with a million devices logging `battery at 95%`, every few
minutes. It's the sort of development-to-operations disparity the devops
movement was supposed to fix, but generally hasn't.

The huge volumes of messages that get sent, often containing numerical data,
have led to Kibana growing all kinds of charting capabilities. People plot the
numbers of messages of given levels, or even extract values from those logs
and plot those.

The suggestion is that, at any kind of scale, the messages themselves become
less informative than the trends they create.

This leads us to the idea that...

## Logs Should Probably be Telemetry...

The battery level example above is clear-cut. It should obviously be a metric.
That's assuming it's important at all -- do we actually care if our customer
lets the battery go flat? That's probably a business decision.

## ...because Telemetry is Better

Metrics are cheap. Even multi-dimensional metrics require very little space to
store, so it's not a big deal to keep everything for ever. They're also fast
to search, and to plot, and simple to combine and analyze. Remember earlier we
could only tell that we had a lot of errors: that's useful information: far
more useful than said error reported a million times.

## Most Logs are Pointless Anyway

Many pieces of software log that they've read their configuration file, or
that a particlar transaction completed.  Ask yourself, do you *really* need to
know that? The more I think about it, the more I feel that a normally behaving
piece of software shouldn't be logging anything at all. What do I need to
know, beyond the fact that it's working?

I try to build into my software "health" metrics. In some cases this takes
care of itself. It's natural for an ETL loader to emit the number of lines it
processed on each job. Alert on an absence of that metric rather than on the
presence of a log message saying it was done.

## Some are Downright Dangerous

I've seen phone numbers, addresses, credit card numbers, all sorts. People
write (and sell) systems to screen identifying information out of logs, but
it's better to never run the risk of exposing it in the first place.

## Except the Ones That Are Vital

If there's any business-critical information in your logs, it shouldn't be
in your logs. If it turns out the business really care when the battery goes
flat, that information should be treated properly: written to a database with
guaranteed receipt: not chucked at ELK or syslog and forgotten about.


## Scaling is Hard

I don't mean running a big fat Elasticsearch cluster, though that is a (black)
art in itself. I mean that under normal conditions, our hypothetical
application won't be writing huge numbers of logs. So, we scale down our
heinously expensive cluster. Then, the moment something goes wrong, like a
broken release, or someone turning on `DEBUG`, the cluster gets hammered with
ten, twenty, a hundred or ten thousand times as many messages, and it can't
cope. Messages get dropped, but only at the time you might actually need them.

We try to lessen this impact by having an ingestion tier in front of
Elasticsearch which can buffer. It's an EC2 autoscaling group, so it can, and
does scale fairly quickly, and it protects Elasticsearch, but it can introduce
minutes of latency; again, at the worst possible time.

All of this makes me convinced that:

## ELK is Wrong

Lucene is a very clever, very powerful tool which is great for searching very
large amounts of free text. Things like websites.

We write logs in a shockingly arbitrary fashion.  Normally they go through
some kind of framework which imposes a common format with at least a timestamp
and a level, but the message itself is arbitrary.  We then try to impose some
kind of order with Fluentd or Logstash filtering and tagging.

Structured logs are far better than unstructured logs, but once you've got to
that point, how much further do you have to go to reduce those logs to metrics
with a few carefully chosen tags?

## So What Would You Do, Smart Guy?

Some logs are a necessary evil, but I think there are tactics to minimize how
much we have to deal with.

* Prefer telemetry to logs.
* Definitely prefer telemetry to logs.
* Build health metrics in where you might normally log.
* Don't try to sneak logs in the back door by adding messages as point tags in
  your telemetry. This will blow up horribly.
* Don't use ELK. It's hard to run. It costs a fortune. It encourages bad
  practices like embedding metric data in logs, using structureless messages,
  and throwing every piece of junk at an endpoint because "it might be useful
  later" because you have the tools to find it.
* Rotate logs aggressively. If you need logs to debug, you need them now. Logs
  become exponentially less valuable the older they are.
* If you're maintaining a logging system, work out and publish the cost of
  each message. Logging is not free. A logging budget should be spent
  wisely.
* If you've got a hundred instances of a service, have one or two log rather
  than the whole hundred. You should get a representative sample at far lower
  expense. (This also applies to detailed telemetry.)
* Continue prefering telemetry to logs.
* If you still have boxes, log to the box. It costs nothing and you can hop on
  and have a look if you need to.
* If you have containers use something like Cloudwatch. It eliminates
  aggregation and transmission pipelines, and it costs money, which helps
  focus the mind on the most important point.
* Think carefully -- *really* carefully about what you are logging. When
  things go wrong, what do you *truly* need to know? When things aren't going
  wrong, do you need to know anything beyond that?
* Prefer telemetry to logs.

---
title: "Wavefront Lambdas"
date: 2018-04-28
tags: [Wavefront, AWS, Serverless]
layout: post
category: Wavefront
---

I have a buzz in each ear at the moment. On one side, everyone is
telling me Kubernetes will solve all my problems. On the other side,
all I hear is "Serverless".

When I first heard about "serverless", I loved the idea. (Even
though I did feel that, from a distance, multiple users running
short-lived processes on the same computer didn't seem *quite* the
most revolutionary thing I'd heard.) Containers may not require as
much maintenance as a server, but there's still more than enough
maintenance for most people. Not thinking about even the container
abstraction sounded like something with great appeal.

Particularly exciting was the idea that any (for some value of
"any") event ocurring in any service might trigger one of these
processes. Most of what's left of ops work in the AWS world involves
glueing services together, and a Lambda function seemed like a very
smart kind of glue.

When I started experimenting with Lambda functions, though, my
initial enthusiasm was dulled. A lot of things suddenly seemed a lot
more effort, not least telemetry. I tied myself up in knots thinking
about critical paths in such transient jobs, and about services not
so much "distributed" as "scattered to the winds". In this article,
I hope to try and distill what I and my colleagues have learnt so
far about collecting telemetry from Lambdas.

[A previous blog
post](https://www.wavefront.com/serverless-automatic-rollbacks-wavefront/)
explained a very clever way of integrating Wavefront with AWS
Lambdas. In that article, a Wavefront alert webhook triggers a
Lambda which rolls back a code deployment. Very interesting indeed,
and it's easy to think of many other actions a condition could
invoke.

This article avoids such clever integration, and looks at simply
collecting telemetry from Lambdas.

## Serverful

Lambdas are just processes, and they can be instructed to write to
Wavefront proxies just like anything else can. If you are already a
Wavefront user, you likely have proxies all over the place, and the
natural way of getting telemetry into Wavefront will be via those
proxies.

Here is a very simple Python Lambda function which writes a random
value to a proxy, and returns `True`.

```python
import socket
import random

def lambda_handler(event, context):
  sock = socket.socket()
  sock.connect(('wavefront.local', 2878))
  sock.send("lambda.example %f\n" % random.random())
  sock.close()
  return True
```

As you can see, I have a Wavefront proxy, and a CNAME
`wavefront.local` which points to it. Everything is in a VPC, and
the Lambda runs inside a security group which has port 2878 ingress
on the proxy's security group.

There are downsides to this approach. You have to make TCP network
calls within very tight time constraints, which you may consider
unacceptable.

At the very least don't try to send any telemetry until all the
function's actual work is done.

If the proxy is inaccessible, the function will time out, and you'll
be charged for the maximum duration of the execution.  This could be
very bad if your function fires at very high rates.

It would be wise to set short timeouts on your socket operations,
for instance by using a channel in Go. But always be aware you could
be throwing away information!  (Python's not a great choice of
language for this application, in my opinion, but I thought it would
make for the simplest and most universally understandable examples.)

How about identifying the Lambda? Let's remind ourselves of [the
Wavefront wire
format](https://docs.wavefront.com/wavefront_data_format.html).

```
<metricName> <metricValue> [<timestamp>] source=<source> [pointTags]
```

When our Lambda wrote the metric, it  didn't specify a timestamp
or a source, leaving it up to the proxy to fill them in. The
former is fine: we have a very low latency inside a VPC, and
Wavefront's resolution is one second, but the latter could be a
problem, as the proxy will do a reverse DNS lookup, and fill in the
`source` with the name of the EC2 instance on which the Lambda ran.
This is meaningless information for us.

Setting the source as the function name is easily done, using the
`context` object exposed by the Lambda framework

```python
sock.send("lambda.example %f source=%s\n" % (random.random(), context.function_name))
```

There's a problem with this approach though, and it's that
one-second resolution. If the function is invoked multiple times per
second, information is lost. To illustrate, I've wired that Lambda
up to API gateway, so an API request puts a random value into a
Wavefront series. Let's briefly hammer that endpoint with
`siege(1)`.

```cmd
$ siege -t 10s -v -i https://s8qn1nhau5.execute-api.eu-west-2.amazonaws.com/example
** SIEGE 3.0.5
** Preparing 15 concurrent users for battle.
The server is now under siege...
HTTP/1.1 200   0.25 secs:      18 bytes ==> GET  /example
HTTP/1.1 200   0.25 secs:      18 bytes ==> GET  /example
...
HTTP/1.1 200   0.12 secs:      18 bytes ==> GET  /example
HTTP/1.1 200   0.12 secs:      18 bytes ==> GET  /example

Lifting the server siege...      done.

Transactions:            242 hits
Availability:         100.00 %
Elapsed time:           9.48 secs
Data transferred:         0.00 MB
Response time:            0.12 secs
Transaction rate:        25.53 trans/sec
```

242 API requests, all fulfilled. And here's the chart:

<script src="https://virunga.wavefront.com/embedded/90Ry2X8NnZ/js"
id="wavefront-embedded-90Ry2X8NnZ" width="700"
height="300"></script>

Ten points. Count 'em. One per second. We've lost almost all that
vitally important random data. If we were running this application
on a host, we'd probably write to a local Telegraf's statsd input,
and ingest the amalgamated data. But in a Lambda, that's not an
option.  Writing your own roll-up logic is impractical, so
Wavefront's going to have to help us out.

Fortunately, I have a cluster on which histograms are enabled.
Wavefront can roll up data into histograms over various time
periods. The shortest roll-up interval is a minute, so let's tell
the proxy we want it to do that for us. Port 40001 is the default
for per-minute roll-ups by adding this to `wavefront.conf`.

```
histogramMinuteListenerPorts=40001
histogramMinuteAccumulators=2
histogramMinuteFlushSecs=70
```

Then add 40001 ingress to the proxy security group, and change
`2878` to `40001` in the Lambda function. Now let's re-run Siege.

```cmd
$ siege -t 10s -v -i https://s8qn1nhau5.execute-api.eu-west-2.amazonaws.com/example
** SIEGE 3.0.5
** Preparing 15 concurrent users for battle.
The server is now under siege...
HTTP/1.1 200   0.21 secs:      18 bytes ==> GET  /example
HTTP/1.1 200   0.23 secs:      18 bytes ==> GET  /example
...
HTTP/1.1 200   0.11 secs:      18 bytes ==> GET  /example

Lifting the server siege...      done.

Transactions:            218 hits
...
```

Nice! Everything's in there, and we can query that series in various
ways. To illustrate better, I ran Seige for five minutes. Remember,
the roll-up is done every minute. Hover over the lines to see what
they are.

<script src="https://virunga.wavefront.com/embedded/1qfX1r4vBl/js"
id="wavefront-embedded-1qfX1r4vBl" width="700"
height="300"></script>

I picked 90th and 95th percentiles, but I could have chosen
anything. We don't have all those individual data points, but this
is the next best thing. In fact, it's probably better, because it's
far easier to work with.

## Proxyless

But wait. Isn't the whole point of "serverless" that there are no,
er, "servers"? And aren't our Wavefront proxies running on servers,
or at least in containers? This is a swizz!

I apologize. Let's consider how we might have our Lambdas write to
Wavefront *without* a proxy.

First, Wavefront now supports direct ingestion. This lets you write
points over the API, provided you have a token and sufficient
privilege. It means a pure serverless architecture would not need
proxies. But, it *will* suffer from the same resolution issues we
discussed earlier, and we can't use histograms, as they are computed
on the proxies.

If you have (as we have) some infrequently-run Lambda in an obscure
account or VPC without proxies, direct ingestion can be extremely
useful, but it's certainly not the key to the serverless-metrics
problem.

Amazon aren't stupid. They know we're going to want telemetry from
our Lambdas, so they've made them automatically write into
Cloudwatch. Wavefront aren't stupid either, so they've made
Wavefront automatically *read* from Cloudwatch, as part of the AWS
integration. Can you see where this is going?

To set up the AWS integration we have to let Wavefront talk to our
AWS account. In the Wavefront console click "Integrations", then the
big shiny "AWS" button. In the "Setup" tab there's a big green
button that says "SET UP AMAZON INTEGRATION". That's the one you
want. The instructions in there are very easy to follow. Follow
them. I'll wait -- we won't need the CloudTrail integration today,
though you can set it up if you like.

Done it? Great.

The AWS Integration page also has a "Dashboards" tab. Go in to that.
Click the big fat "AWS Lambda" button, and -- boom -- there's a
dashboard.

Like all ready-made dashboards, to change it you have to clone it
and change the clone. Click the little pencil icon in the top right
to do that.

We've had a *lot* of mileage from this default dashboard.  More
often than not, all you really need to know is whether things are
failing (the "Total Errors by Function" chart); if everything is
sufficiently performant ("Total Execution Time by Function") and how
often things are run ("Total Invocations by Function"). That one
dashboard could very well be enough for you. There's even a
drop-down to give you full introspection on individual functions.

It's worth looking at the metrics that make up the charts.
Opening up any chart you'll see the metric paths begin
`aws.lambda.`. Go to "Browse -> Metrics" in the top menu bar, and
type that string into the "Metrics" box. Wavefront will give you a
list of everything Lambda-related that it's pulling in from
Cloudwatch.

So that's the basic operational metrics taken care of, with
virtually no effort on our part. But it's likely we'll want to
record more than that. I might have a Lambda which processes files
`PUT` in an S3 bucket, and I might want to know how many lines it
processed. I'll have to do that myself. And let's assume I don't
have proxies.

We already know Wavefront is getting everything from Cloudwatch, so
presumably if I can put my metrics into Cloudwatch, I'll get them in
Wavefront. How to do that?

Amazon provide a Cloudwatch API call, `PutMetricData`, which sounds a
likely suspect. But to trigger this from a Lambda, you're going to
have to do some IAM work, and make the API call yourself. Bit of a
pain, and what if the API endpoint isn't available? Pretty unlikely,
you'd think, until you remember that API calls are rate-limited,
with *account level* granularity.

So an API call is expensive, and however careful *you*
might be not to blow your limit and start dropping metrics, some
other function in your account might do it for you.

Oddly, the correct approach -- according to Amazon, who ought to
know about these things -- is to write logs and have them turned
into metrics with a Cloudwatch "Metric Filter".

Long-time Wavefront fans may be familiar with the way the proxies do
[log
ingestion](https://sysdef.xyz/post/2017-02-13-filebeat-wavefront),
and this is very similar.

Let's amend our `metric_lambda` Lambda so it logs its random value.

```python
import random
import logging

def logging_metric(self, message, *args, **kws):
    self._log(9, message, args, **kws)

def lambda_handler(event, context):
    logging.addLevelName(9, "METRIC")
    logging.Logger.metric = logging_metric
    logger = logging.getLogger()
    logger.metric("number is %f" % random.random())
    return "number generated"
```

The `logging_metric()` method adds a new `METRIC` level to the
standard Python `logging` class. You could use an existing level,
but that might lead to confusion. Better to have everything clear,
and separate.

Running that function produces this kind of output, which goes into
a Cloudwatch log stream.

```
START RequestId: aba1328d-5831-11e8-833f-b5cd5e8c0a59 Version: $LATEST
[METRIC]  2018-05-15T11:18:19.297Z aba1328d-5831-11e8-833f-b5cd5e8c0a59  random_number 0.563928
END RequestId: aba1328d-5831-11e8-833f-b5cd5e8c0a59
REPORT RequestId: aba1328d-5831-11e8-833f-b5cd5e8c0a59  Duration:
0.35 ms Billed Duration: 100 ms   Memory Size: 128 MB Max Memory Used: 18 MB
```

In the AWS Cloudwatch console, I made a metric filter on the
`metric_lambda` stream, using the following pattern:

```
[level=METRIC, timestamp, request_id, metric_name, metric_value]
```

Knowing that filter patterns expect a whitespace delimited string,
it should be fairly clear that the final portion of any `METRIC`
level message will be put in the `$metric_value` variable. As the
final step of metric filter creation, I assign a namespace (I chose
`lambdametrics`), a metric name (`random_number` -- this is *not*
automatically pulled out of the pattern) and a metric value
(`$metric_value`). Filters can also operate on JSON payloads, which
is likely a better solution: structured data always beats free text,
even if that structure's only JSON. A simple string will do for our
example, though.

Running the `siege` command from earlier, this "magically" appears
in Wavefront.

As these metrics came in via Cloudwatch, I expected them to be
under the `aws.` namespace, but they're not. The metric path is
`<namespace>.<metric_name>`.

<script src="https://virunga.wavefront.com/embedded/Tv9rkr0rNm/js"
id="wavefront-embedded-Tv9rkr0rNm" width="700"
height="300"></script>

Cloudwatch has rolled-up the metrics for us: we have maximum,
minimum, and average. No arbitrary percentiles like we saw with the
Wavefront histogram, but still pretty neat, particularly for the
very small amount of effort involved.

We also get `sum` and `samplecount` values, which I've put on the
right axis for a bit of clarity.

You can, of course, see all this stuff in Cloudwatch, but it's far
better in Wavefront, in our "single pane of glass", being mixed in
with all the other things we care about that may not be found in
Cloudwatch.

## Lossless

Everything we've considered has been quite low-level. Operational
data, geared to observing the performance of Lambda functions, and
their generalised, "rolled up" data. What about important stuff? What
about business metrics?

What about my Lambda which knows how many items a customer has in
their cart, where I can't roll up the data, and I can't risk
timestamp collisions?

Though it's tempting to think it is, *that's not telemetry*. If your
functions generate something which you *need to know*, you do not
trust it to logs, or to metrics, however good your logging or
telemetry system might be. You write it to a safe, persistent data
store, with logic which guarantees it gets there.

Logs and metrics are something we pretty much throw out into the
æther, assuming, rather than knowing, that they'll get to where they
need to be. They give us patterns and trends which help us run and
debug.

I hope this article has given you a flavour of how Wavefront can
help you run and debug a "serverless" platform.

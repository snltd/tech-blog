---
title: "nginx | filebeat | Wavefront"
tags: [SmartOS, Wavefront, Go, Filebeat]
date: "2017-02-13"
category: Wavefront
layout: post
---

Lately, Wavefront has acquired [log processing
abilities](https://www.wavefront.com/monitoring-metamorphosis-create-metrics-log-data-wavefront/).
In short, you have a log shipper talk to your Wavefront proxy, which
applies
[grok](https://www.elastic.co/guide/en/logstash/current/plugins-filters-grok.html)
rules to match lines and extract data, generating metrics from what
it finds. After processing, the logs are discarded, so Wavefront
doesn't replace something like Splunk, ELK or Graylog, but I think
there is a great deal of value in its approach to statisically
analyzing flows of logs.

On my current client's site, we have hooked our logging to our
telemetry for some time. Logs are collected with
[fluentd](http://www.fluentd.org/), and we use a
`record_transformer` to increment a StatsD counter every time we see
a certain type of log message. This works well, and gives us lots of
useful information. We are very keen on monitoring and alerting off
the whole state of our systems and services, and bringing log volume
in as a metric lets us say, for instance, we don't care about a
small number of errors if the service as a whole is healthy. On the
other hand, should the number of errors or warnings suddenly rise,
we'd want to know about it even if the service were not affected.

Our `record_transformer` method is particularly useful when we, the
SRE team, want to keep an eye on some aspect of an application which
the developers haven't got round to instrumenting. What follows is a
not-particularly-contrived example of that.

The website you are reading runs on a small [SmartOS instance in
Joyent's public cloud](https://www.joyent.com/smartos). It is one of
a few small
[Sinatra](https://www.joyent.com/smartos) applications mapped to
virtual hosts in an nginx proxy.

Nginx writes access and error logs for each site, but up to now,
I've never done anything with any of that data.  Therefore I have no
idea how much traffic this, or any other site, gets. Or how long
page loads typically take.

I have a good OS-level overview of the zone, courtesy of [a custom
Diamond
collector](https://github.com/snltd/sunos-diamond-collectors/tree/master/collectors/smartos-zone)
that I wrote. It lets me know how close I am to my memory resource
caps and how much bandwidth I use, and I'm alerted if any SMF
services fail, or if there's unexpected paging.  It
would be great to add site usage and latency to that dashboard.

### Telling nginx What to Log

First off I changed my nginx log format to produce the information I
needed.

```
http {
  log_format vhost  '$host $remote_addr $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '$upstream_response_time $request_time';
}
```

The server name is now the first field of every log entry. (Nginx
doesn't really think in terms of "vhosts", though I habitually call
them that.) I also log the upstream response and total request
times.

### Telling Wavefront What to Expect and What to Do With It

I turned on Wavefront proxy log ingestion by adding two lines
to `wavefront.conf` and restarting the service.

```
filebeatPort=5044
logsIngestionConfigFile=/config/wavefront/logsIngestion.yaml
```

The `logIngestionConfigFile` is where you define your `grok`
matchers, and tell Wavefront what to do with the data it extracts.

I want to count HTTP responses, grouped by code, and have
information about the response and upstream response times. I also
want to know to which vhost each metric applies. In Graphite, you'd
put the vhost name into the metric path, and you could do that in
Wavefront, but my vhost names contain dots, which Wavefront sees
as path separators. For that reason, I'm going to use point tags to
differentiate between vhosts. Here's my `logsIngestionConfigFile`,
with the `pattern` lines broken for the sake of formatting.

```yaml
---
aggregationIntervalSeconds: 5

histograms:
  -
    pattern: '%{HOSTNAME:vhost} %{IPORHOST:clientip} %{USER:user}
              \[%{HTTPDATE:timestamp}\] (?:%{WORD:verb}
              %{NOTSPACE:request}(?: HTTP/%{NUMBER:httpversion})?|
              %{DATA:rawrequest}) %{NUMBER:response}
              (?:%{NUMBER:bytes}|-) %{NUMBER:urt} %{NUMBER:rt}'
    metricName: 'nginx.code.%{response}'
    tagKeys:
      - vhost
    tagValueLabels:
      - vhost
  -
    pattern: '%{HOSTNAME:vhost} %{IPORHOST:clientip} %{USER:user}
              \[%{HTTPDATE:timestamp}\] (?:%{WORD:verb}
              %{NOTSPACE:request}(?: HTTP/%{NUMBER:httpversion})?|
              %{DATA:rawrequest}) %{NUMBER:response}
              (?:%{NUMBER:bytes}|-) %{NUMBER:urt} %{NUMBER:rt}'
    metricName: 'nginx.time.upstream_response'
    tagKeys:
      - vhost
    tagValueLabels:
      - vhost
  -
    pattern: '%{HOSTNAME:vhost} %{IPORHOST:clientip} %{USER:user}
              \[%{HTTPDATE:timestamp}\] (?:%{WORD:verb}
              %{NOTSPACE:request}(?: HTTP/%{NUMBER:httpversion})?|
              %{DATA:rawrequest}) %{NUMBER:response}
              (?:%{NUMBER:bytes}|-) %{NUMBER:urt} %{NUMBER:rt}'
    metricName: 'nginx.time.response'
    tagKeys:
      - vhost
    tagValueLabels:
      - vhost
```

Each stanza defines a histogram, with the final part of the
metric path dynamically generated. All the grok patterns use named
matchers, whose names can be referenced in subsequent configuration.
So, a successfully handled HTTP request will increment the
`nginx.code.200` counter. I plan to turn that counter into "hits per
second" with Wavefront's `rate()` function.

Point tags are defined by two arrays. The first is the tag key,
called, obviously, `tagKeys`. The second is called `tagValueLabels`,
which gives you a clue how to use it. The elements of this second
array are the names of the matchers in your `pattern`. I create a
single tag called `vhost`, and assign it the value matched by the
`%{HOSTNAME}` at the start of the pattern.

Every point automatically gets a `source` tag just like any normal
metric, so we can easily look at single hosts or environments.

To collect my data I use `histogram`s. Histograms have "buckets",
which acculmulate data then flush it with a given periodicity
(`aggregationIntervalSeconds`).  Like statsd, they produce a bundle of metrics,
including things like `median`, `count`, percentiles, and the standard
deviation.

The Wavefront engine has single second resolution, so plotting multiple times in
the same second will only leave behind the last one (assuming all tags are
equal), but histograms will give a detailed breakdown of all points in that
second, making it trivial to find the outliers you're probably interested in.
For high frequency data, this is what you want. The log ingestion also offers
counters and gauges, but I think they're less useful.

###  Getting Logs to Wavefront

We need a log shipper which can speak
[Lumberjack](https://github.com/elastic/logstash-forwarder/blob/master/PROTOCOL.md).
Fluentd can't easily do this, and we've been falling out of love
with Fluentd anyway, because of the messy path from 0.12 (which
doesn't support much-needed sub-second timestamps) to 0.14 (which
does). So, I'm going to go with
[Filebeat](https://www.elastic.co/products/beats/filebeat). As I
said, I use SmartOS, so I'll have to build Filebeat myself. If you
aren't using SmartOS, you can skip this part. (And whilst you do
that, ask yourself why you *don't* use SmartOS.)

Filebeat needs Go 1.7. Ignore the fact that Go can't tell the
difference between SmartOS and Solaris: they look very similar from
inside a non-global zone, and everything's fine underneath.

```cmd
$ go version
go version go1.7.5 solaris/amd64
$ mkdir -p $GOPATH/src/github.com/elastic
$ cd $_
$ git clone https://github.com/elastic/beats.git
$ cd beats/filebeat
$ make
$ stat $GOPATH/src/github.com/elastic/beats/filebeat/filebeat
  File: `/home/rob/work/go/src/github.com/elastic/beats/filebeat/filebeat'
  Size: 15883676        Blocks: 15373      IO Block: 8192   regular file
Device: 8f80005h/150470661d     Inode: 153540      Links: 1
Access: (0755/-rwxr-xr-x)  Uid: (  264/     rob)   Gid: (   14/sysadmin)
Access: 2017-02-15 13:26:35.429568318 +0000
Modify: 2017-02-13 10:53:21.353451551 +0000
Change: 2017-02-13 10:53:21.353451551 +0000
 Birth: -
```

If you want to save yourself the bother, [here's the
binary](https://us-east.manta.joyent.com/snltd/public/filebeat). It
appears to also work fine on Solaris 11.

From now on I'm going to explain how everything is done "by
hand". In real life I [did all my configuration through
Puppet](https://github.com/snltd/joyent-puppet/blob/master/modules/basenode/manifests/filebeat.pp). It's
easier to follow this way, I think.

I copied the `filebeat` binary to `/opt/local/bin/` on the JPC host,
and also uploaded the following SMF manifest to
`/opt/local/lib/svc/manifest/filebeat.xml`.

```xml
<?xml version='1.0'?>
<!DOCTYPE service_bundle SYSTEM '/usr/share/lib/xml/dtd/service_bundle.dtd.1'>
<service_bundle type='manifest' name='export'>
  <service name='elastic/filebeat' type='service' version='0'>
    <create_default_instance enabled='true'/>
    <single_instance/>
    <dependency name='multi-user-server' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/milestone/multi-user-server'/>
    </dependency>
    <method_context>
      <method_credential group='daemon'
      privileges='basic,!proc_session,!proc_info,!file_link_any,'
      user='logs'/>
    </method_context>
    <exec_method name='start' type='method'
    exec='/opt/local/bin/filebeat -c /config/filebeat/filebeat.yml'
    timeout_seconds='0'/>
    <exec_method name='stop' type='method' exec=':kill -TERM' timeout_seconds='30'/>
    <property_group name='startd' type='framework'>
      <propval name='duration' type='astring' value='child'/>
    </property_group>
    <stability value='Unstable'/>
    <template>
      <common_name>
        <loctext xml:lang='C'>Filebeat log shipper</loctext>
      </common_name>
      <documentation>
        <doc_link name='elastic.co'
          uri='https://www.elastic.co/products/beats/filebeat' />
      </documentation>
    </template>
  </service>
</service_bundle>
```

I SSHed onto the box with the files, made a user for Filebeat to
run as, and imported the manifest. Because `create_default_instance`
is `true`, the service starts automatically once the manifest is
imported.


```cmd
# useradd -s /bin/false -c log-shipper -u 989 -d /var/log/filebeat logs
# mkdir /var/log/filebeat /var/filebeat
# chown logs /var/log/filebeat /var/filebeat
# svccfg import /opt/local/lib/svc/manifest/filebeat.xml
```

My Filebeat config is pretty simple. I don't think anything needs
explaining.

```yaml
---

filebeat.prospectors:
- input_type: log
  paths:
    - /var/log/nginx/*.log
  tail_files: true
  registry_file: /var/filebeat/registry

output.logstash:
 hosts: ["wavefront.localnet:5044"]
        # I added my Graylog box to this array in dev

logging:
  level: info
  to_syslog: false
  to_files: true
  files:
    path: /var/log/filebeat
    name: filebeat.log
    rotateeverybytes: 10485760
    keepfiles: 7

path.data: /var/filebeat
```

### Sexy Graph Time

With Filebeat running, I put four of my sites under
[Siege](https://www.joedog.org/siege-home/), using the `-i` option,
to simulate real traffic, and asked Wavefront to show me
`rate(ts("nginx.code.200"))`.

<script src="https://metrics.wavefront.com/embedded/F5MZSlRCGq/js"
id="wavefront-embedded-F5MZSlRCGq" width="700"
height="300"></script>

And here are the reponse times corresponding to the load generated
above.

<script src="https://metrics.wavefront.com/embedded/qJMgMN29f9/js"
id="wavefront-embedded-qJMgMN29f9" width="700"
height="300"></script>

This is a tiny box, which runs very close to its limits. As you can
see, under load, the response times for `sysdef.xyz` get
unacceptably long, whilst `cassingle.rdfisher.co.uk` don't suffer at
all. Taking the difference between total and upstream times:

<script src="https://metrics.wavefront.com/embedded/KpY0zB9VX0/js"
id="wavefront-embedded-KpY0zB9VX0" width="700"
height="300"></script>

We see that, barring that one spike, all the time is being spent
upstream: that is, in the Ruby application. This explains the
previous result: `sysdef.xyz` is a dynamic site, doing some amount
of processing, and requiring disk access. `cassingle.co.uk`, on the
other hand, only renders some basic markdown, and keeps pretty much
all its content cached in memory. Nginx is fine, and the client
isn't slow. The bad perfomance is definitely *my problem*. There's
always something, isn't there?

The beauty of using Wavefront here, as opposed to Graylog, is that
my metrics and alerting all stay in the same place. I only need one
maintenance window, one Slack webhook, or one Pagerduty config.

I can also build new kinds of alerts, combining log metrics with
"normal" Diamond data, or synthetic Wavefront metrics.  For example,
I might want to alert any time a `50x` error gets logged: that's
simple, and Graylog will happily do it. But, I may also want to know
if the moving average of response times across my entire webserver
tier goes above 300ms. Or maybe only alert if mean upstream response
time breaches a certain threshold whilst the database tier's average
CPU usage is below 30%, and we're in core business hours. All of
these things are now trivially easy, because all these things are
now a single timeseries visible to Wavefront's alerting engine.

If I mark a new code deployment with [a Wavefront
event](/post/2016-07-12-wavefront_events) (which I do), I can clearly
see if the new release causes any change to the nature of my logs.
Perhaps I might see more error or warning lines, or increased
latency, or some other abnormal pattern. Many of us work at scale
now, handling such large flows of logging information that trends
and patterns are far more valuable than the actual data contained in
the log lines themselves.

Kibana can generate graphs and charts from log streams, but
Wavefront is different. It's *made* to process, anaylze and
correlate timeseries. It never throws data away, which centralised
logging systems almost always do, so it's much easier to understand
"normal" usage, and to spot trends and
[anomalies](https://www.wavefront.com/alerting/).

Lately I've spent a lot of time working with streams of logs, and a
lot of time working with Wavefront. Putting the two together seemed
very natural, and though our initial StasD approach was great,
direct log ingestion by Wavefront is much cleaner and more powerful,
and I feel it's something I will see a lot of benefit from in the
future.

## Update

The proxies can now ingest raw logfiles, so log ingestion becomes as
simple as `tail -f | netcat`. A quick illustration. Enable raw log
ingestion by adding this to the proxy config:

```
rawLogsPort=5055
```

Now we must set up some kind of a receiver. As a simple example, I'm
going to make a quick chart of the facilty and level of
everything going into `syslog` on a Linux VM. (Solaris uses multiple
system logs, which means this wouldn't be a simple one-liner.)

So, my `logsIngestion.yaml` needs a new `counter`, with a definition
of my `syslog` format. We use a modified syslog format, recording
more information than Linux usually does. (Again, the grok pattern
is broken for formatting.)

```yaml
pattern: '%{TIMESTAMP_ISO8601:time} %{WORD:facility}.%{WORD:level} \
          %{HOSTNAME:source} %{SYSLOGPROG:program}:%{GREEDYDATA:message}'
  metricName: 'syslog.%{facility}.%{level}'
tagKeys:
  - source
tagValueLabels:
  - source
```

Then on the host, just do:

```cmd
$ tail -F /var/log/syslog | nc wavefront 5055
```

and we see:

<script src="https://metrics.wavefront.com/embedded/x4hK3lqHQ6/js"
id="wavefront-embedded-x4hK3lqHQ6" width="700"
height="300"></script>


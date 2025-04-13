---
title: "How Wavefront Tamed a Wild Puppet"
tags: [Wavefront, Puppet, Ruby]
date: 2017-10-01
category: Wavefront
---

There used to be charts in this page, but the infrastructure which backed them
no longer exists.

[Here is an edited-for-marketing version which contains embedded images](https://blogs.vmware.com/tanzu/how-wavefront-tamed-a-wild-puppet/).

Show of hands: who's old enough to remember when config management was the hot
new thing?

No one cares about it now, you know. It's a relic, replaced by `Dockerfile`s and
consigned to history. Except, of course, it's not. There's still a world full of
people configuring VMs and -- yes -- physical hosts with Puppet, Chef, CFengine,
Ansible, Salt,
[finish scripts](https://github.com/snltd/Gentle-Jumpstart/tree/master/finish_scripts),
and who knows what else.

My client's site is one of those places. Even as strong users of many AWS and
aaS tools, they still have an awful lot of EC2 hosts, managed with masterless
Puppet. There are nice things about running masterless: effectively infinite
scaling, and very little to go wrong, for a start. But there's one huge
downside: knowing what all those independent agents are doing is entirely down
to you.

## First Things First

The business is a little unusual in that it has several distinct product
platforms with differing requirements. Each platform, however, is built around a
core of common tooling, of which Puppet is one component. Projects begin with a
fork of a bare-bones "reference implementation" repo, which gives engineers
everything they need to run an application except for the application itself.
Hosts are guaranteed to report telemetry to Wavefront, log to our centralised
logging service, and to be compliant with company security policies.

An engineer embedded in a product team cuts a Puppet release by tagging their
repo `RELEASE-YYYY-MM-DD-nn`. A second repo contains a "tag map" which hosts
query regularly, looking themselves up by a combination of their product name,
environment and role. The map tells them which code release they should be on,
and they go and fetch that code, install it, flip a symlink to make it live, and
run Puppet. It's simple, and scalable: but because there's no Puppet Master or
PuppetDB, when we first deployed it, with no telemetry system or off-host
logging, it left no trace anywhere.

## First Steps

As the business matured, and began to switch focus from "get a product out of
the door" to "do things right", progress was more difficult than it should have
been due to a lack of visibility. Puppet was the tool through which we would
have to fix and improve our infrastructure, so it was naturally the first place
we wanted observability.

We had already tried, and largely failed, to get some insight into the state of
our config management (using a different hosted telemetry service), but as we
began trialling Wavefront it seemed worth another go. I took the nascent
[Ruby SDK](https://github.com/wavefrontHQ/ruby-client) and used it to build a
Puppet-to-Wavefront reporter.

The reporter's methodology was simple: take a raw
[Puppet report](https://docs.puppet.com/puppet/latest/format_report.html#puppetresourcestatus),
which summarizes the resources managed by the run and the time spent in various
phases of the operation, and turn those numbers into points in Wavefront. It
wasn't hard to do, and it very quickly gave us some idea of how frequently runs
were failing, and how much work they were doing.

We also pulled lists of hosts out of Wavefront and AWS via the respective APIs,
to find and cull hosts which had no config management at all. We had a lot of
those.

## First Sighting of Trouble

The central services team in which I work has an AWS account where we run a few
core services, and "dogfood" all our new tooling. Testing the first iteration of
the Puppet reporter, I plotted the average `total_time` for Puppet runs across
the account, and saw a steady, constant, and quite unexpected, increase.
Removing the `avg()` from the timeseries expression to present individual hosts
showed the same behaviour on every host.

I picked out a single instance, and changed the query to show `*_time`. Whilst
other metrics held steady, the `file_time` increased with each Puppet run. So I
asked Wavefront for anything filesystem-related disk usage, I/O rate, stuff like
that.

Normalizing multiple metrics on one chart can be a great way to spot
corellations, so I wrapped the query in a `normalize()`, and it was immediately
obvious the amount of data in `/var` was growing at pretty much the same rate as
the `file_time`. Extracting those two metrics and removing the `normalize()`
gave me something very much like this:

<script src="https://metrics.wavefront.com/embedded/3pc3PH675v/js"
id="wavefront-embedded-3pc3PH675v" width="700" height="300"></script>

> The chart above is an after-the-fact reconstruction, made by duplicating in
> the lab the issue I described. I can't show you the original data because it
> was on our evaluation cluster, and we chose not to migrate points over from
> that when we got our "real" single-tenant cluster. If you stay on the same
> cluster, or have old data migrated, Wavefront Never Forgets, and it never
> loses resolution.

Hopping on a box, and looking for big files in `/var` showed `syslog` was huge.
We were trialling a new version of `collectd`, and we'd accidentally left it
running in debug mode, so it was logging like crazy. Every run, even though it
only had to manage the permissions on the file, Puppet calculated the MD5 sum of
`syslog`. Without intervention, that could have bitten us badly, and we could
very easily have pushed the problematic config up to the reference repo, then
out to the product teams. It also suggested our log rotation policy wasn't
sufficiently aggressive, so we fixed that too. An ounce of prevention is worth a
pound of cure.

## First for Knowledge

The original reporter was useful, but we wanted it to do more, not least to
produce metrics on the first run. Because we installed our Wavefront tooling
with Puppet, the catalog was being compiled before the requisite gems were on
the box, and the initial run sent no telemetry.

Even though we couldn't see those initial runs in Wavefront, we knew they had
become way too slow. This led to new tooling to generate partially cooked
"silver" AMIs containing as much common software and configuration as possible.
I made sure [the Wavefront SDK](https://rubygems.org/gems/wavefront-client) went
in, along with our in-house tooling which wraps around it and guarantees
consistent, site-specific ways of performing common tasks.

By this time, the Ruby SDK was much improved, and I rewrote the reporter to use
[the new `batch_writer` class](https://github.com/wavefrontHQ/ruby-client/blob/master/lib/wavefront/batch_writer.rb).
Sadly, the code is proprietary, so I'll have to describe how it works rather
than simply showing it to you.

The most fundamental part of the job is iterating over Puppet's `self.metrics`
object, and turning each value into a point. That's pretty much how you write
any reporter. The interesting part is in adding extra dimensions to the data
with point tags. Every point in one of our new reports gets the following tags:

- **`release`**: As I said, we tag our Puppet code releases
  `RELEASE-YYYY-MM-DD-NN`. So, if your run times go squiffy, or you get
  failures, you can easily see which release introduced the problem. There's a
  down-side though.

  Wavefront, in common with all multi-dimensional metric systems, has issues
  with high cardinality tags. That cardinality is made up of metric, + source +
  tag, and problems (very slow queries) begin at around 1000 such combinations
  on the same metric path. We have a system where all our hosts randomly "commit
  suicide" no more than a week after they are born, so even if we were doing
  five releases an hour for the entire lifetime of each host, we'd be fine. But
  if you have long-lived hosts and frequent releases, you wouldn't want to apply
  this tag, and a couple of our product teams don't. For their benefit, we
  convert the numeric parts of the release into an integer, like `2007061501`,
  and send that as a metric. We also gave our home-made Puppet wrapper script
  the ability to create an instantaneous Wavefront event when a new release
  drops.

- `run_by`: the reporter walks up its process tree, and populates this tag
  according to whatever's at the top. (Well, directly under `init`.) This lets
  you see if a run was triggered by our bootstrapper; as a `cron` job; or kicked
  off by a person, from the command-line.

- `run_no`: the reporter uses a scoreboard file to keep track of the amount of
  times Puppet has run on a host. This has the same potential cardinality issues
  as the `release` tag, and I don't think it's very useful, but one of our
  product teams requested it and presumably use it.

- `new_code`: if the symlink to the Puppet code directory has been updated more
  recently than `run_no`'s scoreboard file, then the reporter assumes the code
  is new, and sets this tag to `true`. An initial run leaves the tag `false`, as
  the reporter can't at that point know whether it's building a new box from old
  code, for instance when scaling an ASG. Don't claim to be something unless
  you're 100% sure.

- `repo`: the name of the Github repository from which the Puppet code and
  config was pulled.

Here is a snippet of one of our real-life charts:

<script
src="https://metrics.wavefront.com/embedded/zxlDzX3V1Q/js"
id="wavefront-embedded-zxlDzX3V1Q" width="700"
height="300"></script>

You can see the bootstrap runs as points, because they have a different tag.
Note that we aren't using the `release` or `run_no` tags here. Some teams do,
some teams don't. This is matching all hosts, buy it's trivial, of course, to
write a a more selective query and only show, say, the `housekeeping` boxes
built from the `puppet-log` repo.

## First Class Results

The chart above is one of a number on our Wavefront "Puppet overview" dashboard.
Product, environment and role are dashboard variables, so it's very easy for any
product team to see, or alert off, the state of their config own management.
It's equally simple for anyone who needs to to look at Puppet across every
product in the business, or wishes to compare their metrics to some other
team's.

Taking the lesson from the `collectd` syslog issue, we have charts which show
the mean run times for bootstrap and "normal" runs (filtered by the value of the
`run_by` tag). Having those separate lets us alert on two time thresholds.

<script src="https://metrics.wavefront.com/embedded/FW5pGvTKVS/js"
id="wavefront-embedded-FW5pGvTKVS" width="700" height="300"></script>

If our bootstrap runs, which include a patching phase, consistently take more
than a couple of minutes, it probably means we're upgrading or installing too
many packages. We have the capability to fire an alert with a webhook and
re-bake our base AMI, which fixes that. If normal runs are taking more than a
couple of minutes, then something has clearly gone wrong, and we must alert.
Tags and events should help us quickly pinpoint the likely cause.

There's also a stacked-area view of the time breakdown, which can be useful. Can
you spot the bootstrap runs?

<script src="https://metrics.wavefront.com/embedded/5KphnQKfQ7/js"
id="wavefront-embedded-5KphnQKfQ7" width="700" height="300"></script>

We also alert on "unexpected changes". Points tagged with `new_code = false` and
`run_by != bootstrapper` are neither bootstrap runs nor new code releases.
Therefore, they should not change any host configuration. If they do, (in
Wavefront parlance `ts("*.host.puppet.changed_resources") > 0`), we want to know
about it, because someone's been messing about where they shouldn't.

Obviously, we alert on any failed resources or events, and aside from the notice
in the appropriate Slack channel, all failing hosts are listed in a tabular view
on the dashboard so they can be quickly investigated. One day I'm going to get
round to creating some external links in Wavefront to take us from those
unexpected points on a chart to a relevant query in our centralised logging
service in a single click. I just haven't got around to it yet.

As I mentioned earlier, an extra point goes in with the Puppet report data. Its
value is the numeric part of the release: for example `RELEASE-2016-12-04-01`
becomes `2016120401`. We look at the variance of this metric to check that
environments or groups of hosts are all on the same release. If you deploy your
application via Puppet, you'd want to know if the tier wasn't uniform by the end
of any rolling release.

<script src="https://connectedhome.wavefront.com/embedded/vxtdy9FTB6/js"
id="wavefront-embedded-vxtdy9FTB6" width="700" height="200"></script>

Here, you can see everything has the same release. Wavefront lets you colour the
text in a single-value chart depending on the value. Green is good, as they
almost say.

## Done

When you think of Wavefront, you immediately think of its ability to ingest and
analyze insane amounts of data, but we have found there can also be tremendous
value in a few carefully selected, multi-dimensional points.

I hope I've shown how Wavefront, fed by a small piece of quite simple code took
us quickly from "we have no idea what's happening" to "we can automatically
re-bake our AMI when it takes too long to launch a box".

Wavefront can easily become an alternative to vendor-supplied config management
observability, and there's an awful lot to be said for the "single pane of
glass" approach, with all your metrics and alerting in one place. With a
source-agnostic approach and a
[well-documented wire format](https://docs.wavefront.com/wavefront_data_format.html),
it's trivial to make anything that produces metrics talk to Wavefront, and
immediately get visibility, alerting, and sophisticated analytics on that data.

I couldn't share the code for the Puppet reporter I talked about, as it belongs
to my client. But it's been so useful I decided I needed something similar in
the infrastrucutre I manage for myself. So, I wrote a similar reporter from
scratch, using the
[new, far more comprehensive SDK](https://github.com/snltd/wavefront-sdk). The
tags are different, and though it supports various operating systems, I've only
run it, so far, on [SmartOS](https://www.joyent.com/smartos). If you're running
masterless Puppet,
[check out the code and give it a go](https://github.com/snltd/wavefront-puppet-reporter).
If you're on some other config management system, it shouldn't be a hard thing
to port. It would certainly make a nice little Chef handler without a lot of
effort. Contribute to the community and share the love!

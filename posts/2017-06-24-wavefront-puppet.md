---
title: "How Wavefront Tamed a Wild Puppet"
tags: [Wavefront, Puppet, Ruby]
date: "2017-06-24"
layout: post
category: Wavefront
---

## First Things First

Hands up who's old enough to remember when config management was the
cool new thing? No one cares about it now, of course, it's a relic,
replaced by `Dockerfile`s and consigned to history. Except, of
course, it's not. There's still a world full of people configuring
VMs and -- yes -- physical hosts with Puppet, Chef, CFengine,
Ansible, Salt and who knows what else.

My client's site is one of those. They have a masterless Puppet
model, which works broadly as follows.

Puppet code and Hiera config are kept together in a Github repo. The
business is a little unusual in that it has several product
platforms with different requirements, but all product teams use a
core of common tooling, of which Puppet is one component.

An engineer embedded in a product team cuts a release by tagging the
repo `RELEASE-YYYY-MM-DD-nn`.  A second repo contains a "tag map"
which hosts query regularly, looking themselves up by a combination
of their product name, environment and role. The map tells them
which code release they should be on, and they go and fetch that
code, install it, flip a symlink to make it live, and run Puppet.
It's simple, and scalable: but because there's no Puppet Master or
PuppetDB, it leaves no trace anywhere.

## First Steps

When we began trialling Wavefront, I took the nascent [Ruby
SDK](https://github.com/wavefrontHQ/ruby-client) and used it to
build a Puppet-Wavefront reporter. Its methodology was simple:
take a raw [Puppet
report](https://docs.puppet.com/puppet/latest/format_report.html#puppetresourcestatus)
-- which summarizes the resources managed by the run and the time
spent in various phases of the operation -- and
turn those numbers into points in Wavefront. It wasn't hard to do,
and it very quickly gave us some idea of how frequently runs were
failing, and how much work they were doing.

## First Mistake

The central services team in which I work has an AWS account where
we run a few core services, and "dogfood" all our new tooling.
Testing the first iteration of the Puppet reporter, I plotted the
`total_time` for Puppet runs across the account, and saw a steady,
constant, unexpected, increase.

Changing the query to show `*_time`, showed that whilst other
metrics held steady, the `file_time` increased with each Puppet run.
So I asked Wavefront for anything filesystem-related
 disk usage, I/O rate, stuff like that.

Normalizing multiple metrics on one chart can be a great way to spot
corellations, so I wrapped the query in a `normalize()`, and it was
immediately obvious the amount of data in `/var` was growing at
pretty much the same rate as the `file_time`. Extracting those two
metrics and removing the `normalize()` gave me something very much
like this:

<script src="https://metrics.wavefront.com/embedded/QgnDzKMKMs/js"
id="wavefront-embedded-QgnDzKMKMs" width="700"
height="300"></script>

Hopping on a box, and looking for big files in `/var` showed
`syslog` (mode managed with Puppet) was huge. We were
trialling a new version of CollectD, and we'd accidentally left it
running in debug mode, so it was growing `syslog` at quite a rate.
Every run, Puppet calculated the MD5 sum of the file, which took
longer and longer.  Without intervention, that could have bitten us
badly, and we could very easily have pushed the problematic config
out to the product teams. It also suggested our log rotation policy
wasn't sufficiently aggressive, so we fixed that too. An ounce of
prevention is worth a pound of cure.

*The chart above is an after-the-fact reconstruction, made by
duplicating in the lab the issue I described. I can't show you the
original data because it was on our evaluation cluster, and we chose
not to migrate points over from that when we got our "real" cluster.
(If you stay on the same cluster, or have old data migrated,
Wavefront Never Forgets, and it never loses resolution.)*

Viewing the behaviour of the whole estate in Wavefront is as easy as
looking at a single machine, and the ability to quickly compare
seemingly unrelated metrics (filesystem usage and Puppet run time)
lets you diagnose, or at least begin to diagnose, many complicated
problems without going anywhere near a terminal.

We also split the monolithic one-size-fits-none Puppet codebase into
one repo per platform, giving the product teams far more control and
freedom than they previously had. People were no longer afraid to
start fixing their own problems in case they caused more for someone
else. Everyone's repo contained the Puppet reporter, and the
Cloudformation and Puppet code which let them stand up a pair of
load-balanced Wavefront proxies in no time. This was the first, and
one of the most important, steps towards a package of "standard
tooling". We saw the value of Telemetry Everywhere, and wanted it to
be available across the entire business.


## Fine Detail

The original reporter was useful, but we wanted it to do more, not
least to produce metrics on the first run.  Because we installed our
Wavefront tooling with Puppet, the catalog was being compiled before
the requisite gems were on the box, and the initial run sent no
telemetry.

Even though we couldn't see those initial runs in Wavefront, we
still knew they had become way too slow.  This led to new tooling
to generate partially cooked AMIs containing as much common
software and configuration as possible. I made sure [the Wavefront
SDK](https://rubygems.org/gems/wavefront-client) went in, along with
our in-house tooling which wraps around it and guarantees
consistent, site-specific ways of performing common tasks.

With modern dependencies in place, I wrote a new reporter, based
around [the Ruby SDK's (then) new `batch_writer`
class](https://github.com/wavefrontHQ/ruby-client/blob/master/lib/wavefront/batch_writer.rb).
I'd love to be able to share the code, but I'm afraid it's
proprietary. I think I can talk about it though.

The most fundamental part of the job is iterating over Puppet's
`self.metrics` object, and turning each value into a point. That's
pretty much how you write any reporter. The interesting part is in
adding extra dimensions to the data with point tags. Every point in
one of our new reports gets the following tags:

* `release`: we tag our Puppet code releases in a standard way:
  `RELEASE-YYYY-MM-DD-NN`. So, if your run times go squiffy, or you
  get failures, you can easily see which release introduced the
  problem. Wavefront, in common with all multi-dimensional metric
  systems, has issues with high cardinality tags. That cardinality
  is made up of metric, + source + tag, and the warning threshold is
  at around 1000 such combinations on the same metric path. We have
  a system where all our hosts randomly "commit suicide" no more
  than a week after they are born, so even if we were doing five
  releases an hour for the entire lifetime of each host, we'd be
  fine. But if you have long-lived hosts and frequent releases, you
  wouldn't want to apply this tag.
* `run_by`: the reporter walks up its process tree, and populates
  this tag according to whatever's at the top. (Well, directly under
  `init`, or `zsched`, if the reporter runs in a Solaris or SmartOS
  zone.) This lets you see if a run was triggered by our
  bootstrapper, as a `cron` job, or kicked off by a person, from the
  CLI.
* `run_no`: the reporter uses a scoreboard file to keep track of the
  amount of times Puppet has run on a host. This has the same
  potential cardinality issues as the `release` tag, and I don't
  think it's very useful, but one of our product teams requested it.
* `new_code`: if the symlink to the Puppet code directory has been
  updated more recently than `run_no`'s scoreboard file, then the
  reporter assumes the code is new, and sets this tag to `true`. An
  initial run leaves the tag `false`, as the reporter can't at that
  point know whether it's building a new box from old code, for
  instance when scaling an ASG. Don't claim to be something unless
  you're 100% sure.
* `repo`: the name of the Github repository from which the Puppet code
  and config was pulled.

Here is a snippet of one of our real-life charts:

<script
src="https://connectedhome.wavefront.com/embedded/zxlDzX3V1Q/js"
id="wavefront-embedded-zxlDzX3V1Q" width="700"
height="300"></script>

You can see the bootstrap runs as points (because they have a
different tag). Note that we aren't using the `release` or `run_no`
tags here. Some teams do, some teams don't.

## Using the Data

We have a "Puppet overview" dashboard. Product, environment and
machine role are variables, so you can be quite specific with your
query, or look at Puppet across
every product in the business.  Taking the lesson
from the `collectd` issue, we have charts which show the mean run
times for bootstrap and "normal" runs (filtered by the value of the
`run_by` tag). Having those separate lets us alert on two time
thresholds.

<script src="https://connectedhome.wavefront.com/embedded/1l3WVCk9LN/js"
id="wavefront-embedded-1l3WVCk9LN" width="700" height="300"></script>

If our initial runs are taking more than a couple of minutes, then
it might be time to look at baking more stuff into our base AMI. If
normal runs are taking more than a couple of minutes, then something
is clearly wrong. We have alerts for both cases.

There's also a stacked-area view of the time breakdown, which can be
useful. Can you spot the bootstrap runs?

<script src="https://connectedhome.wavefront.com/embedded/5KphnQKfQ7/js"
id="wavefront-embedded-5KphnQKfQ7" width="700" height="300"></script>

We also alert on "unexpected changes". Points tagged with
`new_code = false` and `run_by != bootstrapper` are neither bootstrap
runs nor new code releases. Therefore, they should not change any host
configuration. If they do, (in Wavefront parlance
`ts("*.host.puppet.changed_resources") > 0`), we want to know about it,
because someone's been messing about where they shouldn't.

Obviously, we alert on any failed resources or events, and aside
from the notice in the appropriate Slack channel, all failing hosts
are listed in a tabular view on the dashboard so they can be
quickly investigated.

One extra point goes in with the Puppet report values. We take the
release tag I mentioned earlier, and strip out the non-numbers. So,
`RELEASE-2016-12-04-01` becomes `2016120401`. We look at the variance of
this metric to check that environments or groups of hosts are all on
the same release.

<script src="https://connectedhome.wavefront.com/embedded/vxtdy9FTB6/js"
id="wavefront-embedded-vxtdy9FTB6" width="700" height="200"></script>


---
title: "A New Wavefront CLI"
date: "2017-07-26"
tags: [Wavefront, Ruby]
layout: post
category: Wavefront
---

The [Wavefront](https://wavefront.com) console is excellent, and its
API coverage is complete and simple to use. At my client's
site, we put *everything* in Wavefront, and actively use the data
for alerts, webhooks, and other automated behaviour. The easier it
is to do this, the more it will be done, and the more benefit we all
get.

There is already [a Wavefront CLI and Ruby
SDK](https://github.com/wavefrontHQ/ruby-client), to which I was a
core contributor. But that tool uses API version 1, which is
somewhat limited. It's also, because it evolved in a "we have a
problem right now - fix it!" kind of way, it's a bit messy and WET.

As Wavefront's API uses [Swagger](https://swagger.io/) it is pretty
easy to generate an SDK for whatever language you like. But I find
these machine-generated SDKs hard work to use, and I wanted a nice
little project to work on in my spare time, so I wrote [yet another
Wavefront SDK](https://github.com/snltd/wavefront-sdk), in Ruby.
This has more features, and around 40,000 less lines of code than
its generated equivalent, and I've tried hard to hide the
differences in various API paths behind a consistent interface,
which Swagger would not have done.

Built on top of the SDK is a new [Wavefront
CLI](https://github.com/snltd/wavefront-cli), which I'm going to run
through in this article.

> **Note**: This page gets updated from time to time, as the CLI
> acquires new features.

## Installation and Basics

The CLI and SDK both require Ruby 2.2 or later.  There's no
technical reason why they couldn't have been written to work with
older Rubies, but the sooner we stop our software working with them,
the sooner they'll hopefully go away.

```cmd
$ gem install wavefront-cli
```

This installs the CLI and all its dependencies.  A lot of care has
been taken to ensure there are no "native extension" gems anywhere
in the chain, so installation should be quick and painless on any
host. I *hate* people thinking it's fine to expect me to install a C
compiler to run a hundred-line tool written in a scripting language.

Following the model of [the best designed CLI I
know](https://illumos.org/man/1M/zfs), there's a single command, with
subcommands. I chose `wf` to avoid a clash with `wavefront` from
the old `wavefront-client` gem.

```cmd
$ wf --help
Wavefront CLI

Usage:
  wf command [options]
  wf --version
  wf --help

Commands:
  alert              view and manage alerts
  cloudintegration   view and manage cloud integrations
  config             create and manage local configuration
  dashboard          view and manage dashboards
  derivedmetric      view and manage derived metrics
  event              open, close, view, and manage events
  integration        view and manage Wavefront integrations
  link               view and manage external links
  message            read and mark user messages
  metric             view metrics
  notificant         view and manage Wavefront notification targets
  proxy              view and manage Wavefront proxies
  query              query the Wavefront API
  report             send data directly to Wavefront
  savedsearch        view and manage saved searches
  source             view and manage source tags and descriptions
  user               view and manage Wavefront users
  webhook            view and manage webhooks
  window             view and manage maintenance windows
  write              send data to a Wavefront proxy

Use 'wf <command> --help' for further information.
```

The majority of those commands talk to Wavefront's API. To do that,
`wf` obviously needs to know where the API is, and to pass on some
credentials.

You can do this with command-line options (we'll see those in a
moment), but for everyday interactive use, it's much better to
create a configuration. file.

You can, of course, create configuration by hand, but the `wf
config` command will guide you through it. The first time you run
the program without credentials, it tells you how to create
configuration, and even suggests helpful default values for most
things.

```cmd
$ wf alert list
No credentials supplied on the command line or via environment variables,
and no configuration file found. Please run 'wf config setup' to create
configuration.
$ wf config setup
Creating new configuration file at /home/rob/.wavefront.
Creating profile 'default'.
  Wavefront API token:> 820ac1de-4e1f-41a4-f9c3-231c95ae4da1
  Wavefront API endpoint [metrics.wavefront.com]:>
  Wavefront proxy endpoint [wavefront]:>
  default output format [human]:>
$ wf config show
[default]
token = 820ac1de-4e1f-41a4-f9c3-231c95ae4da1
endpoint = metrics.wavefront.com
proxy = wavefront
format = human
```

You can override values in the configuration files with command-line
options, and also with environment variables. `WAVEFONT_TOKEN`,
`WAVEFRONT_ENDPOINT` and `WAVEFRONT_PROXY` are all supported. If
you have multiple Wavefront accounts, you can add a new stanza for
each account.

Now we're fully credentialled, we can start exploring the CLI.
Let's start with some alerts. Wavefront is great at alerts.

## Alert

```cmd
$ wf alert --help
Usage:
  wf alert list [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-al] [-O fields] [-f format] [-o offset] [-L limit]
  wf alert firing [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-f format] [-o offset] [-L limit]
  wf alert snoozed [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-o offset] [-L limit]
  wf alert describe [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-v version] <id>
  wf alert delete [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          <id>
  wf alert undelete [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert history [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-o offset] [-L limit] <id>
  wf alert import [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          <file>
  wf alert snooze [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-T time] <id>
  wf alert update [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          <key=value> <id>
  wf alert unsnooze [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert search [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-al] [-f format] [-o offset] [-L limit] <condition>...
  wf alert tags [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-f format] <id>
  wf alert tag set [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id> <tag>...
  wf alert tag clear [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert tag add [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id> <tag>
  wf alert tag delete [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id> <tag>
  wf alert currently [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] <state>
  wf alert queries [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-b]
  wf alert summary [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-a]
  wf alert --help

Global options:
  -c, --config=FILE         path to configuration file
  -P, --profile=NAME        profile in configuration file
  -D, --debug               enable debug mode
  -n, --noop                do not perform API calls
  -V, --verbose             be verbose
  -h, --help                show this message

Options:
  -E, --endpoint=URI        cluster endpoint
  -t, --token=TOKEN         Wavefront authentication token
  -l, --long                list alerts in detail
  -a, --all                 list all alerts
  -v, --version=INTEGER     describe only this version of alert
  -o, --offset=n            start from nth alert
  -O, --fields=F1,F2,...    only show given fields
  -L, --limit=COUNT         number of alerts to list
  -T, --time=SECONDS        how long to snooze (default 3600)
  -b, --brief               do not show alert names
  -f, --format=STRING       output format
```

Notice the line-wrapping on the help: it automatically adjusts to
fit the width of your terminal, and I'm an unapologetic, hardcore,
80-column guy. Deal with it.

Let's start by having a look at the alerts in my account.

```cmd
$ wf alert list
1459508340708  CHECKING  Point Rate
1463413550083  CHECKING  JPC Failed Services
...
```

Pretty much every command has a `list` subcommand, and it will give
you a one-item-per-line listing by default, where the first column
is the unique identifer of the resource. Despite what I
said earlier about wrapping lines to fit the terminal, brief
listings don't do that. That's so you can always trust a command
like `wf proxy list | wc -l` to give the answer you expect.

Every command has a sensible set of fields it will `list`, but you
can use `-O` to give a comma-separated list of your own, should you
prefer.

```cmd
$ wf alert list -O id,additionalInformation
1459508340708  Fires if we exceed our agreed point rate
1463413550083  A service has failed. Log on to the box and see what it is
...
```

You can also `list -l`, which more-or-less dumps all of every
resource into your terminal. I don't often use that. Using `-O` in
conjunction with `-l` gives you only the fields you request, one
per-line. Items are separated by a blank line.

By default `list` and `search` will return the first hundred objects
they find. You will be informed if there are more objects, and can
use the `--offset` and `--limit` flags (`-o` and `-L`) to get the
next pages.

But now, all `search` and almost all `list` commands take a `--all`
(or `-a`) option which fetches all objects of the given type. (This
can be a heavy operation, if you have a lot of large objects,
particularly dashboards.) The commands which do not paginate are
`user`, because the API doesn't paginate its response, and `source`,
because there are typically many thousands of sources, and an "all"
operation takes for ever.

We can also `search` for alerts, or, indeed, for any other object
type. (All commands support the `search` sub-command, so long as
their ultimate API endpoint supports it.)

When searching you can define multiple conditions, which the
Wavefront engine will `AND` together to refine a query.  Conditions
are specified as `key=value`. Or, if you wish to search for objects
where the `key` field merely *contains* `value`, use `key~value`.
If you want objects where the field *starts with* the value, use
`key^value`. The default display mode for `search` subcommands is
one object per line, and the fields will be the object's `id`, plus
whichever other keys you used in your conditions.

```cmd
$ wf alert search name~JPC
1497275466684  JPC Failed Services
1463413760189  JPC Memory Shortage
1490980663852  JPC: no metrics
$ wf alert search name~JPC id^149
1497275466684  JPC Failed Services
1490980663852  JPC: no metrics
$ wf alert search name~JPC id^149 severity=SMOKE
1497275466684  JPC Failed Services  SMOKE
$ wf alert search status=SNOOZED
1481553823153  SNOOZED
$ wf alert search status=SNOOZED name~' '
1481553823153  SNOOZED  JVM Memory
$ wf alert search status=SNOOZED name~' '
1481553823153  SNOOZED  JVM Memory
$ wf alert search tags=CLS name~
1463135909875  [["customerTags", ["CLS"]]]  Fluentd Overflow
1460546172048  [["customerTags", ["CLS"]]]  Logging Snapshot Failure
```

Getting more detail is best done in a more targeted way. Let's have
a proper look at that the
[JPC](https://www.joyent.com/triton/compute) Failed
[Services](https://illumos.org/man/5/smf) alert.

```cmd
created                      2016-05-16 15:45:50.083
minutes                      2
name                         JPC Failed Services
id                           1463413550083
target                       someone@example.com,
tags
  customerTags               JPC
status                       CHECKING
inTrash                      false
updateUserId                 someone@example.com
lastProcessedMillis          2017-06-12 10:58:30.534
pointsScannedAtLastQuery     0
createdEpochMillis           2016-05-16 15:45:50.083
updatedEpochMillis           2016-05-16 15:50:08.168
updaterId                    someone@example.com
condition                    ts("dev.diamond.host.smf.svcs.maintenance",
                             host="74a247a9-f67c-43ad-911f-fabafa9dc2f3") > 0
updated                      2016-05-16 15:50:08.168
severity                     SMOKE
additionalInformation        An SMF service has failed. Log on to the box
                             and see what it is.
deleted                      false
```

The data in a `describe` command is usually massaged.
The top-level time-related values have been changed from epoch
milliseconds to a more human-readable format. Also, some data which
is read-only and very unlikely to be useful has been omitted for the
sake of clarity. By default the CLI prints its results in a "human
readable"format, which may not always be what you want. So, we offer
three other format, all selectable with the `-f` option. They are
`json`, `yaml`, and `ruby`. The first two should be self-explanatory,
and `ruby` dumps a string of the raw Ruby object from which all the
other output formats are constructed. It could be useful for pasting
into `irb`, or generating test data.

Returning to the output above, we see a failing service is only
SMOKE? That can't be right, surely. Let's fix it.

```cmd
$ wf alert update severity=SEVERE 1463413550083 | grep severity
severity                     SEVERE
```

I used that `grep` because updating an object will re-display said
object with its new values, and I didn't want to show you the whole
lot again. It only updated the `severity`. Trust me. Be aware lots
of poperties are read-only, at least via the API.

Actually, you know what? I changed my mind. I don't care if a
service fails on a box. I monitor my application, not boxes. If the
application is up and latency is acceptable, that's all I care
about. Let's get rid of that alert.

```cmd
$ wf alert delete 1463413550083
Soft deleting alert '1463413550083'.
Deleted alert '1463413550083'.
$ wf alert describe 1463413550083
API 404: Alert 1463413550083 does not exist.
```

Thinking about it, knowing whether or not a service stopped could
make debugging an outage an awful lot simpler. Fortunately it's only
"soft deleted", which means it can be got back

```cmd
$ wf alert undelete 1463413550083
Undeleted alert '1463413550083'.
```

Remember when we modified the alert earlier? Wavefront does.

```cmd
$ wf alert history 1463413550083 -L1
id                 1463413550083
inTrash            false
version            5
updateUser         someone@example.com
updateTime         1497273637816
changeDescription  Alert severity updated from SMOKE to SEVERE
```

The `-L1` specifies that we only want to see the last revision to
the alert. Without it you'd get the entire history. You see the
`version` number? You use that with the `describe` command we saw
earlier to get a past alert definition. Clearly version 5 introduced
the `SMOKE` to `SEVERE` change, so version 4 should have a severity
of `SMOKE`. Instead of `grep`ping, let's use JSON output and parse
the output properly with the  [json](http://trentm.com/json/)
command.

```cmd
$ wf alert describe 1463413550083 -v 4 -f json | json severity
SMOKE
```

What if we wanted to roll back to that alert? Of course, we could
easily `update` that single change back to the old value, but what
if we wanted to go back a number of revisions?  Here's how we'd do
it.

```cmd
$ wf alert describe 1463413550083 -v 4 -f json >alert-4.json
$ wf alert delete 1463413550083
Soft deleting alert '1463413550083'.
Deleted alert '1463413550083'.
$ wf alert delete 1463413550083
Permanently deleting alert '1463413550083'.
Deleted alert '1463413550083'.
$ wf alert import alert-4.json
Imported alert.
created                   1497275466684
minutes                   2
name                      JPC Failed Services
id                        1497275466684
target                    someone@example.com,
status                    CHECKING
inTrash                   false
updateUserId              someone@example.com
createUserId              someone@example.com
lastProcessedMillis       1497275444832
pointsScannedAtLastQuery  0
createdEpochMillis        1497275466684
updatedEpochMillis        1497275466684
updaterId                 someone@example.com
creatorId                 someone@example.com
condition                 ts("dev.diamond.host.smf.svcs.maintenance",
                          host="74a247a9-f67c-43ad-911f-fabafa9dc2f3") > 0
updated                   1497275466684
severity                  SMOKE
additionalInformation     A service has failed. Log on to the box and see what
                          it is
deleted                   false
```

There's the old alert, fully restored. It has a new `id`, but that's
okay. Everything significant is just the same.

Once an alert is exported you can, of course, do things to it before
re-importing.

At my client's site we have a user who has a number of environments:
dev, staging, prod and so on. He created alerts for the first
environment in the Wavefront console, then exported them and made
them into ERB templates. Now, when he stands up a new environment, a
script combines those templates with a few parameters to generate a
whole new set of alerts, which it pushes to Wavefront.  When he
tears down an environment, a script deletes all alerts tagged with
the environment being destroyed. Infrastucture as code, and alerts
as part of your infrastructure.

If you don't want to make templates (and I, personally, don't), it's
probably simpler and cleaner to manipulate the original structured
data. All you have to do is, in the language of your choice, load
and parse some JSON, change what needs to be changed, dump it and
re-import it.

To illustrate, here is a Ruby script which will read a JSON format
alert from STDIN, change the condition, and dump the modified JSON
to STDOUT.

```ruby
#!/usr/bin/env ruby

require 'json'

alert = JSON.parse(STDIN.read)
alert['condition'] = '0 > 1'
puts alert.to_json
```

If I save that to an executable file called `modifier`, I can run

```cmd
$ wf alert describe -f json 1497275466684 | modifier | wf alert import -
```

and get a new alert with a new condition, leaving the old one in
place. Obviously, it would be no more difficult to change any other
aspect of the alert, or to source it from a version-controlled file
rather than pulling it out of Wavefront.

If you use Terraform, the [Wavefront Terraform
provider](https://github.com/spaceapegames/terraform-provider-wavefront)
can create your alerts, alert-targets and dashboards as part of a
stack. To make this easier, supplying `-f hcl` to a `describe`
subcommand will export any of those objects in
[HCL](https://github.com/hashicorp/hcl) format, ready of pasting
straight into your Terraform configuration. (I discuss this further
[elsewhere](/post/2017-08-28-terraforming-smartos).

What else can we do with the alerts CLI? Well, we can easily snooze
and unsnooze an alert. Let's make an alert that's always going to
fire. Save the following block of YAML as `alert.yaml`.

```yaml
---
name: test alert
target: someone@example.com,
condition: "2 > 1"
displayExpression: ""
severity: SMOKE
minutes: 2
```

Now import it. The CLI will happily import JSON or YAML, so long as
the file has a sensible suffix.

```cmd
$ wf alert import alert.yaml
...
$ wf alert summary
active                   1
active_smoke             1
checking                 9
snoozed                  1
trash                    15
```

Ooh, look, a firing alert! Mor info please!

```cmd
$ wf alert firing
1497276280057  FIRING    test alert
```

What do you know, it turns out that 2 _is_ greater than 1. Good job
we had an alert set up for that!

Snooze that alert for now.

```cmd
$ wf alert snooze -T 10 1497276280057
```

Ten seconds later, and it turns out 2 is still greater than 1.
Snooze it again, this time, indefinitely.

```cmd
$ wf alert snooze 1497276280057
```

`alert firing` and `alert snoozed` are deprecated now. [Changes in
the
SDK](https://github.com/snltd/wavefront-sdk/blob/master/lib/wavefront-sdk/alert.rb#L203-L298)
made it simple to add a more generic `currently` sub-command. So `wf
alert currently firing` shows you all firing alerts, and `wf alert
currently no_data` will show you all the ones whose series have no
points over their last "would fire" interval.  Valid alert states are
`firing`, `snoozed`, `in_maintenance`, `invalid`, `none`,
`checking`, `trash`, and `no_data`.

The `alert queries` subcommand will show you the conditions used
across all your alerts. This can be useful if you're thinking of
thinning out the metrics you collect.

The final batch of `alert` sub-commands are to do with tagging. It's
probably easiest just to show you those:

```cmd
$ wf alert tags 1497276280057
No tags set on alert '1497276280057'.
$ wf alert tag add 1497276280057 example
Tagged alert '1497276280057'.
$ wf alert tag add 1497276280057 sysdef
Tagged alert '1497276280057'.
$ wf alert tags 1497276280057
example
sysdef
$ wf alert tag clear 1497276280057
Cleared tags on alert '1497276280057'.
$ wf alert tags 1497276280057
No tags set on alert '1497276280057'.
$ wf alert tag set 1497276280057 example sysdef numbers
Set tags on alert '1497276280057'.
$ wf alert tags 1497276280057
example
numbers
sysdef
```

Remember that most tags in Wavefront are one-dimensional: point tags
are `key=value` pairs.

We're finished for now, with our tour of the CLI alerting interface.
All that remains is for us to not commit the cardinal sin of leaving
an indefinitely snoozed alert.

```cmd
$ wf alert unsnooze 1497276280057
```

I get a bit paranoid about having missed a firing alert, so I
sometimes run the CLI just to double-check I haven't missed a
notification. To make my life marginally simpler I added a `firing`
command.

```cmd
$ wf alert firing
1459508340708  Point Rate  2018-02-17 01:47:39.929
```

Good job I did. I'm over my allocated point rate! I also like to be
able to check that no one has been snoozing alerts instead of fixing
them.

```cmd
$ wf alert snoozed
1489162558204  Zpool usage  2017-11-17 11:03:12.922
```

Ooh, some cheeky so-and-so has used up all the disk space and
silenced the alert so I didn't find out!

## Alert Targets

The API calls alert targets "notificants". The SDK echoes that, and
the CLI follows the SDK. So, one manages one's alert targets with
the "notificant" command.

Alert targets are typically big things with lots of templating, so
the CLI doesn't provide a short-hand way of creating them in the way
it does for, say, events, or derived metrics. You can still import
them though. You just have to create a JSON or YAML description,
likely starting from an existing one in the way we did with an alert
earlier.

As well as `describe`-ing alert targets, you can do all the usual
listing, deleting, updating, searching, and even testing.

```cmd
$ wf notificant list
CHTo475vsPzSaGhh  WEBHOOK  Slack alert webhook
EKdKFv1rJ6ibahqI  EMAIL    alerts from lab machines
T0i98AtVbs6Zkzlz  EMAIL    alerts from JPC production instances
$ wf notificant test CHTo475vsPzSaGhh
```

You'll have to trust me, but I promise that just popped up a Slack
notification on my desktop.

## Dashboards, Proxies, and Sources

`dashboard` commands are pretty much a subset of the `alert` ones.
Obviously you can't `snooze` a dashboard, but most of the others
work just the same. Dashboard descriptions can be h-u-g-e, so quite
a lot of information is dropped when you `describe` one in
human-readable format. Everything I said about exporting and
templating or manipulating alerts applies just as well to
dashboards.

`proxy` is similar to dashboard, but you can't have versions of
proxies. All the tagging and undeleting goodness is there though.

And speaking of tagging, the `source` command lets you tag and untag
your hosts with exactly the same interface as we just saw for
alerts. You can also set a description for a host. (At the moment
you can't clear a description, due to a bug in the API.)

## Events

The CLI is able to interact more with events than with alerts, or
proxies, or dashboards, so we gain a couple of new subcommands in
the `event` space.

```cmd
$ wf event list
$
```

What, no events? Well, no events in the last ten minutes, which is
the default view when you `list` events. How about all events today?

```cmd
$ wf event list -s 00:00
1497313265697:Alert Edited: No discogs update  ENDED
1497310945968:Alert Snoozed: JVM Memory        ENDED
1497310940168:Alert Deleted: test alert        ENDED
```

Event names are, IMO a bit of a mess. They are the millisecond epoch
timestamp at which the event was created, joined, by a `:`, to the
name of the event. When those names are pretty much free-form
strings like those above, it can get a little confusing. Let's have
a look at that top one, remembering to quote the name.

```cmd
$ wf event describe "1497313265697:Alert Edited: No discogs update"
startTime     2017-06-13 00:21:05.697
endTime       2017-06-13 00:21:05.698
name          Alert Edited: No discogs update
annotations
  severity    info
  type        alert-updated
  userId      slackboy@gmail.com
  created     1495232095593
id            1497313265697:Alert Edited: No discogs update
table         sysdef
updaterId     System Event
creatorId     System Event
canClose      false
creatorType   SYSTEM
canDelete     false
runningState  ENDED
```

We can see that's a system event. Something to know about system
events is that you can't delete them.

```cmd
$ wf event delete "1497313265697:Alert Edited: No discogs update"
API 400: Can only delete user events.
```

Let's create an event. First, a couple of instantaneous events,
occuring right this minute, because they're the simplest kind.

```cmd
$ wf event create -i BANG!
...
$ wf event create -i BITE! -H shark
...
```

The first is a vague, floating-in-space event. It's not attached to a
host, and to see it in your dashboards you'd have to turn on "Show
Events: All". The second is attached to the host `shark`, so it'll
turn up on my Shark dashboard with no extra effort. You can attach
an event to as many hosts as you like.

Both those events could probably do with a bit more information, and
the CLI lets us specify severity (`-S`) event type (`-T`), and a
plain-text description of an event (`-d`).

```cmd
$ wf event create TORNADO! -H shark -S SEVERE -y unlikely \
  -d "an unlikely event"
Event state recorded at /var/tmp/wavefront/rob/1497366980092:TORNADO!.
startTime           1497366980092
name                TORNADO!
annotations
  severity          SEVERE
  type              unlikely
  details           an unlikely event
id                  1497366980092:TORNADO!
table               sysdef
createdEpochMillis  1497366980746
updatedEpochMillis  1497366980746
updaterId           slackboy@gmail.com
creatorId           slackboy@gmail.com
createdAt           1497366980746
updatedAt           1497366980746
hosts               shark
isUserEvent         true
runningState        ONGOING
canDelete           true
canClose            true
creatorType         USER
```

Notice that first line of output. The CLI has created, on the local
host, (not on `shark`) a "state file". This is a little memo of the
event ID, and every open event (i.e. one which is not instantaneous
and does not specify and end time) forces the creation of one. Those
state files work like a stack, and simply issuing an `event close`
command will pop the first one (that is, the last one that was
created) off the top of the stack, and close it. You can also supply
the name of an event to the `close` command (just the name: no
timestamp part) and the last event opened with that name will be
closed. At any time you can see what events this host has open with
`event show`. Watch.

```cmd
$ wf event show
1497366980092:TORNADO!
$ wf event create test
$ wf event create example
$ wf event create example
$ wf event create illustration
$ wf event show
1497367580300:illustration
1497367359553:example
1497367333886:example
1497367298974:test
1497366980092:TORNADO!
$ wf event close test
$ wf event show
1497367580300:illustration
1497367359553:example
1497367333886:example
1497366980092:TORNADO!
$ wf event close tornado
No locally stored event matches 'tornado'
$ wf event close 1497367333886:example
$ wf event close TORNADO!
$ wf event show
1497367580300:illustration
1497367359553:example
$ wf event close
$ wf event close
$ wf event show
No open events.
```

My most common use of `wf event` is to wrap some command or other in
an event. I do this so often, I made a subcommand specifically for
it.

```cmd
$ wf event wrap -C 'stress --cpu 3 --timeout 1m' -T example "pointless busy work"
Event state recorded at
/var/tmp/wavefront/rob/1501109228938:pointless busy work.
Command output follows, on STDERR:
----------------------------------------------------------------------------
stress: info: [2041] dispatching hogs: 3 cpu, 0 io, 0 vm, 0 hdd
stress: info: [2041] successful run completed in 60s
----------------------------------------------------------------------------
Command exited 0
$ echo $?
0
```

Note that "output follows, on STDERR". `wf` takes all output,
standard out and standard error, from the wrapped command, and
dumps it to stderr. This is so, should you need to, you can separate
out the command output. In `event wrap` mode, `wf` exits whatever
the wrapped command exited. Here's a chart showing the event.
(You have to hover over the event to see it.)

<script src="https://metrics.wavefront.com/embedded/ZMdvhTfgG7/js"
id="wavefront-embedded-ZMdvhTfgG7" width="700"
height="300"></script>

```cmd
$ wf event describe "1501109228938:pointless busy work"
id                  1501109228938:pointless busy work
name                pointless busy work
annotations
  type              example
  details           stress --cpu 3 --timeout 1m
table               sysdef
startTime           2017-07-26 23:47:08.938
endTime             2017-07-26 23:48:10.492
createdAt           2017-07-26 23:47:09.721
createdEpochMillis  2017-07-26 23:47:09.721
updatedEpochMillis  2017-07-26 23:48:10.492
updaterId           slackboy@gmail.com
creatorId           slackboy@gmail.com
updatedAt           2017-07-26 23:48:10.492
isUserEvent         true
runningState        ENDED
canDelete           true
canClose            true
creatorType         USER
```

You can see that `wf` has put the command it wrapped into the
`details` field. If I had supplied an event description with `-d`,
that would have been used instead.

## Maintenance Windows

I don't use maintenance windows, as the systems I work on are built
to tolerate the removal of pretty much any component. But, Wavefront
does have good support for them, which the CLI covers. Creating a
window is fairly simple:

```cmd
$ wf window create -d 'demonstrating the CLI' -H shark 'example window'
```

You must supply a reason the window exists (with `-d`) and a title
for the window, which is the final argument. You also have to give
Wavefront some way to connect a window to some sources. This can be
done with alert tags (using `-A`), source tags (`-T`), or host name
patterns (`-H`). These aren't the CLI's constraints, they're the
Wavefront engine's. So, the window above will stop any alerts firing
on any host whose name *matches* the string `shark`. That's nice for
me, because all the zones on that server have `shark` as their
hostname prefix. (Yes, `shark` is a pet: it lives in a cupboard in
my house.) You can mix and match tags and source names, and
Wavefront will `AND` them all together.

Note that I didn't supply a start or end time for my window.
Wavefront requires a start and end time when you create a window,
and the CLI has filled them in for me, opening the window right now,
and closing it in one hour.

```cmd
$ wf window describe 1501844960880
id                    1501844960880
reason                demonstrating the CLI
customerId            sysdef
createdEpochMillis    2017-08-04 12:09:20.880
updatedEpochMillis    2017-08-04 12:09:20.880
updaterId             slackboy@gmail.com
creatorId             slackboy@gmail.com
title                 example window
startTimeInSeconds    2017-08-04 12:09:20
endTimeInSeconds      2017-08-04 13:09:20
relevantHostNames     shark
eventName             Maintenance Window: example window
runningState          ONGOING
```

If I wish, I can extend it. Let's give ourselves another hour.

```cmd
$ wf window extend by 1h 1501844960880
$ wf window describe 1501844960880 | grep endTime
endTimeInSeconds      2017-08-04 14:09:20
```

Or we can close it bang on 2pm

```cmd
$ wf window extend to 14:00 1501844960880
$ wf window describe 1501844960880 | grep endTime
endTimeInSeconds      2017-08-04 14:00:00
```

Or just close it immediately.

```cmd
$ wf window close 1501844960880
id                    1501844960880
reason                demonstrating the CLI
customerId            sysdef
createdEpochMillis    1501844960880
updatedEpochMillis    1501845460225
updaterId             slackboy@gmail.com
creatorId             slackboy@gmail.com
eventName             Maintenance Window: example window
title                 example window
startTimeInSeconds    1501844960
endTimeInSeconds      1501845458
relevantHostNames     shark
runningState          ENDED
```

To see which windows are ongoing, use `wf window ongoing`, and to
see which are coming up soon, use `wf window pending`. By default,
`pending` shows windows which will open in the next 24 hours, but it
takes an optional "hours" argument. So, what windows are coming up
in the next two days?

```cmd
$ wf window pending 48
No maintenance windows in the next 48.0 hours.
```

Like I said, I don't use them,

You can import and export maintenance window objects, just like
everything else.

## Derived Metrics

You can manage [derived
metrics](https://docs.wavefront.com/derived_metrics.html) with the
`derivedmetrics` command. As well as all the usual deleting,
exporting, importing, tagging and whatnot, you can create derived
metrics on the command line. You have to supply a name for the
derived metric, along with the actual metric. So something like:

```cmd
$ wf derivedmetric create my_metric 'aliasMetric(ts(real.series), "alias")'
$ wf derivedmetric list
1529944840652  my_metric
```

Like everything in Wavefront, you can tag derived metrics, and the
`derivedmetric create` subcommand lets you do this on the fly, as
well as specifying a description; adjusting the interval at
which the metric runs on the cluster; specifying the amount of
time over which the metric is created; and whether or not to include
obsolete metrics in the calculations.

Derived metrics support history and soft-deleting.

## Cloud Integrations, Webhooks, External Links and Saved Searches

The `integration`, `webhook`, `link` and `savedsearch` commands are
simpler than those we've seen so far, becaue the API doesn't allow
tagging or soft-deleting of those resource types. The CLI still
lets you list, describe, delete and import them though, and each has
properties you can `update`. The `search` subcommand works for all
of them too.

Now let's look at the "oddball" commands.

## Source

The `source` command lets you manage tags and descriptive strings
for any of your sources. In Wavefront "sources" usually equate to
hosts or containers, but they don't have to. I have some
applications which identify as a source, because I don't care where
they run, only what they say.

You will have lots of sources, so the output of `sources list` will
likely be paginated. (If it is, it says so.) You can use `-o` and
`-L` to set the offset (starting point) and limit of the page you
view.  These options work for all `list` sub-commands, but when
listing sources `-o` should refer to a source name. For everything
else it is a numerical offset. This reflects the way the API works.

By default `source list` does not show sources which are "hidden"
(which usually means they are very old) or Wavefront's own sources
(the things that look like `prod-2b-app101-i-018e5f6aa6d8b3967`).
If you want to see these, supply the `-a` flag.

The hidden and internal sources are filtered out by the CLI
*after* the API call is made, but the `-o` and `-L` flags are set
*before* the call. This can mean it can get a confusing working
through the pages. You're probably better off using `source
search`, or using `-a` and dealing with it.

```cmd
$ wf source describe shark-ws
id            shark-ws
sourceName    shark-ws
hidden        false
description   workstation zone
tags
  ~status.errortrue
  zone        true
  solaris     true
$ wf source clear shark-ws
status
  result OK
  code   200
$ wf source describe shark-ws
id           shark-ws
sourceName   shark-ws
hidden       false
$ wf source description set shark-ws "workstation zone"
status
  result OK
  code   200
$ wf source tag add shark-ws solaris
Tagged source 'shark-ws'.
$ wf source tag add shark-ws zone
Tagged source 'shark-ws'.
$ wf source describe shark-ws
id            shark-ws
sourceName    shark-ws
hidden        false
description   workstation zone
tags
  solaris     true
  zone        true

```

## Message

You won't use this one very much, but it's in the API, so the CLI
covers it. `list` shows any messages you may have (you get them, for
instance, if your cluster is going to be upgraded).  There isn't a
`read` command in the API, so to read a message with the CLI, you
have to do a long listing.

Once you've read a message you can `mark` it as read, and it will go
away. Read messages can still be retrieved with `list -a`. They
appear to age out after `endEpochMillis` has passed.


```cmd
$ wf message list
CLUSTER::743cvsHu  Wavefront Upgrade Notification
$ wf message list -l
scope              CLUSTER
id                 CLUSTER::743cvsHu
content            Wavefront is upgrading to the latest version within the
                   next two (2) weeks. -Wavefront Customer Success
source             system@wavefront.com
title              Wavefront Upgrade Notification
severity           INFO
startEpochMillis   1530553832000
endEpochMillis     1531763432000
display            BANNER
read               false
$ wf message mark CLUSTER::743cvsHu
status
  result OK
  code   200
$ wf message list
$ wf message list -a
CLUSTER::LmPJTdQ8  Wavefront Upgrade Notification
```


## User

As you'd expect, you can `list`, `describe` and `delete` users, but
more interestingly, you can also `revoke` and `grant` privileges.

```cmd
$ wf user describe ian@company.net
identifier   ian@company.net
customer     sysdef
groups       embedded_charts
             browse

$  wf user grant alerts_management to ian@company.net
identifier   ian@company.net
customer     sysdef
groups       embedded_charts
             browse
             alerts_management

$ wf user revoke alerts_management from ian@company.net
identifier   ian@company.net
customer     sysdef
groups       embedded_charts
             browse
```

You can't create users from the CLI for the very good reason that
you can't create users over the API.

## Metric

`metric` lets you find out when a metric was last reported. The
output is sorted on the time, with the most recent first.

```cmd
$ wf metric describe wavefront-proxy.host.uptime.uptime
i-0b10ff25afd0e0c7d  2017-06-13 21:34:38.000
i-0c568ca14f72738a6  2017-06-13 20:56:03.000
i-05bc5822132c5863c  2017-06-13 18:58:15.000
i-059184d32a443b326  2017-06-13 13:42:37.000
i-014e5eb7991d97d4e  2017-06-11 03:14:21.000
i-0c425b83f5430dd13  2017-06-10 18:05:00.000
i-0fc90132760807425  2017-06-09 10:47:14.000
i-01bfb02a7c3ad843e  2017-06-07 23:35:28.000
i-0b2fa0060fc8eae88  2017-06-07 23:31:34.000
i-05f8817d3ac61bfab  2017-06-07 17:27:49.000
```

You can pattern-match your request with the `-g` option.

```cmd
$ wf metric describe wavefront-proxy.host.uptime.uptime -g "i-05*"
i-05bc5822132c5863c  2017-06-13 18:58:15.000
i-059184d32a443b326  2017-06-13 13:42:37.000
i-05f8817d3ac61bfab  2017-06-07 17:27:49.000
```

The `/metric` API seems a little brittle at the moment, and throws a
500 if you search for a metric which does not exist. The CLI
dutifully reports this error.

## Query

The `query` command has quite a lot of options (common options removed for
brevity.)

```cmd
[box:/home/rob/work/sites/sysdef.xyz/posts]$ wf query --help
Usage:
  wf query aliases [-DV] [-c file] [-P profile]
  wf query [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-g granularity] [-s time] [-e time] [-f format] [-WikvO] [-S mode]
          [-N name] [-p points] [-F options] <query>
  wf query raw [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-H host] [-s time] [-e time] [-f format] [-F options] <metric>
  wf query run [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-g granularity] [-s time] [-e time] [-f format] [-F options] [-WkivO]
          [-S mode] [-N name] [-p points] <alias>
  wf query --help

Global options:
  -c, --config=FILE            path to configuration file
  -P, --profile=NAME           profile in configuration file
  -D, --debug                  enable debug mode
  -n, --noop                   do not perform API calls
  -V, --verbose                be verbose
  -h, --help                   show this message

Options:
  -E, --endpoint=URI           cluster endpoint
  -t, --token=TOKEN            Wavefront authentication token
  -g, --granularity=STRING     query granularity (d, h, m, or s)
  -s, --start=TIME             start of query window
  -e, --end=TIME               end of query window
  -N, --name=STRING            name identifying query
  -p, --points=INTEGER         maximum number of points to return
  -i, --inclusive              include matching series with no points inside
                               the query window
  -v, --events                 include events for matching series
  -S, --summarize=STRING       summarization strategy for bucketing points
                               (mean, median, min, max, sum, count, last,
                               first)
  -O, --obsolete               include metrics unreported for > 4 weeks
  -H, --host=STRING            host or source to query on
  -f, --format=STRING          output format
  -F, --format-opts=STRING     comma-separated options to pass to output
                               formatter
  -k, --nospark                do not show sparkline
  -W, --nowarn                 do not show API warning messages

The query command has an additional output format. Using
'-f wavefront' produces output suitable for feeding back into a proxy.
Other output formats are 'yaml', 'json', 'ruby', and 'csv'. CSV format
options are 'headers' (print column headers); 'tagkeys' (print tags as
key=value rather than value); and 'quote' (force quoting of every CSV
element).
```

```cmd
$ wf query 'deriv(ts("nfs.server.v4.read"))'
name         deriv(ts("nfs.server.v4.read"))
query        deriv(ts("nfs.server.v4.read"))
timeseries
  label      nfs.server.v4.read
  sparkline  >   ▁  ▂▁ ▃        ▂▁ ▃   ▁ ▂   <
  host       shark
  tags
    env      lab
  data       2018-06-25   17:10:29    0.0
                          17:10:39    0.0
                          17:10:49    0.0
                          17:10:59    0.0
                          17:11:09    0.0
                          17:11:19    0.0
                          17:11:29    0.0
                          17:11:39    0.5
                          17:11:49    0.0
                          17:15:59    0.0
                          17:16:09    0.0
                          17:16:19    0.0
                          17:16:29    0.6
                          17:16:39    0.4
                          17:16:49    0.0
                          17:16:59    0.8
                          17:17:09    0.0
...
```

The `granularity` is an important option. It lets you select the
bucket size Wavefront will use to aggregate data. If you don't
supply a granularity, the CLI will try to work out the right one
based on the size of the time window you give. And if you don't give
a time window, it will use the last ten minutes.

The Wavefront API expects the query window to be defined by start
and end times in epoch milliseconds, but the CLI will try to convert
any time format you give it, using [Ruby's
`strptime()`](https://ruby-doc.org/stdlib-1.9.3/libdoc/date/rdoc/DateTime.html#method-c-_strptime).
Times as loosely defined as `12:00` or `Saturday` may well work, but
sometimes Ruby will assume `Saturday` means the next one, not the
last one, so choose wisely!

The `sparkline` is a bit of a novelty. It uses Unicode blocks, which
severely limits its range. If it annoys you, `-k` turns it off.

As well as specifying the granularity of the point buckets (just
like the UI does, dependent on its canvas size), you can select the
strategy used on the values in those buckets. Like the UI, the
default strategy is `MEAN`, but the `-S` option lets you specify
`MAX`, `LAST` or any of the others offered by the UI.

The `raw` sub-command requires a host and a metric path - *not* a
time-series expression. It gives you the raw values for that metric,
on that host, over a given range.

```cmd
$ wf query raw 'lab.dev.host.nfs.server.v4.read' -H shark -s 13:00 -e 13:01
  2017-06-14 12:00:06.000    127493.0
             12:00:16.000    127493.0
             12:00:26.000    127493.0
             12:00:36.000    127493.0
             12:00:46.000    127493.0
             12:00:56.000    127493.0
```

Start and end times don't have to be absolute. As of version 2.1.0
of the CLI, you can specify relative times. So you can run a query
over a window from "two hours ago" to "one hour ago", with `-s -2h
-e -1h`. Valid time units are `s`, `m`, `h`, `d`, `w`, and `y` which
I hope are self-explanatory. Because these are relative ranges, the
CLI makes no attempt to compensate for any daylight saving or
calendar changes.

You can specify future times as `+2.5h` or similar. This is useful
for maintenance windows, but if you try to see into the future on a
query, the Wavefront API will, not unreasonably, throw an exception.

Imagine if you got a bit obsessive over running that NFS query.
You'd soon get tired of typing it in, and remembering to balance the
brackets and the quotes. Handily, `wf` lets you "alias" commonly
used queries. To set up an alias called `nfs` for the above query,
you would add this to the relevant stanza of your `~/.wavefront`
file.

```
q_nfs = deriv(ts("lab.dev.host.nfs.server.v4.read"))
```

Then to run the query (with default granularity and time windowing)
you'd just do

```cmd
$ wf query run nfs
...
```

You can, of course, specify all the normal query options with an
alias. The syntax, as I'm sure you noticed, is that the alias name
you'd use must be prefixed with `q_`. This is a workaround for the
limitations of INI files, which don't let you nest sections. (At
least, not in Ruby's understanding of them.)

To see what aliases you have configured, you can just run

```cmd
$ wf query aliases
nfs
```

`wf query` supports additional output formats. `wavefront`
writes out the points in native Wavefront wire format. It works for
timeseries and raw queries.

```cmd
$ wf query 'ts("solaris.network.obytes64", environment=production)' -f wavefront
solaris.network.obytes64 121037323749.0 1533754102 source=wf-blue env="prod" nic="net0"
solaris.network.obytes64 121037670562.0 1533754122 source=wf-blue env="prod" nic="net0"
solaris.network.obytes64 121038023454.0 1533754142 source=wf-blue env="prod" nic="net0"
...
$ wf query raw -H www-blue 'solaris.network.obytes64' -f wavefront
solaris.network.obytes64 1219563430.0 1533751241000 source=www-blue nic="net0" role="sinatra"
solaris.network.obytes64 1219563982.0 1533751261000 source=www-blue nic="net0" role="sinatra"
...
```

`csv` format outputs points as a CSV table. By default no column
headers are printed; values are not quoted unless they contain
whitespace, a comma or a soft quote; and point tags have their
values printed but not their keys. By using the `-F` option you can
change all these things. `-F` takes a comma-separated list of
keywords: `headers` will print the CSV header line; `quote` will
soft-quote every value; and `tagkeys` will print point tags as
`key=value`.

You might have noticed that the timeseries query reports the
point timestamp as epoch seconds, whereas a `raw` query phrases them
as epoch milliseconds. Don't worry about it: the proxy accepts both.

If you have a lot of data you wish to modify, perhaps to rename a
metric path, or retrospectively change tags, you
could pipe the output of these commands through `sed`, `awk`, or
some other stream editing program, and back into a proxy.

```cmd
$ wf query 'ts("solaris.network.obytes64")' -f wavefront \
  | sed 's/solaris/smartos/' \
  | nc wf-proxy 2878
```


## Write

Finally we get to the `write` command. This is different from all
the other commands because it talks to a Wavefront proxy, not the
API. At the moment there's no way to send metrics to Wavefront via
the API.

You can set your proxy endpoint with the `-E` option, but better to
pop a `proxy` entry in your config file, like I did.


```cmd
$ grep proxy ~/.wavefront
proxy = wavefront.localnet
```

Sending a single point is easy.

```cmd
$ wf write point cli.example 10
          sent 1
      rejected 0
        unsent 0
```

You can turn off the summary by supplying `-q` (for "quiet"), but it
will still be printed if there are any rejected or unsent points.

If you don't specify a timestamp, it's stamped "now". But you can
specify one if you want, again, in any parseable format. You can
specify any number of point tags, too.

```cmd
$ wf write point -T timestamp=given -t 17:03 cli.example 9
          sent 1
      rejected 0
        unsent 0
$ wf write point -T timestamp=inferred cli.example 12.3
          sent 1
      rejected 0
        unsent 0
```

<script src="https://metrics.wavefront.com/embedded/cGgfb89wpB/js"
id="wavefront-embedded-cGgfb89wpB" width="700" height="300"></script>

You can also write content from a file. Each line in the file
describes a point, so it must contain at least a value, which we
will call `v`. The line may also contain a metric path we'll call
`m`, a timestamp (`t`), a host (`h`) and point tags (`T`). You can
tell the CLI what order those fields are in with the `-f` option.
So, say you have a file which looks like this:

```
cli.example 1550077536 31640 tag1=val1 tag2=val2
cli.example 1550077536 8887 tag1=val1 tag2=val2
cli.example 1550077536 22038 tag1=val1 tag2=val2
cli.example 1550077536 5406 tag1=val1 tag2=val2
```

you'd use `-f mtvT`. There are a couple of rules. Because it can
contain spaces, the `T` field must come last. And if you don't
supply a metric path in the file, you have to supply one with `-m`.
(If you do both, the `-m` one will be treated as a prefix, and
tagged on to the beginning of the paths in the file.)

The file doesn't have to be a file. Following standard Unix
conventions, you can give the filename as `-`, and the CLI will read
from standard in.

```cmd
$ while true; do echo $RANDOM; sleep 1; done | \
  wf write file -m cli.example -T tag=randomness -Fv -
```

<script src="https://metrics.wavefront.com/embedded/CqVs903Gl2/js"
id="wavefront-embedded-CqVs903Gl2" width="700" height="300"></script>

The `write` command has a lot of options and capabilities, so I
wrote [a separate article which looks more closely at sending
metrics](/post/2018-08-08-wavefront-writer) from the CLI.

## End

That, in a nutshell, is my Wavefront CLI. I hope you find it useful,
and if you find bugs, omissions, or have any great ideas for
features, please [raise an
issue](https://github.com/snltd/wavefront-cli/issues). Pull requests
are even more welcome. Don't forget the tests!

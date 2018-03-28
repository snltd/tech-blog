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
these machine-genrated SDKs hard work to use, and I wanted a nice
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
host. I *hate* people thinking it's fine to expect me to install C
compiler to run a hundred line tool written in a scripting language.

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
  alert           view and manage alerts
  dashboard       view and manage dashboards
  event           open, close, view, and manage events
  integration     view and manage cloud integrations
  link            view and manage external links
  message         read and mark user messages
  metric          view metrics
  proxy           view and manage Wavefront proxies
  query           query the Wavefront API
  savedsearch     view and manage saved searches
  source          view and manage source tags and descriptions
  user            view and manage Wavefront users
  webhook         view and manage webhooks
  window          view and manage maintenance windows
  write           send data to a Wavefront proxy

Use 'wf <command> --help' for further information.
```

Looks pretty simple. Let's start with some alerts. Wavefront is
great at alerts.

## Alert

```cmd
$ wf alert --help
Usage:
  wf alert list [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-l] [-f format] [-o offset] [-L limit]
  wf alert firing [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-o offset] [-L limit]
  wf alert snoozed [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-o offset] [-L limit]
  wf alert describe [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-v version] <id>
  wf alert delete [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert undelete [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert history [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-f format] [-S start] [-L limit] <id>
  wf alert import [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <file>
  wf alert snooze [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-T time] <id>
  wf alert unsnooze [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] <id>
  wf alert search [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-l] <condition>...
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
  wf alert summary [-DnV] [-c file] [-P profile] [-E endpoint]
          [-t token] [-a]
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
  -v, --version=INTEGER     describe only this version of alert
  -o, --offset=n            start from nth alert
  -L, --limit=COUNT         number of alerts to list
  -T, --time=SECONDS        how long to snooze (default 3600)
  -a, --all                 list all alerts
  -f, --format=STRING       output format
```

(Notice the line-wrapping on the help: it automatically adjusts to
fit the width of your terminal, and I'm an unapologetic, hardcore,
80-column guy. Deal with it.)

You can see the `alert` command has quite a lot of subcommands, and
that most of those subcommands have credential-related options. We
don't want to have to manually feed it an endpoint and token every
time we run a command, so let's make a config file. Though you can
override the location with `-c`, the CLI expects to find this file
at `~/.wavefront`, and it expects it to look something like this:

```ini
[default]
token = c9a10d4f-09a1-45ac-1401-9acfa15b433c
endpoint = metrics.wavefront.com
format = human
proxy = wavefront.localnet

[myclient]
token = 820ac1de-4e1f-41a4-f9c3-231c95ae4da1
endpoint = myclient.wavefront.com
format = human
```

It's an INI format file, with a stanza for each Wavefront account
you use. Most people will just have one, but I have a couple. You
only need the `default`. Oh, and in case you were wondering, those
aren't my real tokens!

Now we're fully credentialled, let's have a look at the alerts in my
account.

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

You can also `list -l`, which more-or-less dumps all of every
resource into your terminal. I don't often use that.

We can also `search` for alerts. You can define multiple conditions,
which the Wavefront engine will `AND` together to refine a query.
Conditions are specified as `key=value`. Or, if you wish to search
for objects where the `key` field merely *contains* `value`, use
`key~value`.  If you want objects where the field *starts with* the
value, use `key^value`. The default display mode for `search`
subcommands is one object per line, and the fields will be the
object's `id`, plus whichever other keys you used in your
conditions.

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

Once that alert is exported you can, of course, do things to it. At
my client's site we
have a user who has a number of environments: dev, staging, prod
and so on. He created alerts for one environment in the Wavefront
console, then exported them and made them into ERB templates. He now
has a simple build job which takes those templates and few
parameters and generates a whole batch of alerts, tailored for
one or many environements, and and pushes them back up to Wavefront.
If he wants to change the severity of an alert, he does it in one
place, and it's enacted everywhere.

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

Ooh, look, a firing alert! Quick, back to the listing.

```cmd
$ wf alert list | grep -i firing
1497276280057  FIRING    test alert
```

What do you know, it turns out that 2 _is_ greater than 1. Good job
we had an alert set up for that! Snooze it for now.

```cmd
$ wf alert snooze -T 10 1497276280057
```

Ten seconds later, and it turns out 2 is still greater than 1.
Snooze it again, this time, indefinitely.

```cmd
$ wf alert snooze 1497276280057
```

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

## Dashboards, Proxies, and Sources

`dashboard` commands are pretty much a subset of the `alert` ones.
Obviously you can't `snooze` a dashboard, but most of the others
work just the same. Dashboard descriptions can be h-u-g-e, so quite
a lot of information is dropped when you `describe` one.

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
state files work like a stack, and simply issuing and `event close`
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

You can import also import and export windows, just like everything
else.

## Cloud Integrations, Webhooks, External Links

The `integration`, `webhook`, `window`, and `link` commands are
simpler than those we've seen so far, becaue the API doesn't allow
tagging or soft-deleting of those types of resource. The CLI still
lets you list, describe, delete and import them though, and each has
properties you can `update`.

Now let's look at the three "oddball" commands.

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
$ wf query --help
Usage:
  wf query aliases [-DV] [-c file] [-P profile]
  wf query [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-g granularity] [-s time] [-e time] [-f format] [-ivO] [-S mode]
          [-N name] [-p points] <query>
  wf query raw [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-H host] [-s time] [-e time] [-f format] <metric>
  wf query [-DnV] [-c file] [-P profile] [-E endpoint] [-t token]
          [-g granularity] [-s time] [-e time] [-f format] [-ivO] [-S mode]
          [-N name] [-p points] <query>

Options:
  -g, --granularity=STRING     query granularity (d, h, m, or s)
  -s, --start=TIME             start of query window
  -e, --end=TIME               end of query window
  -N, --name=STRING            name identifying query
  -p, --points=INTEGER         maximum number of points to return
  -i, --inclusive              include matching series with no points
                               inside the query window
  -v, --events                 include events for matching series
  -S, --summarize=STRING       summarization strategy for bucketing points
                               (mean, median, min, max, sum, count, last,
                               first)
  -O, --obsolete               include metrics unreported for > 4 weeks
  -H, --host=STRING            host or source to query on
  -f, --format=STRING          output format
```

```cmd
$ wf query 'deriv(ts("lab.dev.host.nfs.server.v4.read"))'
name        deriv(ts("lab.dev.host.nfs.server.v4.read"))
query       deriv(ts("lab.dev.host.nfs.server.v4.read"))
timeseries
  label     lab.dev.host.nfs.server.v4.read
  host      shark
  data      2017-06-13 22:22:00    0.0
                       22:24:00    0.06666666666666667
                       22:25:00    0.016666666666666666
                       22:26:00    0.016666666666666666
                       22:27:00    0.05000000000000001
                       22:28:00    0.0
                       22:29:00    0.0
                       22:30:00    0.016666666666666666
                       22:31:00    0.016666666666666666
```

The `granularity` is an important option. It lets you select the
bucket size Wavefront will use to aggregate data. If you don't
supply a granularity, the CLI will try to work out the right one
based on the size of the time window you give. And if you don't give
a time window, it will use the last ten minutes.

The Wavefront API expects the query window to be defined by start
and end times in epoch milliseconds, but the CLI will try to
convert any time format you give it, using [Ruby's
`strptime()`](https://ruby-doc.org/stdlib-1.9.3/libdoc/date/rdoc/DateTime.html#method-c-_strptime).
Times as loosely defined as `12:00` or `Saturday` may well work, but
sometimes Ruby will assume `Saturday` means the next one, not the
last one, so choose wisely!

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
limitations of INI files, which don't let you nest sections.

To see what aliases you have configured, you can just run

```cmd
$ wf query aliases
nfs
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
$ wf write point -T tag1=val1 -T tag2=val2 -t 16:30 cli.example 9
$ wf write point -T tag1=val1 -T tag2=val2 cli.example 12.3
```

<script src="https://metrics.wavefront.com/embedded/RSgQw0kMk1/js"
id="wavefront-embedded-RSgQw0kMk1" width="700"
height="300"></script>

You can also write content from a file. Each line in the file
describes a point, so it must contain at least a value, which we
will call `v`. The line may also contain a metric path we'll call
`m`, a timestamp (`t`), a host (`h`) and point tags (`T`). You can
tell the CLI what order those fields are in with the `-f` option.
So, say you have a file which looks like this:

```
cli.example 1497455241 31640 tag1=val1 tag2=val2
cli.example 1497455242 8887 tag1=val1 tag2=val2
cli.example 1497455248 22038 tag1=val1 tag2=val2
cli.example 1497455249 5406 tag1=val1 tag2=val2
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
$ while true; do echo $RANDOM; sleep 0.1; done | \
  wf write file -m cli.example -T tag=randomness -Fv -
```

<script src="https://metrics.wavefront.com/embedded/hGympnPMv9/js"
id="wavefront-embedded-hGympnPMv9" width="700"
height="300"></script>

There's a more in-depth look at the `write` command
[here](http://sysdef.xyz/post/2016-07-21-wavefront_writer). Though
that was written for a previous version of the CLI, the interface
remains the same.

## End

That, in a nutshell, is my Wavefront CLI. I hope you find it useful,
and if you find bugs, omissions, or have any great ideas for
features, please [raise an
issue](https://github.com/snltd/wavefront-cli/issues). Pull requests
are even more welcome. Don't forget the tests!

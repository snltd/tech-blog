---
title: "Wavefront Events from the CLI"
date: 2016-07-12
tags: [Wavefront, Ruby, DTrace]
layout: post
category: Wavefront
---

Recently I extended the [Wavefront Ruby
CLI](https://github.com/wavefrontHQ/ruby-client) to make it easy to open and
close Wavefront events from the CLI or, more usefully, from scripts.

Here's a quite uneventful timeseries:

<img src='/i/wf_event_01.png' width='700' />

Let's create an instantaneous event. You might use this to mark a switchover
to a new release.

```cmd
$ uname -n
shark
$ wavefront event create -i instantaneous_event
```

<img src='/i/wf_event_02.png' width='700' />

You can see the event, and the host to which it is attached. I didn't specify
to which host (or hosts) the event should apply, so the local hostname was used.
There is a `-H` option to the `create` command which lets you supply a
comma-separated list of hostnames to which you want the event to apply.

Now, let's create an open-ended event. You might do this at the start of, say, a
load-test, so when you look at your charts later, it's easy to see when the test
started and finished.

```cmd
$ wavefront event create my_event
Event state recorded at /var/tmp/wavefront/events/rob/1468343004277::my_event.
```

When you close an event, you must supply the name of the event, and the time at
which it was opened. The CLI stores this information for you, in a local
state directory. For each event you open without specifying a close time (which
is implicit in an instantaneous event) a file is created whose name is a
concatenation of the time the event was opened, and its name. The content of the
file is the list of hosts to which the event relates.

The state directory behaves like a stack. So when we wish to close the event, we
can simply pop the last event off the stack.

```cmd
$ wavefront event close
```

And the event will be closed. You can also specify the name of the event, in
which case the last event with that name will be popped off the stack; or you
can go the whole hog and specify the time and name of the event to close. I've
tried to make things as simple as possible, whilst retaining flexibility.

Here's the chart now:

<img src='/i/wf_event_03.png' width='700' />

If you wish, you can specify the start and end times of your event. Times can be
given in anything which [Ruby's strptime() method can
parse](http://ruby-doc.org/stdlib-2.3.1/libdoc/date/rdoc/DateTime.html#method-c-strptime).

```cmd
$ wavefront event create -s 17:55 -e 17:59 retrospective_event
```

<img src='/i/wf_event_04.png' width='700' />

If you don't like the idea of the local state directory, and you prefer to do
things yourself, you can use the `-n` flag to not create a state file, and `-V`
to see the JSON that Wavefront sends back. To close the event, you will have to
manually specify the `startTime` and the `name`.

```cmd
$ wavefront event create -Vn my_event
{
  "name": "my_event",
  "startTime": 1468344291878,
  "annotations": {
  },
  "hosts": [
    "shark"
  ],
  "isUserEvent": true,
  "table": "sysdef"
}
$ wavefront event close -V my_event 1468344291878
Closing event 'my_event'. [2016-07-12 18:24:51 +0100]
```

The `show` subcommand gives you a list of events which are open and have a
local state file.

```cmd
$ wavefront event create another_event
Event state recorded at /var/tmp/wavefront/events/rob/1468344428692::another_event.
$ wavefront event create yet_another_event
Event state recorded at /var/tmp/wavefront/events/rob/1468344434674::yet_another_event.
$ wavefront event show
1468344428692::another_event
1468344434674::yet_another_event
$ wavefront event close another_event
Closing event 'another_event'. [2016-07-12 18:27:08 +0100]
Removing state file /var/tmp/wavefront/events/rob/1468344428692::another_event.
$ wavefront event close yet_another_event
Closing event 'yet_another_event'. [2016-07-12 18:27:14 +0100]
Removing state file /var/tmp/wavefront/events/rob/1468344434674::yet_another_event.
$ wavefront event show
No open events.
```

If you wish to properly query events from the CLI, you should use the `events()` function as a timeseries.

```cmd
$ wavefront ts -f human -m --start=17:55 --end=18:10 'events()'
2016-07-12 17:55:00 -> 2016-07-12 17:59:00 (4m 0s)     retrospective_event    [shark]
2016-07-12 18:01:32 -> 2016-07-12 18:01:32 (inst)      instantaneous_event    [shark]
2016-07-12 18:03:24 -> 2016-07-12 18:04:02 (37s)       my_event               [shark]
```

It is possible to set the level of the event (`info`, `smoke`, `warn`, or
`severe`) with the `-l` option; to add a plain text description of the event
with `-d`, and to set the type of event with `-T`. You can use these tags in
`events()` timeseries queries.

```cmd
$ wavefront event create -s 18:25 -e 18:27 -l info -d 'normal thing' info_event
$ wavefront event create -s 18:30 -e 18:35 -l severe -d 'bad thing' bad_event
$ wavefront ts -f human -m --start=18:20 'events(severity=info)'
2016-07-12 18:25:00 -> 2016-07-12 18:27:00 (2m 0s) info info_event  [shark] normal thing
$ wavefront ts -f human -m --start=18:30 'events(severity=severe)'
2016-07-12 18:30:00 -> 2016-07-12 18:35:00 (5m 0s) severe bad_event [shark] bad thing
```

## Dynamically Wrapping Things with Events

Using the commands above, it becomes trivial to wrap something like a Puppet
run, or a deployment, in a Wavefront event. But what if you want to wrap a
system event? Or if you want to wrap some particular process that's part of a
batch job you can't change? This is also easy with a good tracing tool. I'm on
Solaris, so I have DTrace. I've had it for nearly ten years now.

Here's a simple example: I'm going to wrap any occurrence of the charmingly
named `big_job` process, in a Wavefront event. Then, I could run a nice `ts
events()` query, see how many `big_jobs` we've done today, and alert if it's too
many, or too few. Or if they took too long. Or whatever.

Here's a bit of D which will use the `wavefront` command to open an event when
`big_job` start, and close the event when it stops. The name of the event is the
program name and its pid, so we can cope with overlapping `big_job`s. If you
expected `big_job`s to be happening in multiple zones, you could run this once
from the global, and have the zone name be reported as well with DTrace's
inbuilt `zonename` variable.

```dtrace
#!/usr/sbin/dtrace -wqs

proc:::exec-success
/execname == $$1/
{
    system("wavefront event create %s-%d", execname, pid)
}

proc:::exit
/execname == $$1/
{
    system("wavefront event close %s-%d", execname, pid)
}
```

Normally DTrace will not let you perform what it calls a "destructive action".
That is, any operation which changes the state of the machine. `system()`,
changes the state, so we have to pass the `-w` option (waiver?) to assure DTrace
we know what we're doing and we won't blame it if the box gets hosed. The only
other thing in there that strays a little from the norm is the `$$1`: `$1` is,
just like in a shell script, the first argument to the D script. Sticking
another `$` in front of it casts it to a string, so the comparison works.

Run that script with the name of the program you want to watch for, and, almost
magically, any time it runs you'll see it as a Wavefront event.

```cmd
# ./event_wrapper.d big_job
Event state recorded at
/var/tmp/wavefront/events/rob/1468348848346::big_job-12485.
Closing event 'big_job-12485'. [2016-07-12 19:40:53 +0100]
Removing state file /var/tmp/wavefront/events/rob/1468348853507::big_job-12485
```

<img src='/i/wf_event_05.png' width='700' />

Of course, you do't have to use `proc::exec` type probes: you could fire off an
event on anything the system does.

## Deleting Events

For the sake of completeness, the CLI lets you delete events.

```cmd
$ wavefront event create -i -V expendable_event
{
  "name": "test_event",
  "startTime": 1476188322525,
  "endTime": 1476188322526,
  "annotations": {
  },
  "hosts": [
    "shark"
  ],
  "isUserEvent": true,
  "table": "sysdef"
}
$ wavefront event delete 1476188322525 expendable_event
Deleted event.
```

## Library

The `wavefront event` command is all built on top of [existing library
code](https://github.com/wavefrontHQ/ruby-client/blob/master/lib/wavefront/events.rb)
which you can `require` and use in your own Ruby programs.

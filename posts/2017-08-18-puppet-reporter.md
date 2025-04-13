---
title: "Writing a Wavefront Reporter for Puppet"
date: 2017-08-12
tags: [Wavefront, Ruby, Puppet]
layout: post
category: Wavefront
---

I've always found coding against Puppet to be somewhat clunky.

Puppet reporters go in the `lib/puppet/reports/` directory, and their name is
important.

Let's call ours `wavefront.rb`. That means we have to use `wavefront` as the
argument to the method which lets us register a report.

```ruby
require 'puppet'

Puppet::Reports.register_report(:wavefront) do
  def process
    Puppet.notice(metrics)
  end
end
```

The whole reporter has to live inside that block, and the only thing it needs is
that `process()` method. What you see above is pretty much the simplest Puppet
reporter you can write. The `metrics` variable is populated for us, and it's a
hash with the following keys, all of which are
[`Puppet::Util::Metric` objects](https://docs.puppet.com/puppet/4.8/format_report.html#puppetutilmetric),
and all of which must be accessed with a `String` index. No indifferent access
here.

- `resources`:
- `time`:
- `changes`
- `events`:

There are
[other useful variables](https://docs.puppet.com/puppet/4.8/format_report.html#puppettransactionreport)
exposed for us, but as we're writing to a system that only deals with metrics,
few of them are of interest to us.

Talking to Wavefront will be much easier if we use [the Wavefront SDK](an SDK).
Here, you might run into a problem. If you do all your configuration with
Puppet, including installing the SDK, then when the catalog is compiled, it
won't be installed, and the reporter won't work. Then you'll miss out on
first-run reports. Therefore it might be necessary to bake the SDK into your OS
image, or have it installed as part of your bootstrap process.

## Are We Wanted?

We may not always want to run a report. For instance, if you're developing in
Vagrant. Let's have a method which checks for the presence of
`/etc/puppet/report/wavefront/disable_report`. We could then bake that file into
our Vagrant box, or have Puppet drop it according to the value of the `virtual`
fact.

```ruby
require 'pathname'
SKIP_FILE = Pathname.new('/etc/puppet/report/wavefront/disable_report')
```

I do _everything_ filesystem-related with
[`Pathname`](https://ruby-doc.org/stdlib-2.3.0/libdoc/pathname/rdoc/Pathname.h).
It's so much nicer and grown-up than `File`.

Then at the top of `process()`,

```ruby
return if SKIP_FILE.exist?
```

## Who Ran Us?

In the past I've found it useful to know what triggered a Puppet run. That is,
was it a normal run, triggered by `cron`? Was it a bootstrap run? Was it run
manually? Let's write a method to tell us. We want to walk up the process tree,
finding the thing underneath `init`: that's almost certainly what we want.
Sounds like we need a recursive function. Now I'm not much of a programmer, and
I don't trust things like that, so I'm going to keep track of the depth of the
recursion, and raise an exception if it goes too deep.

```ruby
def launched_from(pid, depth = 0)
  raise 'UnknownAncestor' if depth > 8
  cmd, ppid = ps_cmd(pid)
  return cmd if ppid.to_i == INIT_PID
  launched_from(ppid, depth + 1)
end
```

Notice the call to `ps_cmd()`. This lets our reporter work on different
operating systems with different `ps(1)` commands. There are Ruby modules that
handle `ps`-type stuff, but I'm not sure we can trust them where we're going.
Here's `ps_cmd()`.

```ruby
def ps_cmd(pid)
  case RbConfig::CONFIG['arch']
  when /solaris|bsd/
    `ps -o comm,ppid -p #{pid}`
  when /linux/
    `ps -o cmd,ppid #{pid}`
  else
    raise 'UnknownOS'
  end.split("\n").last.split
end
```

Whether on Solaris, BSD, or Linux, it returns the command name and parent PID
for the given process.

Return to `launched_from()`, and you might well wonder why we check that the
parent PID is equal to `INIT_PID`. Surely, you may suppose, the PID of `init` is
always 1. It is. Except when it isn't. In a Solaris or SmartOS zone, it
definitely isn't. Okay, you say, then let's just walk to the top of the tree and
stop there. Can't. In a zone, init isn't even the top dog.

```cmd
$ uname -s
SunOS
$ zonename
4efe7943-b793-45e8-d783-e6af15613b75
$ pgrep -fl init
 7258 /sbin/init
$ ptree 7258 | sed '/7258/q'
7194  zsched
  7258  /sbin/init
```

In a zone, `zsched` is the boss, and as there's no PID namespacing in Solaris,
you've no idea what its, PID will be. So we need another method to work out the
top PID. We just run that once, at the start of the report, and put its value in
a constant, called `INIT_PID`. For completeness:

```ruby
def init_pid
  case RbConfig::CONFIG['arch']
  when /solaris/
    `ps -p 1 -o comm` =~ /init/ ? 1 : pgrep -f zsched`.strip.to_i`
  when /linux|bsd/
    1
  else
    raise 'UnknownArch'
  end
end
```

As it stands, `launched_from()` will give us a command name, likely with a full
path. That might be fine, but I preferred to run its output through another
method which produces something more relevant:

```ruby
def launcher
  prog = launched_from(Process.pid)

  case prog
  when %r{/sshd$}
    'interactive'
  when 'sshd:', '/usr/bin/python'
    'bootstrapper'
  else
    prog
  end
end
```

## What Tags do We Need?

We're going to let the user pick what tags they want through a Hiera value
called `wf_report_tags`. This must be an array.

I've had trouble accessing Hiera from a reporter.

I expected that Puppet would expose the caclulated Hiera state for the reporter
to access, but I couldn't find it. Moving on, I expected Puppet to expose the
options with which it was invoked, from which I could retrieve the path to
`hiera.yaml`. But everything related to internal state seems to be a private
interface.

So, I ended up deciding to scan through likely directories until I found what I
wanted. Not very proper I know.

```ruby
require 'hiera'
require 'facter'

HIERA = Hiera.new(config: lambda {
          %w(/etc/puppetlabs/puppet /etc/puppet /opt/puppet).each do |d|
            p = Pathname.new(d) + 'hiera.yaml'
            return p.to_s if p.exist?
          end }.call)

SCOPE = { '::environment' => Facter[:environment].value) }
TAGS  = HIERA.lookup('wf_report_tags', %w(run_by status), SCOPE)
```

The `to_s` in the lambda is necessary because `Hiera` constructor can't deal
with pathnames if they're `Pathname`s. They must be `String`s.

With the Hiera config loaded, we can do a `lookup`. To do this we must provide
sufficient "scope" for Hiera to home in on the value we want. I assume that
simply knowing the envionment will be enough to do that. It is in my world. If
it is not in yours, and you have to be more specific, then you must modify the
`SCOPE`. The second argument in the `lookup` call is a default value which will
be returned if said lookup fails.

## Where is Wavefront?

Assuming (there's that word again) that the user has a Hiera variable called
`wavefront_proxy` we can recycle all the work we did getting the tags, and just
do

```ruby
PROXY = HIERA.lookup('wavefront_proxy', 'wavefront', SCOPE)
```

Now we can use the SDK to make a connection to Wavefront.

```ruby
@wf = Wavefront::Write.new(proxy: PROXY, tags: setup_tags)
```

By passing our tags in to the constructor, the SDK will ensure all points
written using the `@wf` handle will be tagged the same.

## Do it!

The
[Wavefront::Write class](https://github.com/snltd/wavefront-sdk/blob/master/lib/wavefront-sdk/write.rb#L70-L88)
expects to receive an array of points, where each point is a hash having keys
`path`, `value`. You can also specify a source, timestamp, and tags. We don't
need to tag: that was taken care of when we instantiated the class; we don't
need to specify a source: the local hostname will be used by default; but we
want all points to get the same timestamp, so we will specify that.

[Knowing the format of the `metrics`
object](https://docs.puppet.com/puppet/3.7/format_report.html#puppetutilmetric)
it becomes pretty simple to convert all those metrics to points.

```ruby
def metrics_as_points
  ts = Time.now.to_i

  metrics.each_with_object([]) do |(category, cat_values), aggr|
    cat_values.values.each do |v|
      aggr.<< ({ path: [category, v[0]].join('.'), value: v[2], ts: ts })
    end
  end
end
```

For example, the `cron` value in the `time` category because `time.cron`. Now we
can send that lot to Wavefront. Our `process()` method is as simple as:

```ruby
def process
  Wavefront::Write.new({ proxy: ENDPOINT, port: 2878 },
                       tags:  setup_tags).write(metrics_as_points)
  update_run_number
end
```

And that's a reporter.

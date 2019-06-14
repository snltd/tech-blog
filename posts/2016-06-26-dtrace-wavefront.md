---
title: "Wavefront and Solaris 03: DTrace"
date: 2016-06-26
tags: [Solaris, Wavefront, DTrace]
layout: post
category: Wavefront
---

[Gathering kstats](/post/2016-04-19-diamond-solaris) provided us
with excellent introspection onto a Solaris system, but I think
there's a lot more fun and enlightenment to be had if we can come up
with a way to wire [DTrace](http://dtrace.org/blogs/about/) up to
[Wavefront](http://www.wavefront.com/).

## Getting Numbers out of DTrace

Let's start with something very simple, and use one of Brendan
Gregg's famous [DTrace
one-liners](http://www.brendangregg.com/DTrace/dtrace_oneliners.txt).
Run this, wait a few seconds, and ctrl-c it.

```cmd
# dtrace -n 'sdt:::interrupt-start { @num[cpu] = count(); }'
dtrace: description 'sdt:::interrupt-start ' matched 1 probe
^C

        7              776
        5              882
        1             1038
        4             1061
        6             1126
        3             1220
        0             1754
        2             2338
```

It counts the number of interrupts on each CPU, but it does that
silently until you abort the script, then dumps the whole lot on you
in one go. This is not much use for generating a steady flow of
metrics. If We use DTrace's `tick` mechanism, though, we can output
something every second, regular as clockwork. Pop this into a script
called `intr.d`:

```dtrace
#!/usr/sbin/dtrace -s

sdt:::interrupt-start
{ @num[cpu] = count(); }

profile:::tick-1sec
{ printa(@num); }
```

make it executable, and run it:

```cmd
# ./intr.d
dtrace: script './intr.d' matched 2 probes
 CPU     ID                    FUNCTION:NAME
   6  93396                       :tick-1sec
        2               91
        7              139
        3              183
        6              183
        4              188
        5              209
        1              287
        0              378

   6  93396                       :tick-1sec
        7              345
        3              372
        4              384
        5              449
        6              456
        1              602
        0              746
        2              820

   6  93396                       :tick-1sec
        7              452
        3              516
        4              615
        5              662
        6              689
        1              795
        2              949
        0              962
```

Much more useful. Notice, though, that the numbers only go up:
they're counters, and we'll have to deal with that later.

## Getting Numbers into Wavefront

We need a bit of something that can turn that DTrace output into
Wavefront wire format, and send it to a proxy.  We also need to make
the output of the D script be input for that thing. The obvious way
to do this is to join stdout of `dtrace` to stdin of the processor
with a Unix pipe. But I think it's more interesting to use a named
pipe. Let's treat ourselves. We don't get to use named pipes very
often. I haven't used one in years.

Metrics need a path. If we use the name of the pipe to tell the
processing script what metric path to use, that script becomes
reasonably general-purpose.  It script could theoretically service
any number of DTrace scripts, provided they output in that same
two-column format. So, to make the output of `intr.d` go to
Wavefront with metric paths `intr.cpu.0`, `intr.cpu.1` and so-on,
begin with:

```cmd
# mkfifo -m 666 /tmp/intr.cpu
# ./intr.d >/tmp/intr.cpu
```

and in another window, run the processor script, which I'll show you
in a minute.

```cmd
# ./dtrace2wf intr.cpu
```

Wait a couple of minutes for a meaningful amount of data to go
through, and...

![CPU interrupts](/i/wf_cpu_intr.png)

If you squint, you might see that I wrapped the time series in
Wavefront's `deriv()` function, turning my simple counter into a
more useful gauge. The big hump in the middle was a 10-way parallel
build of Apache, just to show stuff changing.

Below is the Ruby processor script which did all the work. It's also
[in
Github](https://github.com/snltd/solaris-wavefront/blob/master/dtrace2wf.rb)
where it will probably be updated, and drift away from what you see
here.

```ruby
#!/usr/bin/env ruby

#=======================================================================
#
# dtrace2wf.rb
# ------------
#
# Pull DTrace aggragated data out of a FIFO and turn it into basic
# Wavefront metrics. I chose to use a FIFO rather than STDIN as it
# gives a nice separation between privileged collector and
# unpriviliged aggretator/forwarder. The coupling can even be
# across zones with a correctly shared filesystems for the named
# pipe.
#
# As it stands, this script only understands simple two-column
# DTrace output, where the left column is an aggregation bucket
# whose name will become the final segment of the metric path, and
# the right column is the value which will be sent.
#
# Requires a readable FIFO. Create a fifo whose name is the first
# part of the metric path you desire, and direct your D script's
# output to it. For example:
#
#   $ mkfifo -m 666 /tmp/interrupts.cpu
#   $ ./cpu_latency.d >/tmp/interrupts.cpu
#
# then run this script with the path to the FIFO as the only
# argument.
#
# CAVEATS
# This is only really a proof-of-concept, illustrative program.  If
# this script dies, DTrace will exit. If this matters (!), put both
# under SMF control, with this service dependent on the D script.
#
# R Fisher 06/2016
#
#=======================================================================

require 'pathname'
require 'socket'

# If you want, you can bundle up metrics before sending them. This
# lets you do intervals which DTrace's tick() doesn't support.
#
CHUNKS_PER_SEND  = 1
POLL_INTERVAL    = 0.1
HOSTNAME         = Socket.gethostname
METRICS_ENDPOINT = 'wavefront.localnet'
METRICS_PORT     = 2878
LINE_FORMAT      = %r{^(\d+)\s+(\d+)$}

#-----------------------------------------------------------------------
# METHODS

def flush_metrics(data, prefix)
  #
  # Send data in Wavefront format over a socket.
  #
  timestamp = Time.now.to_i

  begin
    s = TCPSocket.open(METRICS_ENDPOINT, METRICS_PORT)
  rescue
    abort "ERROR: cannot open socket to #{METRICS_ENDPOINT}."
  end

  begin
    data.each do |bucket, value|
      s.puts "#{prefix}.#{bucket} #{value} #{timestamp} source=#{HOSTNAME}"
    end
  rescue
    puts 'WARNING: could not sent metrics.'
  end

  s.close
end

def process_buffer(buffer)
  #
  # What do you want to do here?  You could do all kind of StatsD
  # percentile/max/min stuff if you wished. I'll work out the
  # sums for every bucket over the interval. Turning those into a
  # mean would be trivial.
  #
  # Returns a hash of the form {bucket: sum}
  #
  buffer.each_with_object(Hash.new(0)) do |row, aggr|
    row.each { |bucket, count| aggr[bucket] += count.to_i }
  end
end

def process_raw_buf(raw_buf)
  #
  # Pulls together into one object all the separate lines of DTrace
  # output from a single tick. Ignores lines it can't understand.
  #
  # Returns an array of [bucket, count] arrays
  #
  raw_buf.each_with_object([]) do |line, aggr|
    begin
      aggr.<< line.match(LINE_FORMAT).captures
    rescue
      puts "WARNING: could not process #{line}"
    end
  end
end

#-----------------------------------------------------------------------
# SCRIPT STARTS HERE
#
abort 'Please supply a path to a FIFO' unless ARGV.size == 1

# The name of the fifo is the first part of the metric path
#
FIFO = Pathname.new(ARGV.first)

unless FIFO.exist? && FIFO.readable? && FIFO.pipe?
  abort "ERROR: can't read FIFO '#{FIFO}'."
end

buffer, raw_buf = [], []

# This loop uses two buffers. 'raw_buf' collects together all the
# lines of a DTrace aggregation. 'buffer' collects bucket->count
# pairs until it has enough to send to Wavefront. Once you read a
# FIFO, it's empty, so it is safe to read faster than the D script
# writes.

loop do
  File.open(FIFO, 'r+') do |stream|
    loop do
      line = stream.gets

      if line.match(/^\s+\d+\s+\d+$/)
        raw_buf.<< line.strip
      elsif raw_buf.length > 0
        buffer.<< process_raw_buf(raw_buf)
        raw_buf = []

        if buffer.length == CHUNKS_PER_SEND
          flush_metrics(process_buffer(buffer), FIFO.basename)
          buffer = []
        end

      end
    end
  end

  sleep POLL_INTERVAL
end
```

## Getting More out of Everything

This is all pretty simple stuff. The next step is to make
`dtrace2wf` more flexible on the type of inputs it can understand.
It might even be nice to integrate its functionality into [the
Wavefront CLI](https://github.com/wavefrontHQ/ruby-client). That may
be seem minority-interest for a general-purpose tool, but
you could just as easily read the output of one of the Linux tracing
tools. One could also write a Diamond collector with similar
functionality.

Back in my darkest days, maintaining a Graphite "cluster", (I use
quotes because Graphite clusters don't really scale and aren't
really resilient, the two factors which I think define clustering)
perhaps my biggest problem was developers adding new metrics, or
slightly changing metric paths, and hundreds of new whisper files
appearing, promptly filling the disks. Again. Graphite likes to be
set up and left alone: it doesn't deal well with change. Wavefront
is different: spinning up a quick DTrace script and shoving its
output into the proxy with one-second resolution and a unique metric
path is effectively free, so methods like that shown above become
useful.

Also, point tags let you create meaningful graphs of constantly
changing data. For instance, say you want to see the top 10 on-CPU
processes on the box: you could write a D script to do this, and
have a connector capable of generating "two-dimensional" Wavefront
data: that is, time spent on-CPU as the value, and process name as a
point tags. (I would hesitate to use PID: the high cardinality could
make queries very slow.) This would make for a nice point-plot
chart, handling as many transient processes as need be from a single
root metric path.

I think there is huge mileage in graphing the output from DTrace.
(And other tracing tools.) The art of good DTracing is knowing where
to look, and I think Wavefront's simple near-real-time
visualizations will make it easier to know when you are on the right
track. And, to set up a Wavefront alert for next time the same
problem starts to happen.

This is possible because the very low overhead of correctly written
DTrace scripts makes it perfectly viable to have a bunch of them
constantly running, streaming data into Wavefront all the time: data
that can't be got from kstats, or straight from a properly
instrumented application. To that end, it probably makes sense to
have `dtrace2wf` (or its successor) be capable of multiplexing
various input streams.

There's lots of fun to be had.

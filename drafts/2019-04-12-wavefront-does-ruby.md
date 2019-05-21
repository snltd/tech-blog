---
title: "Wavefront Does Ruby"
date: "2019-04-12"
tags: [Wavefront, Ruby]
layout: post
category: programming
---

Regular readers (ha!) may know that I have written [a Ruby SDK for
Wavefront](), and built [a CLI tool] atop it. A little while I added
metric support to that SDK, but now Wavefront themselves have
released an official SDK which offers a far more comprehensive
method of sending data than mine does.

At the moment it's only [in
Github](https://github.com/wavefrontHQ/wavefront-sdk-ruby), so you
have to build the gem yourself.

```cmd
$ gem build wavefront-client.gemspec
  Successfully built RubyGem
  Name: wavefront-client
  Version: 0.1.0
  File: wavefront-client-0.1.0.gem
$ gem install ./wavefront-client-0.1.0.gem
Successfully installed wavefront-client-0.1.0
1 gem installed
```

I'm going to use it to make a bit of Rack middleware, to count
accesses to pages of this very site.

The SDK lets you send points via a proxy or straight to Wavefront
over the `report` API. I have proxies in my dev environment, but my
live stuff uses direct ingestion, so let's check that out first.
I'm becoming a terrible Clojure bore, which means I go on constantly
about the REPL now. So let's REPL.

```irb
irb(main):001:0> require 'wavefront/client/direct'
=> true
irb(main):002:0> ENDPOINT = 'https://virunga.wavefront.com'
=> "https://virunga.wavefront.com"
irb(main):003:0> TOKEN = '12345679-abcd-1234-abcd-123456789abc'
=> "12345679-abcd-1234-abcd-123456789abc"
irb(main):004:0> wf = Wavefront::WavefrontDirectIngestionClient.new(ENDPOINT, TOKEN);0
=> 0
irb(main):005:0> wf.send_metric('test.sdk', 9, nil, 'irb', example: 1)
=> #<Thread::SizedQueue:0x00005648f7a697d0>
```

Note that we've been returned a
[`SizedQueue`](https://ruby-doc.org/core-2.5.0/SizedQueue.html)
object. The point has gone on a queue from where it will, be
flushed at some point in the next five seconds.

The third argument to `#send_metric` is a timestamp. We sent `nil`.
What happens if we send a whole bunch of points with the same
timestamp?

```irb
irb(main):006:0> NOW = Time.now.to_i
=> 1555081169
irb(main):007:0> 1.upto(10) { |i| wf.send_metric('test.sdk', i, NOW, 'irb', example: 2) }
=> 1
irb(main):008:0> wf.flush_now
=> []
```

As you can see, you can force a flush if you can't bear to wait for
up to five seconds. Let's see what we got.

```cmd
$ wf query -kP beta 'ts(test.sdk)'
name          ts(test.sdk)
query         ts(test.sdk)
timeseries
  label       test.sdk
  host        irb
  tags
    example   2
  data        2019-04-12   15:59:00    10.0
              ------------------------------------------------------------------
  label       test.sdk
  host        irb
  tags
    example   1
  data        2019-04-12   15:55:00    1.0
events        <none>
```

We just got the final point, which is what you'd expect given
Wavefront has a one-second resolution.



Setting up a client just means requiring the right file and creating
an object with an endpoint and token.

```ruby
@wf = Wavefront::WavefrontDirectIngestionClient.new(
    'virunga.wavefront.com', '12345678-abcd-1234-abcd-123456789abc')
```

Obviously, this site gets *massive* traffic. Way above one page read
per second. (As I said, earlier "ha!"), so simply sending a point
every time we get a page read is no good. Fortunately Wavefront have
given us an `AtomicInteger`.




---
title: "CI/CD into Wavefront"
date: "2018-08-27"
tags: [Ruby, CI, CD, Travis, Gitlab, Wavefront]
layout: post
category: Wavefront
---

Wavefront has [over a hundred and fifty
integrations](https://www.wavefront.com/integrations/) and counting.
But it doesn't, at the time I write this, have one for
[Travis-CI](http://travis-ci.org/) or
[Gitlab](https://gitlab.com/), both of which I use every day.

I get notices in Slack from both services if a build fails, and both
keep records of the builds they've done, but I thought it would be
nice to have some build and deployment telemetry in Wavefront.
That's not been possible in the past, but now we have [direct
ingestion](https://docs.wavefront.com/direct_ingestion.html) it's
pretty easy.

Most of my projects are written in Ruby, so they test, build, and
deploy through jobs in a `Rakefile`. (In fact, I like `Rakefiles` so
much I use them for some things that *aren't* written in Ruby.)

You can probably trace the `Rakefile`s on most of my my existing
projects back to the first "decent" one I made. Why write a new one
when you can modify an old one? And they tend to call the Ruby
`abort` function with a (hopefully) helpful error message when
things go wrong. So, a fairly obvious point

As an initial stab, let's just tell Wavefront we did a test, and
what happened. If you use Gitlab, you might want to do this in the
final stage of your pipeline, but I don't really use that: I still
have the single `Rakefile` that does everything. It works for me,
and it works on Travis, or on my laptop, with no changes.

This is Ruby, so we'll talk to Wavefront via [the Ruby
SDK](https://github.com/snltd/wavefront-sdk]. The SDK has [a
credentials class]() which, if it sees environment variables called
`WAVEFRONT_ENDPOINT` and `WAVEFRONT_TOKEN`, will use them to create
a credendials object all the other classes can consume. So, I made
sure I exposed these in my CI pipeline. That means using [encrypted
variables](https://docs.travis-ci.com/user/environment-variables/#defining-encrypted-variables-in-travisyml) in Travis, and
[secret
variables](https://docs.gitlab.com/ee/ci/variables/#variables) in
Gitlab.

```ruby
require 'wavefront-sdk/credentials'
creds = Wavefront::Credentials.new
```

We can use that `creds` object to make a new instance of the
[Report](https://www.rubydoc.info/gems/wavefront-sdk/Wavefront/Report)
class.

```ruby
require 'wavefront-sdk/report'
wf = Wavefront::Report.new(creds)
```

I decided to time the various steps of the pipeline. This meant
wrapping all my Rake tasks in a little timer. There are a million
ways of doing time wrong. Here's, hopefully, one less.  Ever since I
read [this
article](https://blog.dnsimple.com/2018/03/elapsed-time-with-ruby-the-right-way/)
I always extend Ruby's stdlib `Time` class with the following
method.

```ruby
class Time
  def self.right_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
```

for doin

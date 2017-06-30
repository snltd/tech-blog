---
title: "A New Wavefront SDK"
date: "2017-05-25"
tags: [Wavefront, Ruby]
layout: post
category: Wavefront
---

Over the last year or so I made
[various](/post/2016-07-21-wavefront_writer)
[contributions](/post/2016-07-12-wavefront_events) to the [official
Wavefront Ruby
SDK and CLI])(https://github.com/wavefrontHQ/ruby-client). Now, I've
made another, which supports the far more powerful API version 2.


## The SDK

First, there's [an SDK](https://github.com/snltd/wavefront-sdk). I
chose (perhaps unwisely, we'll see) not to automatically generate
from the Swagger docs. I don't like working with SDKs where there's
just a method for each call. I want input validation, sensible
exceptions, helper methods that simplify common operations, and the
kind of interface that makes sense to a human being. I find that
machine-generated SDKs don't always provide these.

Every API path, such as `/alert`, or `dashboard`, has its own class,
in its own file, named for that path. Method names echo those of the
API calls.

All classes except `write` speak to Wavefront's API, so they need
credentials. Any method you call will return a `Wavefront::Response`
object, which has a `status` (a summary of how the request went) and
a `response` (the body of the request). You can see all the
responses in the Wavefront API's Swagger docs.

Here are a few simple examples.

```ruby
CREDS = { endpoint: 'company.wavefront.com',
          token:    'c7a1ff30-0dd8-fa60-e14d-f58f91bafc0e' }

# List the short names of all your proxies

require 'wavefront-sdk/proxy'

Wavefront::Proxy.new(CREDS).list.response.items.each do |p|
  puts p[:name]
end
```





# History, Whys and Wherefores

We've had excellent service from the original SDK and CLI, building
many things on top of it, bringing much telemetry where before there
was no telemetry. But, it wasn't without issues. Firstly, as the
work of a number of people at a number of companies, the coding
style of the SDK was rather inconsistent, and not every class
offered a similar interface. Extending the SDK became messier and
messier, and I was itching to rewrite it.  There were also things it
couldn't do. We never provided support for the user or maintenance
window APIs, and even where we covered everything, there were things
the API simply couldn't do, like delete an alert.

Then, Wavefront released version 2 of the API (whilst not breaking
version 1: certain other monitoring companies take note!). The v2
API is much more wide-ranging, much more consistent, and lets you do
pretty much anything you can think of. It was also sufficiently
different that adapting the old SDK to cover it was a non-starter.
So, I started again.

## Decisions, Decisions

This was my project, so I chose to use it as a chance to  do
everything as "right" as possible, and improve as a programmer. I
am, after all, just a stupid sys-admin at heart.

The first decision was to abandon all support for any version of
Ruby that's not current. So, anything before 2.2 can suck it. The
second decision was to decouple the API and the CLI. If you're
building a which only use the API, why do you want the CLI? So, two
repos.

Even though I hate the Git CLI with all my heart, you've got to keep
stuff in Github these days, so that's easy.

I'm a worrier. Well, kind of. I never worry about my own stuff, but
I do worry than any change I make to anything will have some bizarre
knock-on effect and break something for someone else. So obviously,
I need tests. I have always preferred
[Minitest](https://github.com/seattlerb/minitest) to RSpec, so I
chose that. As soon as I had a `Rakefile` with a working `test`
target, I set up an integration with
[Travis](https://travis-ci.org/), so every commit will do a build,
which means every commit will run all my tests. CircleCI looks very
interesting, and I plan to try that in the future, but I chose
Travis because it makes it trivial to run parallel builds on
multiple Ruby versions)

I also wanted to code as cleanly and "properly" as possible, which
meant lots of [Rubocop](https://github.com/bbatsov/rubocop). As part
of the continuous integration cycle, I hooked
[CodeClimate](https://codeclimate.com/)  up to my Github repo, and
it draws my attention to any sloppy coding. I also wired the repo up
to [Snyk](https://snyk.io). This automatically checks all your
code's dependencies, alerting you to any known vulnerabilities.

I'm not much of a test writer. I struggle badly with mocks, doubles,
stubs and all of that. I found it particularly hard to work out how
my methods were making the correct API calls, until I found
[WebMock](https://github.com/bblimke/webmock). This lets you define
an HTTP request you expect to see, and it hooks itself into the
standard library at a point where it intercepts any calls and
compares them to the one you defined. I also found
[Spy](https://github.com/ryanong/spy) made it easy for me to ensure
methods were being called correctly. (At that point I slightly
regretted not using RSpec, which also makes that quite simple.)

The old SDK was built on a version of `rest-client` which Snyk
didn't like. The reason for that was primarily to ensure Ruby 1.9
compatability (not an issue in this project) but we pinned to a
*particularly* old version, because newer ones had a dependency
chain which ended in
[unf_ext](https://rubygems.org/gems/unf_ext), which is a
native-extensions job. I don't have a C compiler on my production
boxes, and neither should you. So anything with a native dependency
anywhere in its chain is off my list.

After looking at a number of alternatives, I chose
[Faraday](https://rubygems.org/gems/faraday). It seemed complete,
active, and simple to use. Swapping from rest-client was easy:
change the one method which actually makes API calls, and re-run the
tests. Since WebMock only looks at the *request* that's made, and
doesn't care what's making it, I knew nothing had broken. And Snyk
was happy too.


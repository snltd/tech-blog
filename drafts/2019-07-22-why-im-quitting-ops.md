---
title: "Why I'm Quitting Ops"
date: "2019-07-22"
tags: [Rant]
layout: post
category: rant
---

Four years ago I [wrote a piece](/post/2015-05-05-why-i-hate-devops)
about why I was falling out of love with operations work. I've lived
in a loveless relationship too long, and just got myself my first
"proper" dev job since the late '90s.

There are, of course, still "proper" ops jobs. There are still
"proper" sysadmins maintaining "proper" software running on
"proper" Unix, on "proper" computers in a "proper" machine room.
But that's a world I already escaped from, and have little desire to
revisit. The only places with that kind of setup are the
places where the procurement team buy the server, the DC team put it
in a rack, the cabling team wire it up, the network team plug in the
RJ45s, the SAN team plug in the Infiniband, the OS team put Unix on
it, the security team harden it, and the application team install
Websphere. Forget that.


# 1. AWS

Most of the rest of us, it seems, are using AWS. And my attitude to
AWS has gone from "wow" to "cool" to "OK" to "meh" to "boring" to
zero.

Being a dev on AWS is, I'm sure, a liberating experience. After
decades of being beholden to The Ops Guy, standing up whatever you
need, whenever you need it, is a revolution. Being the The Ops Guy
on AWS is, to This Ops Guy, soul-destroying.

I know I overthink everything. I'll try to explain.

All AWS work boils down to futzing about with some amount of JSON
until the thing works, after which you leave it for ever. Said JSON
may be IAM rules, Cloudformation, bucket policy, or plain old
configuration, but as an AWS Ops Guy you're nothing more than a JSON
wrangler.  They may try to glorify it by calling it "code", but it's
not. It's JSON (or YAML) with some awful logic and interpolation
syntax shoehorned into it.

This is fine. There are far, far worse ways to make a living. But
there is no *skill* in this work. It's hitting on the right happy
combination. Wondering for two hours why something doesn't work,
waiting for the stack to roll back, pondering an uninformative error
message, until finally you realise that there needs to be an
exclamation mark on the end of the keyword because... well, because
there just does.

That's the second point. Everything is arbitrary. As a programmer,
or even as a Unix engineer, you work in complex system built from
some amount of rules. With experience you absorb these rules, and
are able to produce better, more efficient systems. The scope is
infinite. You learn and grow. You can know a tiny subset of Python,
and still be able to write a program -- albeit a crude one -- to do
pretty much anything. But in AWS, however smart you are, however
experienced you are, there is no way on earth you're *ever* getting
that service to come up until you read the line of the documentation
that says you need to have `"ignoreInverseKeywordFalsehoods": 1` in
your Cloudformation.

And why *would* you know that?  You may know everything there is to
know about Amazon Fishcake. But when they launch Amazon Crabstick,
you're starting from zero. Unlike Fishcake, Crabstick doesn't use
`ignoreInverseKeywordFalsehoods`, it uses
`acceptPositiveTruthsInKeywords`, and values of that must be
single-element arrays of booleans. Because.

I'm very old-fashioned in that I value knowledge. I resent
single-use knowledge as much as single-use plastic. Techniques
learnt in Clojure may make you a better Ruby programmer. Nothing
learnt in AWS Fishcake will buy you anything anywhere else.
Everything is a ghetto.

When you're writing code, or working at OS level. and something
doesn't work, it's because you haven't worked out how to do it.
Someone might help you, or you might eventually crack it yourself,
but either way you've improved.  But in the AWS world, if something
doesn't work, it's probably because it isn't implemented, and that's
the end of that. Again, it's all arbitrary.

When a new service comes out, most people applaud. Amazon have just
solved a problem for them. I feel Amazon have just made redundant
something I took pride in knowing.


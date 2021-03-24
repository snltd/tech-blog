---
title: "Everything Let Me Down (Or, How I Messed Up a Simple Task)"
date: 2020-02-28
tags: [Ruby, programming]
layout: post
category: programming
---

I wrote some code for [a site about music](http://cassingle.id264.net). At the
top of each page, it has a mouseover which tells you what equipment was used
to play the records discussed below. It does this by way of a hash which
details all the gear that's ever been in the hi-fi, and when it came and went.
When rendering a post it filters the hash according to the date the post was
written, and returns the correct system. It then further filters depending on
whether the reviewer listened through headphones or speakers.

It didn't work.

Visiting the site showed the source and amplification, but not the
transducers. No speakers, no headphones. I fired up a local instance.

It worked fine.

Until it didn't.

If you started off viewing a "listening through speakers" page, you got the
speakers, until you viewed a "listening through headphones" page, at which
point the speakers disappeared and were not replaced by headphones. And
vice-versa.

I had unit tests to check each transducer type, and they were passing.

Looking at the code, I found the transducer filtering was done with Ruby's
`#delete_if` method. Now, `delete_if` should probably be called `delete_if!`,
because it modifies the object on which it operates. So when I took out the
headphones or speakers, they were gone from the hi-fi hash *for ever*. I
replaced `delete_if` with `reject`, and everything was as it should be.

It's a stupid, elementary mistake, but I think it raises a couple of
interesting points.

## 1. The New Toy

Why did I use `delete_if`? When I looked at the code, I barely recognized it,
and a quick `grep -r` through my work directory shows I've never used it
anywhere else. I remember, around the time I wrote this code, prepping for an
interview, and reading through the reference part of the pickaxe book. There
were a whole bunch of `Enumerable` methods I didn't know, and I probably used
it because I'd just learnt about it, without understanding *exactly* what it
did.

We do this a lot.  We get a new toy, be it as complex as Kubernetes or as
simple as `delete_if`, and we throw it at the first vaguely related problem we
see. And we're probably wrong, and we'll probably regret it.

## 2. Trusting Your Tests

When I came to fix the bug, I immediately looked at the tests. The code had
a build pipeline, and there were unit tests for class which creates the hi-fi
list, and an acceptance test which looked at the rendered HTML. They passed,
and they passed because every test set up a nice fresh environment in which to
run.

The headphones test ran on a brand-new hi-fi object. The speakers test ran on
a brand new `HiFi` object, so the effects of permanently deleting the other
type of transducer were never seen. The acceptance test ran on a randomly
generated page, not on a page which had been through the change in state. This
is (broadly) the way we're told to write tests: ordering is bad, and
idempotency is king. If I'd had lousy order-dependent, resource-recycling
tests, they'd have caught this problem before the first release. (Though,
of course, they'd have caused lots of other problems.)

A code review would have caught this. Someone would have said "why are you
using `#delete_if`, and I'd have said "... I... don't... know...", and changed
it to `reject`. That person might also have pointed out exactly what
`delete_if` does, and I'd have learnt the easy way instead of the hard.

## 3. Changing Stuff

I wrote this code a couple of years ago, before I started using Clojure and
Rust, and had the penny-drop moment about immutability. Now, even when I write
Ruby, I try to think functionally, and do whatever is reasonable to avoid
mutating *anything*.

If you *can't* change existing objects, you *can* trust those beautifully
distinct, idempotent tests. You also don't have to worry about locking and
synchronization and all that awful stuff.

## 4. Those Damn Expressive Languages

Some people would blame Ruby for giving me the scope to make a mistake like
this.  'Why does `Enumerable` need so much "syntactic sugar"? You wouldn't
make this mistake in Go.'

True, but I'd much rather, whether writing or reading code, have all those
`Enumerable` methods compacting and explaining than only a `for` loop, and
everything in longhand.

I'd rather have the rope, even if I did accidentally wrap it round my neck
this time.

## Lesson Learnt

Though I'd like to say "I wouldn't make this mistake now", I wouldn't have
made it then if I'd bothered to look up exactly how `delete_if` works.  That's
the best lesson: on any scale, dev or ops, don't use something without fully
understanding it.  Don't use something "because it does this" if you don't
know enough to grasp that "it also does that".

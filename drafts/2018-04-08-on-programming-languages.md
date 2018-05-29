---
title: "On Programming Languages"
date: "2018-02-26"
tags: [Ruby, Go, Clojure, Python, C, Shell]
layout: post
category: Rant
---

This is the second in an open-ended series of articles I am filing
under "professional suicide".

When people ask me what I do for a living, I say "I'm a computer
programmer".  This is good because it is broad enough to satisfy
people outside the industry who do not know or care what "SRE" might
be, and vague enough to brickbat a technical person who may wish to
talk to me about work. If we have just met, I do not want to talk to
you about work, and hear about your build pipeline or your
Peoplesoft rollout. I would rather talk to you about whatever it is
that you *like* to do. Books, or painting, or cricket or cooking or
something *human*. Or not talk at all.

But the truth is that I'm not really a computer programmer. Not much
of one anyway. I didn't do a CS degree, I don't use Sublime, I can't
quote algorithms and I don't feel I can weigh in on the technical
merits of a language because five years ago I did a ten week module
on compilers.

This article, like all my articles, is written with the hope it will
clarify my thoughts. That writing, editing, and re-reading will
prove to me whether or not I understand something. Usually that's
some aspect of some program, but in this case it's more
philosophical. I probably won't publish this. (Though it looks like
I have, right?)

The reason I need to clarify my thoughts is because I'm confused
about Go. I'm confused about Go because I am apparently the only
person in the world who does not like it.

We work in an extraordinarily opinionated industry. Everyone seems
to think they know best yet, paradoxically, they all do what (they
think) everyone else is doing.

I, of course, have my favourites, my heroes and my villains. But I
at least *try* be open minded and rational. Hence my need to
understand what it is about Go that turns me off so badly.

I was very excited to learn Go. I liked the idea of fast, concurrent
code that compiled down to a single binary. Who wouldn't like that,
after years of trying to ship rats' nests of Ruby dependencies. (And
`Thread.new`...)

I started working through [Go by
Example](https://gobyexample.com/hello-world), and found it pretty
boring. I'm old, and I like a book. I like to sit on my settee at
night, with a big mug of tea, and read until my brain is full. Then
I digest what I've read and go back over it with the book open, at
the computer. That works for me. Naturally I bought *The Go
Programming Language*. It's obvious, right? It's co-written by Brian
Kernighan, it's solid 5-star ratings everywhere you look, it's
official, and it's AS BORING AS HELL. I also found it elitist. The
example code could have done anything, and the choice to, from
chapter one, have it render mathematical forms I've never heard of,
put me on the back foot. I immediately thought "this isn't supposed
to be for me. They don't want me in their club".

On page 43 they're showing me how to convert Celcius to Fahrenheit.
(Again.) Then on page 62 I'm asked to use Newton's method to find
complex solutions to a function and shade an SVG wireframe based on
numbers of iterations or something. I don't know. I'm 45 and I don't
know what Newton's method is. I don't feel encouraged or enthused by
these exercises. I feel stupid, and it's not even because I can't
*do* the exercises, but because I can't even *understand* them.

Or how about Exercise 8.2.

> Implement a concurrent FTP server... You can use the standard
> `ftp` command as the client, or write your own.

Yeah, I could do that, couldn't I? I've nothing better to do. Why
stop at reinventing the client? Maybe I could write an entire
operating system for it to run on? One day it might take over the
world, just like Plan 9!

They're worded so flippantly too. Like they're taking the piss,
setting students busy-work exercises so they can knock off early and
go down the pub. Anyone can do that.

> **Exercise x.y:** Microsoft Office is a productivity suite aimed
> at large enterprises. Implement it.

The book -- particularly the exercises -- indelibly coloured my view
of the language.  Perhaps it unleashed a hitherto unnoticed angry
inadequacy at my lack of education, (I admit I have an axe to grind
with formal education) but I saw it as elitist, long-winded, full of
boilerplate, and the more I read (from various sources) the more I
felt myself setting against it.

The Go community felt, and feels, like a club whose entry
requirements are a recent CS degree and a malleable mind. I tried to
find people like me, who had had eventual success with Go despite it
being antithetical to their mindset, but found little. It seemed
like a cult, with the overriding message that Go is AWESOME and if
you don't like it, then that's YOUR PROBLEM. Go is FUN, and one of
the most fun things about it is HOW PRODUCTIVE IT MAKES YOU.

The penny dropped when I read that Go was made so Google could
quickly get reliable, usable code out of recent graduates. Golang
is the programming equivalent of an open plan office. An academic
implementation of a time-and-motion study designed to maximise a
huge corporation's staffing ROI.

Google is built on automation, repetition, stamping out the same
image over the world. It's natural they'd see their people in the
same way. Start with the same people, with the same education, in
the same patterns and the same algorithms. Give them the same
language which enforces the same syntax and the same techniques, and
when one burns out at 26 from the 80 hour weeks, drop in another and
you won't see the join.

Give me the child and I will mould the man. And Go probably does
seem like fun when your programming experience up to that point has
mostly been implementing quicksort in Java.

I can look at Go's opinionated nature as a positive. As something to
free me from wasting time on the trivial stuff, and help me
concentrate on what I'm doing. If you see it like that, I won't
argue with you. But I find it equally easy to see it as something to
make me Just Like Everybody Else. And I don't want to be Just Like
Everybody Else. It fits with the way the big tech companies work,
with their catered breakfasts and laundry services and general
keenness to abstract away the rest of your life. Google Borg. Am I
the only one who gets the joke?

This, I think, is at the root of my coldness towards Go. The people
who love it, I think, come from what I'll call a *professional*
background. They have paid a lot of money and invested a lot of time
in a formal CS education. They are working hard in environments
where they are judged on their output. I respect that, and I greatly
admire (some of) their work

But I, like most 40+ people in the industry, didn't come in by that
route. We're often the hobbyists turned pro. We didn't worry about
finding a unicorn startup, or getting into Google, or about Github
stars, or even salaries. We didn't have to deal with five-stage
interviews. We generally drifted in through intellectual curiosity,
exposed to computers as part of some other job.

I am, emphatically, not 24 years old and working in a competetive
environment where my job is my life. I do not measure the worth of
my effort by how quickly it can be monetized by my employer, or
how good I think it makes me look in the eyes of my peers.  I am
old. I sit, and I think, and I observe. I may be getting paid to
reach a destination, but I value the journey.

What makes that journey fun for me is using an expressive language.
Whatever its failings, I *enjoy* Ruby.  What you may dismiss as
"syntactic sugar" I see as richness, and it still delights me when I
find a new little `proc` trick, or an `Enumerable` method I'd never
noticed before. I read about how it's better for everyone that code
be uniform in appearance, and that one loop type is better than
many, and that a certain degree of repetition is acceptable if it
makes things explicit, and I don't disagree, but I also *don't
care*. I like variety. I like seeing how other people use a language
(I got into Lisp and Clojure because of the way a former colleague
wrote Ruby.)

Would it better if there were only one type of food? It would be
easier to decide what to have for dinner wouldn't it? That's kind of
how I see Go. Today's menu: plain rice, 100g. Rob Pike's having
steak, but you're all having the rice: it's good for you. I suppose
I'm a contrarian. Being told how to do things -- how to think --
doesn't sit well with me, whatever the rewards.

Maybe that's it. I'm 45 years old. I've been doing this job more
than twenty years. I don't want Rob Pike telling me where I have to
put my braces and that I'm not allowed exceptions because I won't
use them properly. That said, I am, and always have been, a stickler
for Rubocop, `enable strict`, `pep8`, `-Wall` etc, and I initially
*liked* Go's approach to error handling. (After a while I got to a
point where I couldn't bear to type another `if err != nil` and
started thinking "fuck it, it'll probably be fine", making Go the
first language I've ever used where I am genuinely tempted to ignore
errors. Me. Mister But-What-If...? That's an achievement.)

I fully understand the benefits of Go's dictatorial approach, but I
don't feel they benefit *me*. They benefit the company I work for,
and I don't really care about that. I want to provide good service,
of course, but I'm more interested in my own professional and
intellectual fulfilment than in their bottom-line.

It's not that I'm some luddite who things the first language I
learnt should be good enough for anyone. Alongside dragging myself
through Go I found time to learn and get very enthusiastic about
Crystal, Clojure and D3 (okay, not a language, but similar in effort
to learn) and I'm now sniffing around the edges of Rust. (And this
in addition to writing Ruby, Python, and, alas, shell, in my normal
job.)

The older people I know, if they aren't thoroughly indoctrinated in
C, tend to prefer the more expressive languges, like Ruby, or Lisp.
Perhaps when you've been programming in excess of 25 years you're
drawn towards things that give you the chance to phrase things in
different ways. We do tend to end up solving the same problems over
and over.

I have similar feelings about Python. I first ran into that working
in a university, and the academics all loved it. Loved its
correctness, loved its explicitness and its one-way-of-doing-things
approach. And like Go, Python is a hypocrite. It lauds its
explicit, simple, obvious syntax, then says "oh, and here are
generators, dict comprehensions and decorators". Go says "static
typing is the only way" and "generics are wrong", and the fanboys
spread the gospel, then fill their code with empty interfaces.



Perhaps my prejudice stemmed from the fact that I do not like
Google. I do not like their business, or how they go about it. I
also do not like the way so much of the industry hangs on their
every word and slavishly imitates them. Perhaps it's because I find
Rob Pike the embodiment of their know-it-all pontification. Maybe
I'm just some old hippy at heart. I want to be left alone to write
Lisp on some dead Unix and document it in TeX.


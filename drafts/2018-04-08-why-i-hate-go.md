---
title: "Why I Hate Go"
date: 2018-02-26
tags: [Ruby, Go, Clojure, Python, C, Rust, "professional suicide"]
category: Rant
---

This is the second in [an open-ended series of articles I am filing
under "professional suicide"](/tag/professional suicide).  Like all
my posts and essays, it is written with the hope it will clarify my
thoughts.  I wish to do this because I am deeply confused about Go.
I'm confused because I am apparently
([almost](http://dtrace.org/blogs/wesolows/2014/12/29/golang-is-trash/))
the only person in the world who does not like it. And I don't like
it for a whole host of *really* stupid reasons.

Everything that follows is opinion. Rabid opinion. This article does
not contain a single fact.

My Go journey started with high hopes. I enjoy new languages, and
was very excited by the offer of fast, easily concurrent code that
compiled down to a single binary. Who wouldn't like that, after
years of trying to ship rats' nests of Ruby dependencies. (And
`Thread.new`...)

I started working through [Go by
Example](https://gobyexample.com/hello-world), and found it pretty
boring. I'm old, and I like a book. I like to sit on my settee at
night, with a big mug of tea, and read until my brain is full. Then
I digest what I've read and go back over it with the book open, at
the computer. That works for me. Naturally I bought *The Go
Programming Language*. It's obvious, right? It's co-written by Brian
Kernighan, it has solid 5-star ratings everywhere you look, it's
official, and -- it's AS BORING AS HELL.

A programming language book will, I suppose, reflect the language it
describes, so it was whilst reading the book that I began to feel
Go would also be BORING AS HELL.

But worse than boring, I found *The Go Programming Language* a snob.
The example code could have done anything, and the choice, from
chapter one, to have it render mathematical forms I've never heard
of, put me on the back foot. After a couple of chapters I had a
half-formed idea that Go wasn't supposed to be for me. That they
don't want me in their club.

For example, on page 43 they're showing me how to convert Celcius to
Fahrenheit.  (Again.) Then on page 62 I'm asked to use Newton's
method to find complex solutions to a function and shade an SVG
wireframe based on numbers of iterations. (Or something.) I've done
a physics degree and an engineering masters, but I don't know what
Newton's method is. I could learn it, but unfortunately I'm using
all my spare time learning Go. Consequently I don't feel encouraged
or enthused by these exercises. I feel stupid.  And not because I
can't *do* the exercises, but because I can't even *understand*
them. Way to nurture learning, people.

How about Exercise 8.2?

> Implement a concurrent FTP server... You can use the standard
> `ftp` command as the client, or write your own.

Yeah, I could do that, couldn't I? It's not like I have a job to do,
and a life to live, and people to see. Why stop at reinventing the
client? Maybe I could write an entire operating system for it to run
on. One day it might go on to be as wildly successful as Plan 9.

The whole book, and, I feel, the whole ethos on which the
programming language is built, is shot through with Google's
trademark ivory-tower arrogance. Exercises feel lazy, smug,
chuckling. The sort of crap you get from academics who think they're
too important to teach, and set the same vaguely worded,
unapproachable questions every year, then don't bother marking them.

> **Exercise x.y:** Microsoft Office is a productivity suite aimed
> at large enterprises. Implement it.

The online documentation is the same. In fairness, the API and core
language docs are thorough, but they're dry as hell, and riddled
with academic conceit. For example, the preamble to the `regexp`
module smugly suggests I look at "any book on automata theory".
Okay. And while I do that, regex module people, why don't you all go
f--- yourselves?

By this point I was using Go. I wrote a few toy programs, and I
wrote extensions to a couple of real ones. It worked fine, and I got
stuff doing what it needed to do, but I never got close to enjoying
it.  I felt like a sullen teenager being dragged round a National
Trust property by his parents.

I tried to find people like me, who had had eventual success with Go
despite it being antithetical to their mindset, but found little. It
seemed like a cult, with the overriding message that Go is AWESOME
and if you don't like it, then that's YOUR PROBLEM. Go is FUN, and
one of the most fun things about it is HOW PRODUCTIVE IT MAKES YOU.

Go is all about productivity, because it was designed so Google
could quickly get reliable, usable code out of recent graduates.
Golang is programming's answer to the open plan office.  An academic
implementation of a time-and-motion study designed to maximise a
huge corporation's staffing ROI. You can imagine Go in the same
C-level presentation as catered breakfasts and laundry services and
all the other devices to simplify and remove every part of your
workforce's life that doesn't generate revenue. Hell, they even call
Go programmers "gophers",  which when I worked in a factory, was
what they called the lowest dogsbodies. (Like me.) Coincidence?

Google is built on automation, repetition, stamping out the same
image over the world. It's natural they'd see their people in the
same way. Start with the same people, with the same education in the
same patterns and the same algorithms. Give them the same language
which enforces the same syntax and the same techniques, and whenever
the 80-hour weeks burn out another 24 year-old, drop in a new one
and you won't see the join.

Give me the child and I will mould the man.

The "fun" thing makes me laugh. Not only that Go the least fun
language I've ever used (and I've used MATLAB), but more the way
that almost every Go library and document goes out of its way to
reiterate WHAT FUN that library will be. I've never seen that in any
other language. It's like a cult.

But, perhaps Go does seem like fun when you work 90 hour weeks
and your programming experience up to that point has mostly been
implementing quicksort in Java.

Like many people in this industry the wrong side of forty, I came to
programming by a circuitous route.  Many of my age are hobbyists
turned pro. We didn't worry about finding a unicorn startup, or
getting into Google, or Github stars, or even salaries. We didn't
have to deal with five-stage interviews. We generally drifted in
through intellectual curiosity, exposed to computers as part of some
other job. We picked up some programming, some OS stuff, some
networking bits, and we enjoyed the latitude.

I am, emphatically, not 24 years old and working in a competetive
environment where my job is my life. I do not measure the worth of
my effort by how quickly it can be monetized by my employer, or how
good I think it makes me look in the eyes of my peers.  I am old. I
sit, and I think, and I observe. I may be getting paid to reach a
destination, but I value the journey. I am not going to go ahead and
come in on Sunday. You may not wish to employ someone with my
attitude, in which case I do not wish to work for you, so we're
both happy.

Clearly, most of the issues I have with Go are philosophical.  Maybe
it's Google. I dislike Google. I dislike their business model,
their disregard for privacy, their ever-creeping Ts&Cs,
their commodotization of human behaviour, Google Drive, the lot
really. And I snub my nose at the fawning follow-the-leader attitude
my industry has for anything Google do: Go, the SRE Book,
Kubernetes, etc. Go is the only Google product I still use, and
that's only because I have to.

If I may get more personal, I think Go is a hypocrite. Go says
"static typing is the only way" and "generics are wrong", and the
fanboys spread the gospel, but half the code I look at is stuffed
with reflection, lazy abuse of the empty interface and crazy amounts
of casting.

Go doesn't trust us with exceptions, so the fanboys tell us this is
great because exceptions are bad, then manually pass their errors
back up the stack like they're going to rot.

Go tells us not to use unreadable shorthand, or semicolons, then
makes crap like `if val, ok := fn(); ok {` idiomatic.  Don't do what
Donny Don't does.

Go is a small language. This supposedly makes it simple. I think
that depends on your definition of simple. Take looping. Go gives
you any kind of loop you want as long as it's `for`.

In, say Ruby or Clojure, I can look an operation on any collection
and immediately tell what's happening. I see `map`, or `select`, or
`any?`, and I probably don't need to read the block. obviously it's
changing what's there, winnowing out a subset, or checking something
exists.  But in Go, I've got to read the whole damn loop to know
that.  The way the loop *looks* tells me nothing, because they all
look the same. And there's not going to be a comment, because
'Commander' Pike sez comments are for idiots. (And that [syntax
highlighting is
childish](https://groups.google.com/forum/#!msg/golang-nuts/hJHCAaiL0so/kG3BHV6QFfIJ),
lest we forget.)

Every time I start typing `for _, thing := range...` I feel a little
bit more enthusiasm for programming slip away. Coding in Go feels
riddled with repetition and boilerplate, and never more so than when
testing for errors. Or, as Go calls it, calling any function, on any
data, ever.

I've never been the biggest fan of exceptions, and I initially loved
that Go decided not to have them. Explicit error checking, clearly,
is a great idea. (I'm one of those people that hates `-e` at the top
of a shell script -- check properly!) But soon I got to a point
where I couldn't bear to type another `if err != nil` and started
thinking "f-- it, it'll probably be fine". This makes Go the first
language I've ever used where I am genuinely tempted to ignore
errors. Me. Mister But-What-If...? I grit my teeth and do the right
thing, but so much Go code I see handles errors by assigning to
underscore.

Wrapping everything in `if err != nil` blocks isn't just tiring and
boring when you're writing code, it's even worse when you're
reading it.  When you are an SRE, diving into other people's
codebases without much prior knowledge, getting a quick sense of
what's going on is key. I find this hard with Go.  A small language
makes for uniform looking code, which needs much closer reading than
the same thing written in something more expressive.  Assembly is a
very small language. Can you tell, broadly, what a chunk of assembly
does without reading every line? I might say, flippantly, that most
of the deliberately obfuscated languages use tiny lists of verbs as
their [primary obfuscation](https://esolangs.org/wiki/Whitespace).

I have tried to look at Go's opinionated nature as a positive. As
something to free me from wasting time on the trivial stuff, and
help me concentrate on what I'm doing. But I find it equally easy to
see it as something to make me Just Like Everybody Else. And, like
everybody else, I don't want to be Just Like Everybody Else.

Would it better if there were only one type of food? It would be
easier to decide what to have for dinner wouldn't it? That's kind of
how I see Go. Today's menu: plain rice, 100g. Rob Pike's having a
steak, but you're all having the rice: it's good for you, and if we
let you have the steak, you'd probably eat it wrong and be sick or
something. Or spend all your time arguing about which knife to use.

I'm the kind of person who `rubocop`s, `pep8`s, or `-Wall`s
everything.  I like to be correct, so I don't know what it is about
Go's unilateral my-way-or-the-highway approach that irks me so.
Perhaps something in me *needs the option* to put braces in the
wrong place, or include an unused file, even if I don't actually
want to do it. Rust's compiler is *at least* as picky as Go's, but
you know that everything it wants you to do is for a good reason. It
needs you to follow strict rules so it can do something
remarkable. Go makes you follow strict rules because it can.

Treat me like an adult. Give me the rope. I won't complain if I hang
myself.

I suppose I'm a contrarian. Being told how to do things -- how to
think -- doesn't sit well with me, whatever the rewards.  Go is, of
course, a perfectly fine language. I don't have any technical
objections to it, I don't want to tell anyone who likes it that they
are wrong. I'd *love* to like it myself, not least because it's far
more commercially useful than any of the languages I *do* want to
use.

Those languages, -- Clojure, Rust, Elixir, and Crystal -- are, I
think, expressive and innovative. They offer new ways of thinking
and different ways to solve problems.  Each has given me new ideas,
new understanding, inspired me to code for the sake of coding, and
made me a better programmer in general. Go did none of these things.

The functional approach of (most of) those languages makes so much
sense to me, particularly with regard to concurrency. Learning about
that was truly a slap-to-the-forehead,
why-did-I-not-think-of-that-myself? moment. It's genius. I've coded
myself into knots more than enough times trying to keep track of an
updated structure in non-functional languages. Go's "give 'em
pointers" (and "give 'em locking primitives") approach doesn't just
feel old, it feels *wrong*. Maybe (maybe!) mutating data in-place is
faster, but the industry which is worried about shaving a few CPU
cycles off a transaction is not an industry I recognize any more.
And you've still got a GC overhead, if you're that bothered about
performance.

Finally, you can laugh all you like, but I care how my code looks on
the page. I honestly (when I have the time) take pride in it. I want
everything I write to look and read like poetry. (Yeah, I know...)
Go is brutally ugly, and `go fmt` is there to make sure it always
will be. Even the old `CAPS LOCK LANGUAGES (FROM THE 60S);` look
better.

A little while ago there was a mailing list announcement saying they
were going to let us align `=` in blocks of declarations. This
Earth-shattering reveal was made with all the condescention you'd
expect; the overall tone being that of a father giving his son a
penknife. "I'm trusting you here. You could hurt yourself. Don't let
me down, or I won't trust you next time."

And that's Go, isn't it? It's the "I know best", "do as I say not as
I do", disapproving, finger-wagging-father of programming languages.
With an infantile mascot to make it just that teeny bit more
patronising.

I'm done. You enjoy your Go, I'll enjoy my Ruby. It's a big world
with plenty of room for all of us.

We are not rational.

Well, I'm not.

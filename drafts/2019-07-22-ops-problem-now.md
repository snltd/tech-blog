---
title: "Ops Problem Now"
date: "2019-07-22"
tags: [Rant]
layout: post
category: rant
---

Once I [wrote a piece](/post/2015-05-05-why-i-hate-devops) about why I was
falling out of love with operations work.  The purpose of that essay was to
straighten out my head: lay your problems out before you and you often find
they're far less than you thought.

But four years later, I still believe every word of *Why I Hate DevOps*.  I've
lived in a loveless relationship too long, and I'm out. I now have my first
"proper" dev job since the late '90s.

These are my reasons for moving on.

# 1. AWS

Pretty much everyone, it seems, uses AWS. In the decade since I first used it,
my attitude to AWS has gone from "wow" to "cool" to "OK" to "meh" to "boring"
to zero. Actually, to less than zero, because I pretty much hate Amazon as an
entity.

Being a dev on AWS is, I'm sure, a liberating experience. After decades of
being beholden to The Ops Guy, spinning up whatever you need, whenever you
need it, changes everything. (Even if it makes everything distributed,
complicated, and expensive.) Being the The Ops Guy on AWS has, to This Ops
Guy, changed everything for the worst.

In the end, all AWS work boils down to futzing about with some amount of JSON
until the thing works, after which you leave it for ever. Said JSON may be IAM
rules, Cloudformation, bucket policy, or plain old configuration, but as an
AWS Ops Guy you're nothing more than a JSON wrangler.  They may try to glorify
it by calling it "code", but it's not. It's JSON (or YAML) with some awful
faux-logic and interpolation syntax shoehorned into it.

This is fine. There are far, far worse ways to make a living. But it feels
there's no *skill* in this work. It's hitting on the right happy combination.
Wondering for two hours why something doesn't work, waiting for the stack to
roll back, pondering an uninformative error message, until finally you realise
that there needs to be an exclamation mark on the end of the keyword
because... well, because there just does.

That's the crux. Everything is arbitrary. As a programmer, or even as a Unix
engineer, you work in complex system built from some amount of rules. With
experience you absorb these rules, and are able to produce better, more
efficient systems. The scope is infinite. You learn and grow. You can know a
tiny subset of Python, and still be able to write a program -- albeit a crude
one -- to do pretty much anything. But in AWS, however smart you are, however
experienced you are, there is no way on earth you're *ever* getting that
service to come up until you find the line of the documentation that says you
need to have `"ignoreInverseKeywordFalsehoods": 1` in your Cloudformation.

And why *would* you know that?  You may know everything there is to know about
Amazon Fishcake. But when they launch Amazon Crabstick, you're starting again
from zero. Unlike Fishcake, Crabstick doesn't use
`ignoreInverseKeywordFalsehoods`, it uses `acceptPositiveTruthsInKeywords`,
and values of that must be single-element arrays of booleans. Just Because.

I'm very old-fashioned in that I value knowledge. I resent single-use
knowledge as much as single-use plastic. Techniques learnt in Clojure may make
you a better Ruby programmer. I've seen things in Rails that make me write
better Elixir. Nothing learnt in AWS Fishcake will buy you anything anywhere
else. Everything is a cul-de-sac. In a ghetto.

You know the idea of "flow"? That wonderful state of mind when you are totally
at one with what you're doing and time disappears? You can't get that working
on AWS. Change JSON. Push change. Wait five minutes. Roll back. Change JSON.
Push change. Wait five minutes. Works. Wait another couple of minutes. Next
bit failed. Roll back. Change JSON. Push change.

Ops, at most places, is AWS-wrangling. Not interested. What's the alternative?

# 2. Kubernetes

If you're not guzzling the Amazon Kool-Aid -- or even if you are -- then you
probably feel you need Kubernetes.

No technology I've seen in my 20+ years in this industry seems to so aptly fit
the old "teenage sex" analogy as does Kubernetes. But a quick search on
Jobserve suggests everyone actually *is* doing it.  Probably in conjunction
with at least two of Ansible, Terraform, and EC2.

I ought to like Kubernetes. For years I've been complaining that AWS had
abstracted away all the things that used to make ops fun.  K8s brings them all
back. Want to worry about networking again?  About storage? About security?
About DN-effing-S? Have we got the product for you!

Ops pretty much boils down to running a computer program. This is not a hard
problem. But boy, are we ever intent on making it one.

The principle of engineering I value the most is simplicity. This is not a
core value which aligns with Kubernetes: a phenomenally complicated system
which seems to exist primarily as an enabler for phenonenal amounts of
phenomenally complicated tooling. The solution to every problem in the
Kubernetes space seems to be to install ten-thousand lines of Go from some
arbitrary Github repo, or wait for the next release.  (Or both.)

Putting this on the record could make me look pretty stupid in five years'
time, but I get the same feeling from Kubernetes that I got from OpenStack.
It's not the steaming pile that was, but it's still a massively complicated
solution to a problem you probably don't have.

AWS and K8s seem to pretty much define modern ops, and I don't want to get
mixed up in either of them. Any other options?

# 3. The Long Tail

There are, of course, still "proper" ops jobs. There are still "proper"
sysadmins maintaining "proper" software running on "proper" Unix, on "proper"
computers in a "proper" machine room.  But that's a world I already escaped
from, and have little desire to revisit. The only places with that kind of
setup are the places where the procurement team buy the server, the DC team
put it in a rack, the cabling team wire it up, the network team plug in the
RJ45s, the SAN team plug in the Infiniband, the OS team put Unix on it, the
security team harden it, and the application team install Websphere. Also
they're banks. So forget that.

In this decade I have worked at places that still have a Vax in a cage, but I
know the long tail will dwindle. Even the stuckingest sticks-in-the-mud are
migrating to AWS. A minority, I suspect, will run Kubernetes and value the
knowledge necessary to do so, but on the whole Amazon will abstract the ops
job out of existence.

For some years I've said that if I want to retire in this industry, I'll have
to do it as a developer. The only ops jobs will be at Amazon or Google or
Facebook, and I'd cut my thumb off before I'd work for them.

Fortunately, we have:

# 4. Modern Languages

I've always written code. I was always very sceptical of sys-admins who
didn't. The job was always about automation, and making your life easier. I
never particularly took to Perl or Python, and learnt just enough of them to
get a job done. I used to like shell scripts, but that's not real programming.
I spent way more time getting other people's C to compile than I ever did
writing my own. Even though I wrote a decent amount of PHP (at a time when the
alternatives were JSP and CGI scripts) I couldn't make much of a claim of
being "a programmer".

My part-time status got upgraded when I met Ruby. I love Ruby. Ruby properly
turned me on to programming. I *got* OO (having previously only seen PHP-4's
"interesting" take on it). Later, meta-programming and `Enumerable` were my
gateway drugs to the mind-expanding world of Lisp. Lisp led me to Clojure.
Clojure showed me FP and logic programming. Soon I was up to my eyes in Elixir
and sniffing round the edges of Prolog. Ruby led me to Rails, which
re-introduced me to Javascript, which had got all grown-up in the time since I
last saw it. I hated Go enough to try Rust out of pure spite, and found I
liked that too.

So while ops-land turns into desert, development is evolving and flourishing
in so many exciting ways. Whereas I can't motivate myself to spend a paid half
an hour reading the CLI doc for Amazon Fishcake, I'll happily sit up until
three in the morning code-golfing Project Euler 14 in Crystal.

---
title: "Config Management: Do it Yourself"
tags: [Puppet, Chef, opinion, rant]
date: 2015-11-18
category: Rant
layout: post
---

**Don't use wrapper cookbooks. Don't use forge modules. Don't write
completely generic configuration management code. Don't foist your
config management code on "the community".**

This, I know, is contrary to what you are told. It's contrary to the
idea of the Puppet Forge, or the Chef Supermarket, but it's a
hard-learnt-lesson from the last few years of my working life.

I am astonished at how complicated some people make the act of
configuring a computer to run some program or other.  When you get
down to it, setting up a piece of software, say Redis, or nginx,
comes down to: installing the package, dropping in a config file,
and starting a service. That's it. In Puppet, that's three
resources. You probably won't even need to template the config file
because it's the same everywhere. It's tempting, I know, to ERB the
shit out of that config file. "I might want to change the port Redis
listens on: better make that a variable". You won't, so don't. If
I'm wrong, and one day you *do*; make it a variable then, or just
change the file. Everything, for me, should be as simple as it
possibly can be. That's how I build stuff that works.

When you start genericizing modules or cookbooks, where do you draw
the line? The software you are targeting may have dozens, scores, or
hundreds of configuration options, which can perhaps be combined in
all kinds of thorny ways. (Apache. nginx.)  If you cover them all,
you've made something awfully complicated. It would likely take a
user far longer to read your docs (which you probably won't even
write) than it would to write those three little resources from
scratch.

And if you do choose to cover all those options, you're going to
have to keep up with new ones forever. If you don't, someone will
use your module, and sooner or later, they'll need to change
something you hardcoded, maybe because you couldn't be bothered,
because you didn't think anyone would ever want to change it, or
because it didn't exist at the time you wrote the code. They then
have to fork your code, or start again. They won't want to do either
of these things.

We all know re-use of code is a good thing, right? It's a no
brainer. The problem is that an awful lot of the "thought-leaders"
in devops or webops or sysadmin or whatever the hell it is I do
these days, have no brain. They don't think. They regurgitate dogma,
and apply valid principles in invalid contexts. How is it better to
re-use 10,000 lines of semi-randomly chosen, dubious quality
spaghetti off Github than to write the thirty lines of DSL you actually
need, yourself?

A (small) part of the problem is that so much of the community
config-management code is awful. Some of the many ready-rolled
modules Google throws up may be well coded, and some of those may
even do everything you need, but will your time be better spent
diligently sifting through the options than in writing simple code
yourself? I doubt mine is.

You already, hopefully, understand how to use Puppet or Chef
reasonably well, but if you're going down the community road, you still
have plenty more to learn, because each module will have its
own foibles, bugs, style, and limitations.
Rather than applying the principles of your config-management
framework, you end up trying to reverse-engineer the module author's
thought process, hoping that their problem was sufficiently similar
to yours.

Each module has its own assumptions, and dependencies.  At one
site I worked on, we had around a hundred-and-fifty instances in
EC2. And, because of the free-and-easy application of wrapper and
community cookbooks by a previous ops-ist, we had a
hundred-and-sixty cookbooks in our Chef repo. Because so many
third-parties were configuring our boxes, we had stuff being
installed from unknown PPAs, and even built from source. (After, of
course, pulling in a whole build environment.) We had services
controlled by SYSV init, runit, supervisord, daemontools, and
upstart.  In short, we had no consistency, and no idea what we had, or
how it was built.  We also had Chef runs longer than most TV
programmes, and dependency chains that still make me wince. (I
recall one set of machines which somehow managed to pull in *two*
Redis cookbooks, which didn't agree on certain things, and
constantly flip-flopped certain attributes between two values.)

My current client uses masterless Puppet, with all configuration in
Hiera, and quite a few, very carefully chosen, vendor modules. I
can't guess how many hours I've wasted trying to find exactly the
right Hiera incantation to replicate a tiny piece of configuration I
could write by hand in seconds, and drop in with a file resource.
But I feel obliged to follow the organization's policies, and do
things in the way they consider correct.

So, I spend hours running and re-running Puppet in Vagrant in one
terminal, with the module source code in another. Suddenly,
something which exists to make your life simpler makes it so much
more difficult. I **know** how to edit a file. I have to **learn**
how to use a module.

Some modules have value. They are the ones which extend the DSL. The
ones which give me new types so I don't have to write `exec` blocks.
But the ones that write a config file? No thank you.

I understand why Puppetlabs and Chef want you to use the community
code. It flattens the learning curve; it fools you into thinking
you're buying into a simple turnkey solution rather than a
programming framework. But this is wrong. If you want to use config
management, learn the tool you've chosen. Understand the principles.
Keep it simple. Keep it in-house.

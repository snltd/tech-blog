---
title: "Deciding to Write My Own Config Management Tool"
date: 2025-06-04
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

## Config Management and illumos

I've been using config management since the late 1990s, when I did an evaluation
of CfEngine. (Conclusion: not worth the effort, which it probably wasn't on our
tiny, ancient, never-changing system. I wrote a stack of Jumpstart finish
scripts and we left it at that.) Since then I've been paid to use Chef, Puppet,
CloudFormation, Fabric, Terraform, Ansible, and various Kubernetes-related
YAML-wranglers, all with varying degrees of distaste and disappointment.

These days, for paying the bills, it's just Terraform: I haven't been paid to manage
servers in a good while. But at home I have a some 
[OmniOS](https://omnios.org/) boxes which run a couple of dozen zones providing
various home- and hobby-related services.

I used to configure everything with Puppet, using
[my own illumos-specific fork](https://github.com/snltd/puppet-solaris_providers)
of [Oracle's providers](https://github.com/oracle/puppet-solaris_providers), but
it was always a bit of a house of cards, and keeping it working took effort.
When OmniOS dropped support for the only OpenSSL version that worked with it, I
couldn't be bothered any more, and I switched to Ansible.

Ansible works, and it has surprisingly complete support for illumos, but it made
me think that perhaps it was finally time to scratch that itch I've always had,
and write my own, insanely-specific, illumos config management tool.

And rule #1: NO YAML.

## Party in the Front

I always felt Lisp, with its facility for DSLs, would make a great config
management language. But which one to choose? There are so many.

I've always been interested in [Clojure](https://clojure.org/), and because it's
JVM-based it will run on illumos. But I don't want to have to install a JVM and
Clojure package on every zone I want to configure. The reason I stopped using
Chef was because it wanted more memory than my zones were allowed to use, and a
JVM isn't going to improve that. So no Clojure, even though that's the flavour I
know. (Scheme and Common Lisp are a bit of a mystery to me.)

[Babashka](https://babashka.org/) is a fast-startup Clojure, but built around
GraalVM, which means it will never run on illumos.

[Janet](https://janet-lang.org) is a small, fast language which implements many
of Clojure's good ideas in a (close to) zero start-up-time C VM. I did a few
days of Advent of Code with it a couple of years ago and liked it, so Janet got
the nod.

I wrote, in an invented DSL, what I thought a host configuration should look
like. I tweaked it, decided it was rubbish, binned it, started again, decided
the new approach was too opaque, spent a lot of time thinking about efficiency,
clarity, and ergonomics, started a couple more times, and eventually I had
something I liked.

There were more changes of plan as things proved too difficult to implement (the
brain-bendingness of Lisp macro expansion!) or led to inflexibility, or simply
looked a mess on the page. (I am weirdly picky about this. The first thing that
prejudiced me against Go was how ugly it looks.)

I eventually settled on something which I suppose is just like Chef, and Puppet,
and maybe even YAML, but with the parentheses in different places. I like it
though, and as no one else will ever use this tool, that's all that matters.

Here's a host, composed of roles.

```janet
(import roles/basenode)
(import roles/webserver)

(host my-host
  (basenode)
  (webserver))
```

A role might look like this:

```janet
(role basenode
  (pkg/ensure "shell/zsh")
  (pkg/ensure "ooce/editor/helix")
  (pkg/ensure "ooce/text/ripgrep")
  (pkg/ensure "ooce/util/fd"))

  (directory/ensure "/export" :group "sysadmin")
  (directory/ensure "/export/home"))

  (file/ensure "/etc/sudoers.d/sudo_group"
               :mode "0400"
               :content "%sysadmin ALL=(ALL:ALL) ALL"))
```

That, I think, is clear and elegant. It would be nice to not need the
`(import)`s, but you've got to link files somehow.

Written in such a simple way my config doesn't look all that different from the
hated YAML, but it's a real language, so not only can you put spaces wherever
you like, but if you wished you could install those packages with

```janet
(def packages ["shell/zsh" "ooce/editor/helix" "ooce/text/ripgrep" "ooce/util/fd"])

(role basenode
  (loop [pkg :in packages] (pkg/ensure pkg)))
```

You can thread variables through things, write helper functions for common
tasks, and basically do whatever you like without nasty artificiality.
Infrastructure as actual code. It's the future.

## Business in the Back

As I started to make my lean, clean definitions correspond to actions, I found
myself restricted by the somewhat limited flexibility of Janet's module system.
Building any kind of modularised configuration meant an awful lot of the kind of
`(import)` boilerplate I was so keen to avoid.

To try to get around this, I looked into what Janet calls "image files". These
are binary captures of environments, which means a Lisp program plus the
definitions around it. Bundling config and supporting libraries into a `.jimage`
could certainly make distribution simpler.

Going further, Janet programs can be compiled into native executables, and I
toyed with the idea of a "server" which would build tool, libraries, and config
into a single unique binary which could be pushed to a target and run. But I
found that extra compilation phase, and the idea of debugging binary artifacts,
offputting.

Janet is a very minimal language, which is not necessarily a bad thing, but I
soon hit its edges. For instance, there's no way to natively change a file's
owner. You have to shell out (which I didn't want to do, despite
[this brilliant module](https://github.com/andrewchambers/janet-sh)), or you
have to add new functions by either extending the core language or writing a C
extension.

I haven't written any C from scratch this century, but as I've become quite the
Rust fan lately, I had a look around for Rust/Janet bindings, and
[found them](https://docs.rs/janetrs/latest/janetrs/). I could write Rust
modules for the bits native Janet couldn't cover, but why not flip things
around, and use Rust for main program, embedding a Janet interpreter? That would
give me very tight system integration, speed, safety, static typing where it
counts, and a single binary, which could even have my ever-growing Janet DSL
embedded inside it.

As this was meant to be a fun side-project, I was happy to see what direction it
went in and not plan it out too much. But I did make a little list of rules for
myself.

- Configuration is defined in a thin Janet DSL.
- Rust will do all the work.
- "Done" means it can rebuild all my systems with the exact same results as my
  Ansible config.
- It is illumos-specific. In fact, OmniOS specific. It will not support any
  other OS.
- It will integrate cleanly with things like SMF and ZFS, abstracting their
  config a consistent DSL.
- It is as fast as it reasonably can be.
- It will be as simple and minimal as it reasonably can be.

The main one was the last one. Features will be added as they are needed. The
road to hell is paved with "It might be nice if...", and "one day I might want
to...".

I've always felt part of the problem of the likes of Puppet and friends was their
relentless all-things-to-all-people feature creep and huge, mostly stale, community ecosystems. [I wrote about this ten years ago](/post/2015-11-16-do-it-yourself) when I was at the coal-face of config management, and I haven't changed my opinion. You can
accomplish a heck of a lot by dropping a file and restarting a service, so I
decided, at least in its first iteration, to provide no mechanism for running
arbitrary commands.

For reasons too silly to go into I called my program Gurp. Then I
[put it on Github](https://github.com/snltd/gurp),

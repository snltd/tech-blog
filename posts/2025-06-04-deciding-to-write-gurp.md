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

These days, commercially, it's just Terraform: I haven't been paid to manage
servers in a good while. But at home I have a couple of OmniOS boxes which run a
couple of dozen zones providing various home- and hobby-related services.

I used to configure these with Puppet, using
[my own illumos-specific fork](https://github.com/snltd/puppet-solaris_providers)
of [Oracle's providers](https://github.com/oracle/puppet-solaris_providers), but
keeping it running got to be more and more work, and when OmniOS eventually
dropped support for the only OpenSSL version that worked with it, I couldn't be
bothered any more, and I switched to Ansible.

I'm not the biggest Ansible fan. It works, and it has surprisingly reasonable
support for illumos, but it made me think that perhaps it was finally time to
scratch that itch I've always had, and write my own, insanely-specific, config
management tool.

And rule #1: NO YAML.

## Party in the Front

I always felt Lisp, with its facility for DSLs, would make a great config
management language. But which one to choose? There are so many.

I've always been interested in [Clojure](https://clojure.org/), and because it's
JVM-based it will run on illumos. But I don't want to have to install a JVM and
Clojure package on every zone I want to configure. The reason I stopped using
Chef was because it wanted more memory than my zones were allowed to use, and a
JVM isn't going to improve that. So no Clojure.

[Babashka](https://babashka.org/) is nice, but it uses GraalVM, so it's never
going to run on illumos.

[Janet](https://janet-lang.org) is a small, fast language which implements many
of Clojure's good ideas in a zero start-up-time C VM. I did a few days of Advent
of Code with it a couple of years ago and liked it, so Janet got the nod.

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

That, I think, is clear and elegant. Written this way it isn't all that
different from the hated YAML, but it's a real language, so not only can you put
spaces wherever you like, but if you wished you could install those packages
with

```janet
(def packages ["shell/zsh" "ooce/editor/helix" "ooce/text/ripgrep" "ooce/util/fd"])

(role basenode
  (loop [pkg :in packages] (pkg/ensure pkg)))
```

You can thread variables through things, write helper functions for common
tasks, and basically do whatever you like without nasty artificiality.
Infrastructure as actual code. It's the future.

## Business in the Back

As I started to make my nice clean definitions correspond to actions, I hit
problems. First, the somewhat limited flexibility of Janet's module system.
Building any kind of modularised configuration meant an awful lot of
`(import)`s, and it started to look like there would be nearly as much stuff to
carry around as there was with Puppet and Ansible.

Many Janet modules need a C-compiler, and the last thing I wanted was a heavy
dependency chain. You can, however, compile native binaries, and what Janet
calls "image files", which are binary captures of environments. (In Lisp this
means a program plus the definitions around it.) I toyed with the idea of a
"server" which would compile all your config into a single `.jimage`. I even
considered compiling the toll and config into a single unique binary, which the
server could push to the target machine and run. But I found that extra
compilation phase, and the idea of debugging binary artifacts, offputting.

Janet is a very minimal language, which is not necessarily a bad thing, but I
soon hit its edges. For instance, there's no way to natively change a file's
owner. You have to shell out (which I didn't want to do, despite
[this absolutely brilliant module](https://github.com/andrewchambers/janet-sh)),
or you have to add new functions by either extending the core language or
writing a C extension.

I haven't written any C from scratch this century, but I've become quite the
Rust fan lately, so I had a look around for Rust/Janet bindings, and
[found them](https://docs.rs/janetrs/latest/janetrs/). I could certainly write
Rust modules for the bits native Janet couldn't cover, but why not write the
main thing in Rust, embedding a Janet interpreter? That would give me very tight
system integration, speed, safety, static typing where it counts, and a single
binary, which could even have my ever-growing Janet DSL embedded inside it.

As this was meant to be a fun side-project, I was happy to see what direction it
went in and not plan it out too much. But I did make a little list of rules for
myself.

- Configuration is defined in a thin Janet DSL.
- Rust will do all the work.
- "Done" means it can rebuild all my systems with the exact same results as my
  Ansible config.
- It is illumos-specific. It will not support any other OS, but it will
  integrate cleanly with things like SMF and ZFS.
- It is as fast as it reasonably can be.
- It will be as simple and minimal as it reasonably can be.

The main one was the last one. Features will be added as they are needed. The
road to hell is paved with "It might be nice if...", and "one day I might want
to...".

For reasons too silly to go into I decided to call it Gurp, and I
[put it on Github](https://github.com/snltd/gurp),

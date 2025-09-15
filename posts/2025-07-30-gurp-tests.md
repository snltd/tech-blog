---
title: "Testing Gurp"
date: 2025-07-30
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

When you're
[writing a config management tool](https://tech.id264.net/post/2025-06-04-deciding-to-write-gurp)
-- whose sole purpose is to run as root and change things -- you've got to be
pretty confident it's going to do what you think it's going to do. This means
tests. Loads of tests.

### Unit Tests for Vanity

Gurp's backend -- the bit which actually changes things -- is all written in
Rust, and it doesn't have a huge amount of test coverage.

As an absolute Rust novice I wrote a lot of unit tests. I was in the habit,
having come from a Ruby background, and it helped me understand the basics of
the language. But as I became more able, I found I had more confidence in my
code than I've had with any other language. Unit tests felt necessary only if I
was implementing some hard-to-understand, complex logic. Most of my Rust
projects now only have integration, or even full end-to-end tests.

If you look at
[Gurp's Janet code](https://github.com/snltd/gurp/tree/main/janet_src) however,
you'll find that pretty much every function and every macro has unit tests. I
think behaviour has to be pinned down somehow, and a quick
assert-output-from-input is a good way to that. It's safety for refactoring, a
description of behaviour, example use, and type checking, pretty much for free.
(I'm not strongly opinionated on static vs dynamic typing. They both have pros
and cons, all of which are usually overstated.)

### Functional Tests for Sanity

What Gurp lacked was strong functional tests, but different parts of it mandated
different approaches.

The `file-line` doer is pure Rust. It calls no external commands, so it's
OS-agnostic, and you can test it thoroughly from `mod test{}`, creating and
manipulating real files in a temporary space with
[`assert_fs`](https://docs.rs/assert_fs/latest/assert_fs/). It all works just
fine on my illumos dev box, my Mac, and in Github actions.

`file` and `directory` are harder because, even though they also don't shell
out, they can change file ownership which, running as a normal user, `cargo`
(probably) can't do.

I could do some `pfexec` chicanery on my dev box, and Github Actions lets us run
things in containers. So we could let `cargo` take privileged actions, and write
tests that perform real actions on real files then use a bit of metadata
inspection to check things worked. But running as root is dirty. We're better
than that.

And how about something like SMF, which starts and stops services, but only on
illumos? We can test that sensible-looking manifests are generated from user
input, but how do we ensure that when those manifests are imported, they do the
right thing? We can't run SMF in Docker, or on a Mac, so the best we can do is
assert the manifests Gurp generates, and the commands it runs. That introduces a
lot of messy mocking, and it's never going to be the same as interacting with a
real OS. If the interface changes, I need to know.

Clearly, proper functional tests can only run on an illumos box. Fine. That's
where I do 90% of my development. Gurp itself can spin up a zone and run itself
and other processes, as root, in that zone, so it feels like it ought be testing
itself somehow. But how should it do it? What does it need to run inside that
zone?

Gurp's actions ought to be idempotent, so a simple test would be to run it once,
then run it again and assert that it makes no changes. That proves some amount
of the internal logic, but it does not prove it did what it said it would. It
may have got `owner` and `group` the wrong way round on every file both times.

The obvious approach is to write a separate tester, probably in Rust. But I know
if I did that I'd likely end up re-using code from Gurp itself, or at least
taking a very similar approach. I might make the same mistake in both places. I
also have to think about how I would define the desired state? It feels a lot
like writing a second Gurp. And what if there was some obscure bug in Rust where
it always set files to `2755` instead of `0755` on illumos? Yes, it's a
contrived example, but I don't like the idea of using something to test itself.
I need to look at another language.

My first thought was [ServerSpec](https://serverspec.org) I used that a lot on a
previous job and I quite liked it. But it's old now, and I have no idea how well
it covers illumos. It also needs Ruby, which means I'd have to build a reference
zone with a runtime and all the required gems, then have Gurp clone a fresh zone
from that every time it wanted to run the tests. That's not so painful, but
there was something about polluting the test environment that put me off.

I like Ruby, so I considered a from-scratch Ruby checker, but there's no way
around that runtime. That led me to Crystal, which is equally flexible and
DSL-friendly, but compiles to a single, fast binary, But Crystal's illumos
support was very sketchy the last time I tried it.

Through gritted teeth, I looked at the YAML-driven
[goss](https://github.com/goss-org/goss). It fell at the first hurdle, having
dependencies that don't build on illumos, and even if I got it working, I'd have
to implement support for things like `svcprop` myself.

So why not write something a little like `goss`, in Go? Well, this is supposed
to be a fun project, which rules Go out completely. And, again, I don't want to
write TWO config management tools.

When I set down my requirements:

- Not Rust.
- Not a re-implementation of everything I already did.
- Fast.
- Minimal dependencies.
- Quick to implement.

I realised I already had the tools I needed.

### Judge

[Judge](https://github.com/ianthehenry/judge) is the Janet testing framework I
already use in Gurp. It has a very nice line in macro expansion, but the feature
of interest here is that _it generates test values for you_.

Say you put this in a file:

```janet
(use judge)

(test (-> ["p" "r" "u" "g"] (reverse) (string/join) (string/ascii-upper)))
```

and run `judge`, you see

```janet
(test (-> ["p" "r" "u" "g"] (reverse) (string/join) (string/ascii-upper)))
(test (-> ["p" "r" "u" "g"] (reverse) (string/join) (string/ascii-upper)) "GURP")

0 passed 1 failed
```

Notice that Judge has filled in the second half of the comparison. And if you
run `judge -a`, it will write that value into the file. If you are happy with
the value, leave it there (you can of course put the value in yourself), and
when you re-run `judge`, the test will pass. Given that collecting the values
for the assertions is half the work, this is a big win.

### janet-sh

The other part of the puzzle is
[janet-sh](https://github.com/andrewchambers/janet-sh), which makes shell
scripting just about as nice as shell scripting can be.

```janet
($ ls /etc | grep pass)
```

Does exactly what you think it will. And `($< ls /etc | grep pass)` will capture
stdout.

Putting the two together, let's say I want to test that my publisher got added
as it should. You list publishers with `pkg publisher`.

```janet
(use judge)
(use sh)

(deftest "test-sysdef-publisher-was-created"
  (test
    ($< pkg publisher)))
```

I run `judge -a`, and it inserts into the `(test)` call the stdout of the
`pkg publisher` command. I eyeball it, it looks good, and I have an infintely
repeatable test. Minimum effort, maximum satisfaction.

The `($)` macro is extremely capable, and can handle flags, pipes, errors, and
anything else you could wish for. So it's super easy to write targeted shell
commands.

How about this, which asserts that `pkg list missing/package` fails, `false`
dumping standard error to `/dev/null`.

```janet
(test ($? pkg list missing/package :> [stderr :null]) false))
```

Or if it's neater, I can capture output, parse it in Janet with
[a PEG](https://janet-lang.org/docs/peg.html) or whatever, and assert on some
aspect of that parsed output.

## Implementation

I made a new project, called [Merp](https://github.com/snltd/merp). It sits in
my home directory, which is accessible from my dev zone and that machine's
global zone.

From the Janet-equipped dev zone, I run
[a script](https://github.com/snltd/merp/blob/main/setup-repo.sh) which copies
in the `janet` binary, and uses `jpm` (the Janet package manager) to install the
`judge` and `sh` modules.

In the global zone, I run
[a second script](https://github.com/snltd/merp/blob/main/setup-template-zone.sh)
which makes a clean "gold" zone containing `janet` and the aforementioned
modules.

From that zone Merp instructs Gurp to clone a test zone and configure it in a
particular way.

To save on boilerplate, a
[`(controller-for)` macro](https://github.com/snltd/merp/blob/main/tests/helpers.janet)
spits out the Gurp config we need for the given role. It's called like this:

```janet
(controller-for "pkg-server" :remove-after false
                             :test-basenode true
                             :with-dataset true)
```

`basenode` is a module all my zones get, and which most of them need to do their
thing. Adding the `:test-basenode` option applies and tests `basenode` in the
cloned zone.

If `:with-dataset` is truthy, Gurp also creates a ZFS dataset which is delegated
to, and mounted inside, the test zone.

`:remove-after` tells Gurp to destroy the zone and, if there was one, the
dataset, once the tests have run. Normally you'd want to do that, but not doing
so makes it simpler to develop tests.

The zone config generated by `controller-for` also includes a `(zone-fs)`
resource, which loopback mounts the `merp` directory in the zone's `/var/tmp`.

I write a skeleton test of all the things I want to check, mostly using shell
commands. As a very simple example:

```janet
(deftest "test-zone"
  # Janet's (os/stat) is too detailed, giving inodes and other info we'd have to drop
  (test ($< /bin/stat -c "%U:%G %A" /export/home/backup))

  (test ($< /bin/svcs -Ho state svc:/sysdef/telegraf:default)))
```

I run the tests with
[a shell wrapper](https://github.com/snltd/merp/blob/main/run-tests.sh) that
lets me test one or all zones, run in debug mode, clean up any dangling
resources, and generally make life easier.

The first time a role's tests run, they fail because they have no expected
values. So I `zlogin` to the zone, `cd /var/tmp/tests/judge` and run
`judge -a test-module.janet`. Judge fills in the blanks and the above file
becomes

```janet
(deftest "test-zone"
  (test ($< /bin/stat -c "%U:%G %A" /export/home/backup)
    "root:root drwxr-xr-x\n")

  (test ($< /bin/svcs -Ho state svc:/sysdef/telegraf:default)
      "online\n"))
```

If the results look good, I'm done. The next time I `run-tests.sh` the tests
will pass. Assuming Gurp works, of course.

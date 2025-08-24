---
title: "Testing Gurp"
date: 2025-07-30
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

When you're writing a tool whose sole purpose is to run as root and change
things, you've got to be pretty confident it's going to do what you think it's
going to do. This means tests. Loads of tests.

### Unit Tests for Vanity

Gurp's backend -- the bit which actually changes things -- is all written in
Rust, and it doesn't have a huge amount of test coverage.

As an absolute Rust novice I wrote a lot of unit tests. I was in the habit,
having come from a Ruby background, and it helped me understand the basics of
the language. But as I became more able, I found I had more confidence in my
code than I've had with any other language. Unit tests seemed necessary only if
I was implementing some hard-to-understand, complex logic.

If you look at
[Gurp's Janet code](https://github.com/snltd/gurp/tree/main/janet_src), however,
you'll find that pretty much every function and every macro has tests. I think
behaviour has to be pinned down somehow, and a quick unit test is a good way to
that. (I'm not strongly opinionated on static vs dynamic typing. They both have
pros and cons, all of which are usually overstated.)

### Functional Tests for Sanity

What Gurp lacked was strong functional tests.

The `file-line` doer is pure Rust, and OS-agnostic, so you can test it
thoroughly from `mod test{}`.

`file` and `directory` are harder because, even though they don't shell out,
they can change file ownership which, running as a normal user, `cargo`
(probably) can't do. Github actions lets us run things in containers, so we
could run as root, and write tests that perform real actions on real files, then
use [`assert_fs`](https://docs.rs/assert_fs/latest/assert_fs/) and a bit of
metadata inspection to check things worked. But running as root is dirty. We're
better than that.

How about something like SMF? We can test that sensible-looking manifests are
generated from user input, but how do we ensure that when those manifests are
imported, they do the right thing? We can't run SMF in Docker, so the best we
can do is assert the manifests Gurp generates, and the commands it runs. That
introduces a lot of messy mocking, and it's never going to be the same as
interacting with a real OS.

Proper functional tests can only run on an illumos box. Fine. That's where I do
90% of my development. Gurp itself can spin up a zone and run a command in that
zone, so it seems like it could be used to test itself. But what should it run
inside that zone?

Gurp should be idempotent, so a simple test would be to run it once, then run it
again and assert that it makes no changes. That proves some amount of the
internal logic, but it does not prove it did what it said it would. It may have
got `owner` and `group` the wrong way round on every file both times.

The obvious approach is to write a tester, probably in Rust. But I know if I did
that I'd end up re-using the code from Gurp itself, or at least taking a very
similar approach. I might make the same mistake in both places. Then I have to
think about how I would define the desired state? It feels a lot like I'd end up
writing a second Gurp. And what if there was some obscure bug in Rust where it
always set files to `2755` instead of `0755` on illumos? Admittedly it's a
forced example, but I don't like the idea of using something to test itself. I
need to look at another language.

In the past I wrote a lot of ServerSpec. It's a decent tool but it's rather old,
and it requires Ruby. Ruby is a big package, with a lot of files, and I don't
want to have to drop it into my test zone every time. I could build a reference
zone with Ruby and all the required gems, and have Gurp clone a fresh zone from
that every time it wanted to run the tests, but ServerSpec is pretty old, and I
don't know how good its illumos support might be.

I like Ruby, and I considered a from-scratch Ruby checker, but there's no way
around that Ruby runtime. I even thought about Crystal, but the illumos support
for it was extremely sketchy the last time I looked.

Through gritted teeth, I looked at the YAML-driven
[goss](https://github.com/goss-org/goss). It fell at the first hurdle, having
dependencies that don't build on illumos, and even if I got it working, I'd have
to implement support for things like `svcprop` myself.

So why not write something a little like `goss` myself, in Go? Well, this is
supposed to be a fun project, which rules Go out completely. And, again, I don't
want to write TWO config management tools.

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

(test (-> ["P" "R" "U" "G"] (reverse) (string/join) (string/ascii-upper)))
```

and run `judge`, you see

```
# a.janet

(test (-> ["P" "R" "U" "G"] (reverse) (string/join) (string/ascii-upper)))
(test (-> ["P" "R" "U" "G"] (reverse) (string/join) (string/ascii-upper)) "GURP")

0 passed 1 failed
```

Notice that Judge has filled in the second half of the comparison. And if you
run `judge -a`, it will write that value into the file. If you are happy with
the value, leave it there (you can of course put the value in yourself), and
when you re-run `judge`, the test will pass. Given that collecting the values
for the assertions was going to be half the work, this is a big win.

### janet-sh

The other part of the puzzle is
[this terrific library](https://github.com/andrewchambers/janet-sh) which makes
shell scripting just about as nice as shell scripting can be.

```janet
($ ls /etc | grep pass)
```

Does exactly what you think it will. And `($< ls /etc | grep pass)` will capture
stdout, allowing you to use it in scripts.

Putting the two together, let's say I want to test that my publisher got added
as it should.

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
commands. Or if it's neater, I can capture output, parse it in Janet with
[a PEG](https://janet-lang.org/docs/peg.html) or whatever, and assert on some
aspect of that parsed output.

## Implementation

I made a new project, called Merp. It is in my home directory, which is
accessible from my main dev zone and also from the global zone of the machine
which hosts it. From the dev zone, which has Janet installed, I run a script
which copies in the `janet` binary, and uses `jpm` (the Janet package manager)
to install the `judge` and `sh` modules.

In the global zone, I run a script `setup.sh`, which installs a clean zone and
copies into it `janet` and the aforementioned modules.

A `(controller-for)` macro spits out Gurp config to clone that zone and
bootstrap it with a given role. It's called like this:

```janet
(controller-for "pkg-server" :remove-after false
                             :test-basenode true
                             :with-dataset true)
```

`basenode` is a module all my zones get, and which most of them need to do their
thing. Adding the `:test-basenode` option applies and tests `basenode` in the
cloned zone.

If `:with-dataset` is truthy, Gurp also creates a ZFS dataset which is delegated
to the test zone.

`:remove-after` tells Gurp to destroy the zone and, if there was one, the
dataset, after the tests have run. Normally you'd want to do that, but not doing
makes it simpler to make tests.

The zone config generated by `controller-for` includes a `(zone-fs)` resource,
which mounts the `merp` directory in the zone's `/var/tmp`.

I write a skeleton test of all the things I want to check, like

```janet
(deftest "test-zone"
  (test ($< /bin/stat -c "%U:%G %A" /export/home/backup))

  (test ($< /bin/svcs -Ho state svc:/sysdef/telegraf:default)))
```

then run a little `run-tests.sh` wrapper. This calls Gurp, which clones the
zone, bootstraps it, and calls `zlogin` to run the tests. They obviously fail
because they have no expected values. So I `zlogin` to the zone myself,
`cd /var/tmp/tests/judge` and run `judge -a test-module.janet`, and my above
file becomes

```janet
(deftest "test-zone"
  (test ($< /bin/stat -c "%U:%G %A" /export/home/backup)
    "root:root drwxr-xr-x\n")

  (test ($< /bin/svcs -Ho state svc:/sysdef/telegraf:default)
      "online\n"))
```

If the results look good, I'm done. The next time I `run-tests.sh` the tests
will pass. Assuming Gurp works, of course.

I like this solution so much I'm toying with the idea of writing a tiny
ServerSpec style tool around it.

---
title: "Client/Server in Gurp 2.0.0"
date: 2026-04-26
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

Today I want to talk more about Gurp, specifically about a fundamental change in
the interaction between client and server.

Gurp has had
[client/server mode since version 1.3.0](/post/2025-11-05-gurp-server), but it
wasn't always as useful as it looked.

To understand why, first know that a `gurp apply` has three phases.

1. Turn a user config ([Janet](https://janet-lang.org)), into a struct of Janet
   resource descriptions. This requires the Gurp DSL: a Janet library baked into
   the `gurp` executable.
2. Turn said resource descriptions into a single JSON object.
3. Deserialize the JSON into Rust structs.
4. Ensure that every resource has the spec defined in its struct.

In 1.x client/server mode, the server performed steps 1 and 2, sending JSON over
the wire.

Often, this is fine, but what if the user config contains logic that would yield
different results on the client and the server?

As an example, here's the first real problem I hit: a (annotated) role from my
own Gurp config, which runs in global zones and updates Gurp in every NGZ with
an `/opt/site/bin` directory.

```janet
(role gurp-in-zones
      (def zone-site-bins
        (->> (os/dir "/zones")     # iterate over entries in /zones
             (map |(pathcat zone-root $ "root/opt/site/bin"))
                                   # build a path to the target dir from each zone name
             (filter os/stat)))    # drop any paths which don't exist

      (loop [dir :in zone-site-bins]
        # create a resource for each dir in the list we just made
        (file/ensure (pathcat dir "gurp")
                     :from "/path/to/most/up-to-date/gurp"
                     :mode "0755")))
```

Compile that in the global zone, and the JSON will contain the relevant
`file/ensure` resources. Compile it anywhere else, and it won't.

This is fatal for Gurp's client/server model. Config which inspects any property
of the host _must_ be compiled in-place.

Maybe we could have the client serve up the raw config? But, even simple configs
contain different roles and files, all of which would have to be bundled up,
sent, unpacked, compiled, applied, and tidied up. The best approach I could
think of was to rsync everything everywhere, and I didn't like that at all.

I made my global zones apply from local config and used client/server in NGZs.
It worked, but the problem nagged at me, as did the way that things like
`this-host` were creeping into the DSL. as markers to tell the back-end to
inspect the local host. This smelt too much like Ansible, and "magic" YAML. It
bothered me.

It also bothered me that the Gurp DSL library had grown to well over a thousand
lines of Janet, all in one increasingly hard to maintain file.

There was a good reason for the single file, at least initially. Janet does not
hoist functions, so you must declare all the DSL ahead of the user config. The
single file was embedded in the Gurp binary with an `include_str!()` call, then
injected at the top of the user's config. It was a clean, simple MVP, in-line
with Gurp's strongest guiding principle: deal with complexity when you _must_.

For some time I had wanted to break the library up. But it seemed impossible
because modules would have to `import` their dependencies, and `import`s make no
sense in a flat file. The options seemed to be to either dump the library to
disk at compile time and let Janet assemble everything (NO!) or to keep the
embed/inject approach, and have Cargo construct a single file from the bits at
build time, either dropping `use` and `import` lines, or wrapping them all in
guards. Also, emphatically, NO! Just breaking the single file into chunks and
catting them back together was no good either, because they'd be impossible to
unit test. Again, I left it alone, and it nagged at me.

Until...

```cmd
$ cat lib.janet
(def library-says "all is clear")
```

...I realised the two apparently unrelated problems had a single, elegant
solution.

````cmd
$ janet
Janet 1.40.1-local illumos/x64/gcc - '(doc)' for help
repl:1:> (curenv)
@{_ @{:value <cycle 0>}}
repl:2:> (import ./lib :prefix "" :export true)
@{_ @{:value <cycle 0>} library-says @{:private false}}
repl:3:> (def my-definition "is-a-string")
"is-a-string"
repl:4:> (defn my-greeter [name] (print "Hello " name))
<function my-greeter>
repl:5:> (curenv)
@{_ @{:value <cycle 0>} library-says @{:private false} my-definition @{:source-map ("repl" 2 1)
:value "is-a-string"} my-greeter @{:doc "(my-greeter name)\n\n" :source-map ("repl" 3 1)
:value <function my-greeter>}}```
````

Janet deals in "environments". In the REPL above, we started with a blank
environment (shown by `(curenv)`, which refers to the current environment), and
added to it a binding and a function, with`def`and`defn` respectively. Now watch
this (still in the same REPL session):

```cmd
repl:6:> (spit "stored-env.jimage" (make-image (curenv)))
nil
repl:7:> ^D
```

(I apologise for `spit`, and the forthcoming `slurp`. Mentally substitute them
with `write-file` and `read-file`.)

```cmd
$ janet
Janet 1.41.1-homebrew macos/aarch64/clang - '(doc)' for help
repl:1:> (merge-module (curenv) (load-image (slurp "stored-env.jimage")))
@{_ @{:value <cycle 0>} lib-fn @{:private true} my-definition @{:private true} my-greeter
@{:private true}}
repl:2:> (my-greeter "Rob")
Hello Rob
nil
repl:3:> (library-says)
all is clear
nil
```

We wrote, then -- on a different host and architecture -- read an _image file_:
a compact, portable, binary representation of a Janet environment. It contained
our binding, function, and, most importantly, the contents of library we loaded.
(Because we specified `:export true` when we imported it.)

But our image only contained the things we made. Remember how, at the start of
the first REPL, the current environment was empty, but we could still run
functions like `curenv` and `make-image`? Where were they?

They were in a _different_ environment which, by default, we couldn't see. Janet
environments _nest_, so if a symbol can't be resolved in `curenv`, the VM will
try the next one down until it hits the root. You can see the lower envs, if you
know where to look:

```cmd
repl:1:> (fiber/getenv (fiber/root))
@{% @{:doc "(% & xs)\n\nReturns the remainder of dividing the first value of xs by each
...
```

Here's the key: put the Gurp library in an environment below the user's code,
making the DSL hidden, but available. Client and server both have the library,
so we'd only need to pass the environment containing the user config, which the
server's embedded interpreter can assemble by following as many `use`s and
`import`s as it has to.

I [took the single file apart](https://github.com/snltd/gurp/pull/205),
separating concerns, with common code in library files. I did the same with the
unit tests. I made a new boss
[`gurp.janet` file](https://github.com/snltd/gurp/blob/main/janet/src/gurp.janet),
to pull everything together.

The `janet` executable has a `-c` flag which makes it super-easy to build
images. But I didn't want Janet to become a build dependency, so I wrote
[a `build.rs`](https://github.com/snltd/gurp/blob/main/embed/build.rs) which
runs `gurp.janet` through Gurp's own Janet interpreter, creating a library image
which it embeds in the final binary. (Cargo is smart enough to rebuild the
library if any Janet file changes, and we don't keep the library image in
version control.)

Now the client/server phases are:

1. The client requests its config.
2. The server loads the config, and Janet's module system assembles an
   environment from it and all its dependencies. The server returns this as an
   image. _Nothing has yet been executed!_
3. The client starts a Janet interpreter with its embedded library image loaded
   into the root environment, and the config image above it.
4. The client calls the config image entry point, turning the resource
   descriptions into a single JSON object. If it needs to access the filesystem,
   it accesses the _client's_.
5. The client deserializes the JSON into Rust structs.
6. The client ensures that every resource has the spec defined in its struct.

A further benefit is that, though Gurp doesn't yet have a proper secrets
solution, we're now far less likely to be sending sensitive data over the wire.
Clients can call out to a vault or whatever, rather than a cert or password
being baked into the JSON they receive.

On the theme of security, Gurp v2 enables
[Janet sandboxing](https://janetdocs.org/core-api/sandbox). I'll write more
about this in the future, but, briefly, we now restrict the actions the
interpreter can take during the config compilation phase. For instance, only
certain external commands can be executed, and filesystem access is read-only.

I won't pretend the implementation of this change was entirely plane sailing.
Janet's module system is somewhat restrictive (intentionally, I'm sure), and the
documentation is sometimes a little spare. There were also some sharp edges with
dynamic bindings, which didn't behave in the way I expected and forced a bit of
a rethink.

But, the Janet community is very helpful; the source is easy to understand; and
I even ended up adding DTrace probes to Janet's VM to better see what was going
on (blog post to follow!). So I got there in the end.

With the library nicely separated, I had more appetite to improve it. I added
rudimentary type checking and built-in documentation; expanded the DSL; and
cleaned and polished it to a point where it's no longer embarrassing. (Though
I'm still not much of a Lisper.)

I always intended to ship config via images, going right back to the time when I
was going to write Gurp entirely in Janet. It took a whilte to get around to,
and was a bit tricky to get right, but it is a solid and elegant approach which
I feel even more strongly justifies my decision to base Gurp around Janet; a
lovely little language with some powerful and innovative features.

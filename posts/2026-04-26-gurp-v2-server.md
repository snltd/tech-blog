---
title: "Client/Server in Gurp 2.0.0"
date: 2026-04-26
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

In line with [semantic](https://pridever.org/) and
[pride](https://pridever.org/) versioning, v2.0.0 of
[Gurp](https://github.com/snltd/gurp) is ready to go. The
[`HISTORY`](https://raw.githubusercontent.com/snltd/gurp/refs/heads/main/HISTORY.md)
gives you the cold facts, but I want to give my hypothetical users a bit more
context.

## Client/Server Change

Gurp has had client/server mode since version 1.3.0, but it wasn't quite as
useful as it looked.

Briefly, a `gurp apply` has three phases.

1. Turn a user config (Janet), into a struct of Janet resource descriptions.
2. Turn those resource descriptions into a single JSON object.
3. Deserialize the JSON into Rust structs.
4. Ensure that every resource has the spec defined in its struct.

A local `apply` carries out all four phases; pre-2.0.0, client/server performed
1 and 2 on the server, 3 and 4 on the client.

Often, this is fine, but what if the user config contains logic that would yield
different results on the client and the server?

For example here's a role from my Guro setup, which runs in global zones. It
updates Gurp in every NGZ with an `/opt/site/bin` directory.

```janet
(role gurp-in-zones
      (def zone-root "/zones")
      
      (def zone-site-bins
        (->> (os/dir zone-root)    # iterate over entries in /zones
             (map |(pathcat zone-root $ "root/opt/site/bin"))
                                   # build a path to the target dir from each zone name
             (filter os/stat)))    # drop any paths which don't exist

      (loop [dir :in zone-site-bins]
        (file/ensure (pathcat dir "gurp")
                     :from "/path/to/most/up-to-date/gurp"
                     :mode "0755")))
```

Compile that in a global zone with `/zones`, and you'll get some `file/ensure`
resources. Compile it in an NGZ and you'll get an error.

We could, I suppose, serve up the raw config, but that might involve a lot of
dependencies which would need to be worked out, bundled up, sent over the wire,
unbundled to local disk, compiled, applied, cleaned up... No. It would be
horrible.

Oh, and you know what else was a problem in version 1? The Janet DSL library: a
single file, embedded in the `gurp` binary and injected at the top of the user's
config. It was flat, huge, and not nice to work on. But modularising it seemed
impossible because modules would have to `import` their dependencies, and
`import`s make no sense in a flat file. I'd have to somehow Frankenstein the
bits back into a whole... No. It would be horrible.

```cmd
$ cat lib.janet
(def library-says "all is clear")
```

Don't you love it when two apparently unrelated problems have a single, elegant
solution?

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
environment, and added to it a binding and a function. Now watch this:

```cmd
repl:6:> (spit "stored-env.jimage" (make-image (curenv)))
nil
repl:7:> ^D
```

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

We made and, on a different host, reloaded an image file: a compact, portable,
binary representation of a Janet environment. It contains our binding, function,
and, most importantly, the contents of library we loaded. (Because we specified
`:export true` when we imported it.)

I modularised the big library file, greatly improving the clarity and quality of
the code. Now when I `cargo build`, a `build.rs` script pulls all the modules
together into a single image file, ready to be embedded in the binary.

Remember how, at the start of the first REPL, the current environment was empty,
but we could still run functions like `curenv` and `make-image`?

This is because Janet environments _nest_. If a symbol can't be resolved in
`curenv`, it will try the next one down until it hits the root. You can see the
lower envs, if you know where to look:

```cmd
repl:1:> (fiber/getenv (fiber/root))
@{% @{:doc "(% & xs)\n\nReturns the remainder of dividing the first value of xs by each
...
```

So if we put the Gurp library in a lower environment than the user's code, the
DSL functions will be hidden, but available.

Now the client/server phases are:

1. The client requests its config.
1. The server returns a single environment image containing the raw config,
   including any dependencies. _Nothing has yet been executed!_
1. The client starts a Janet interpreter with its embedded library image locaded
   into the root environment, with the config image above it.
1. The client calls the entrypoint in the config image, turning the client
   config resource descriptions into a single JSON object. If it needs to access
   the filesystem, it accesses the _client's_.
1. The client deserializes the JSON into Rust structs.
1. The client ensures that every resource has the spec defined in its struct.

Proper client/server behaviour.

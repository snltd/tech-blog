---
title: "Gurp: Design and Evolution"
date: 2025-06-30
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

## Identities, References, and Labels

Early on, even though I didn't need them, it seemed like a good idea to give
each Gurp resource a unique ID. Resources have a type, as defined by the second
part of the `(ensure/type)` function name, and they must always belong to a
role. They also all have a name, which is the first argument of the `ensure`
call. In the case of users, that's the username; for files it's the file path.
So, I gave every resource an `:_id` key with a value of
`/role/resource-type/resource-name`.

With an easy way to refer to any resource type, I saw an obvious way to use
them. Say you create a user, and you want files to be owned by that user. Rather
than hardcoding the value in two places, or using a Janet `def`, you could have
a reference.

```janet
(role example
  (user/ensure "rob"
    :uid 264
    :primary-group "sysadmin"
    ...)

  (file "/robs/file"
    :owner :/example/user/rob/name
    :group :/example/user/rob/primary-group))
```

References are resolved by the Janet front-end. It can spot circular
dependencies, and also flags up references which\
point nowhere. I also added a `(this)` function, which would let you write the
file above as

```janet
(file "/robs/file"
  :owner (this :user :rob :name)
  :group (this :user :rob :primary-group))
```

The initial reference implementation worked fine until I wanted to refer to
files. The `/` separator I'd chosen didn't play nicely, and nothing else felt
right. So, I converted slashes to underscores in the name part of the reference.
But that meant you could end up with unweildy references like
`:/role/file/_etc_opt_ooce_default_application_config_file.conf/owner`. To make
life easier, I added a new `:label` property. If you write

```janet
(file "/etcome/really/long/path/to/file.conf" :label :my-config)
```

you can refer to it as `(this :file :my-config)`.

## Dependencies

With IDs and labels in place, I spent a lot of time thinking about dependencies.
With all the desired state in Rust data structures, it should be easy to chuck
them into [Petgraph](https://docs.rs/petgraph/latest/petgraph/) and get a proper
dependency graph. But, do I need that? Or even _want_ it?

If we allow the user to add `:before` and/or `:after` properties to resources,
then how do we relate the resources without them? Take the Ansible approach of
ordering as seen? Random? Something else? The more you think about it the more
complicated it gets. I thought about it so much that the project stopped dead. I
needed a decision.

If you can't decide on the details, go with your core principals. I chose to
stay true to my initial, hardcore-minimal, approach, and not crate a graph, but
instead, install resource types in a particular order.

For instance, if directories are created before files, there's no way a file
resource can fail because its parent does not exist. (Assuming said parent is
managed by Gurp.) And given directory creation is `mkdir -p` style, it's
impossible for directories to be created out-of-order. If file-line resources
come after files, the files on which they operate must already exist.

We need to create users before directories, so there's no way we can try
`chown`ing a directory to a not-yet-extant user. Packages can bring in any kind
of resource, but should never depend on anything beyond other packages listed in
their manifests, so they can go first. For removing resources, it's probably
enough to traverse the same list backwards.

So far, it works fine.

### Service Dependencies

Services may need to restarted or reloaded when their config files change. I
decided the cleanest way to do this was to add optional `:restarted-by` and
`:reloaded-by` keys to `(svc/ensure)`. By keeping a list of resources which have
changed, Gurp can very quickly check whether or not to perform a `refresh` or
`restart` when it asserts the state of the service.

## Janet and JSON

When you embed a Janet interpreter in a Rust program, you end up in a function
which receives and returns a `Janet`. This is a multi-purpose wrapper object,
and at some point you have to unpack it and turn the data into Rust structures.

My original approach was to have the front-end "compile" the user configuration
into a single `Janet` holding one big `JanetStruct`. I had functions which
unpacked each resource type into appropriate Rust structures.

This approach gave me complete control. I could check and adjust as needed,
giving exact, clear messages about missing or incorrectly typed fields, and I
liked that a lot. But it all felt wrong, with lots of similar code doing similar
things, but just different enough that I couldn't nicely DRY it up. And whatever
I did, at some point I had to return data across that Janet/Rust boundary, and I
simply could not find a nice way to do that.

I decided I needed weaker coupling between the front and the back. I wanted
Janet to give me a single JSON object, which I could deserialize with Serde. So
I turned my various Janet->Rust functions into a more generic Janet->JSON
machine.

With this new approach, errors became generic, and the whole thing didn't fit
nicely with the shape of my code. I ended up ripping it all out and going back
to the manual unpacking of the Janet struct, which I thought I could streamline
and improve. I very much believe in the old engineering adage that "if it looks
right, it probably is", and the insides of Gurp just didn't look right.

I revisited the JSON approach, but this time I wanted the Janet front-end to
produce the object, so the `Janet -> Janet` function would return a `Janet`
wrapped `String`. this would be clean and simple.

Janet has a utility library called Spork, which includes a great JSON
serializer. But that's written in C and built with JPM, and building that into
my binary would be messy at best. I found a couple of pure Janet JSON libraries,
but neither worked very well. I ended up hacking one of them into shape, and
bundling it in my binary. I did a big refactor, making Serde the centre of the
Universe, and shed about a quarter of the codebase. My errors weren't as good as
before, but I added some lints and checks to the Janet code, catching the
likeliest user errors right at the start. The whole thing felt so much more
_right_.

After a little white I revisited the original Rust JSON encoder, smartened it
up, fixed a couple of edge cases, and replaced the pure Janet version. This
couples the two halves a little more tightly, but I think it's an acceptable
trade-off. I was right the first time.

With the two halves of Gurp decoupled, you could, if you wish, build a different
front-end. And, of course, JSON is a subset of YAML...

## Loops and Stuff

In its first iteration, a Gurp `(role)` produced an array of resources, and all
the `ensure` and `remove`s produced a struct. So

```janet
(role example
  (thing/ensure "abc")
  (thing/ensure "def"))
```

would give you something like

```janet
{:thing {:abc {...} :def {...}}
```

At the end of the run, a `collate` function combined the outputs of all the
roles into `ensure` and `remove` structs.

The problem is,

```janet
(role example
  (loop [name :in ["abc" "def"]]
    (thing/ensure/name)))
```

gave you `{nil}` (because that's what `loop` returns) and a puzzled user show
can't understand why `abc` and `def` are missing from their host.

If you know how Gurp works, you might realise that you can iterate with `map`.
(Or you could once I made Gurp flatten the role's output array.)

```janet
(map |(thing/ensure $) ["abc" "def"])
```

But that puts a burden on the user, and breaks the fourth wall of the DSL. I
didn't like it.

My next approach was to define a `collector` array in the role macro, and give
the user an `add` macro which appends its resources to `collector`. You'd write

```janet
(role example
  (loop [name :in ["abc" "def"]]
    (add thing/ensure/name)))
```

This reminded me of those pretend loops you get in things like Ansible and HCL,
and actually felt worse than using `map`. Eventually and inevitably, with `add`
being a macro, I even hit a weird edge case behaviour that gave incorrect
results.

I played with various approaches using dynamic bindings, and even channels
between "collector" and "aggregator" fibers, but all my solutions felt flaky, or
burdened the user. The subtler the approaches got, the further they felt from
being "right". Then one morning, the junior developer in me woke up and shouted
"GLOBAL VARIABLE". And, I think, he was right.

Now, at the top of the Gurp library, I define a `*collector*` struct with
`:ensure` and `:remove` structs inside it, holding arrays for each resource
type. Every `(ensure)` and `(remove)` call appends its resource to the right
array in the collector, so no complicated collation is required, and it makes no
difference if function is called inside a loop.

I'm no happier with mutable global state than you are, and I tried everything I
could to avoid it. Maybe, as I get a deeper understanding of Janet, I'll come up
with a functional approach that's as boilerplate-free, and that would make me
happy.

But, we have to balance good taste with practicality. Using a single global
state is extremely simple. It suits a very clean and thin DSL. And because every
Gurp operation is a single-threaded one-and-done, there's nothing to cause
unexpected behaviour. We simply append to lists, then pass the results to Rust
and shut down the Janet interpreter. I can live with myself for that, can't I?

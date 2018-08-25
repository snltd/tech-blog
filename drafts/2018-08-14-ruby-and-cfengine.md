---
title: "The Day I Made a Ruby Package Module for CfEngine"
date: "2018-06-01"
tags: [cfEngine, Ruby, "config management"]
layout: post
category: config management
---

## Ancient History

I first ran into CfEngine in, I think, 1998. I was running about
twenty servers and fifty workstations, nearly all Solaris, with a
couple of SunOS 4 stragglers. My manager got me to evaluate it as an
alternative to the Jumpstart setup we were using.

For reasons I no longer remember, I didn't "get" CfEngine. I
probably felt it solved a problem we didn't really have. Our servers
were all locked down incredibly tightly: just two of us could log on
to them, and we never did. Our lab workstations were completely
rebuilt every night with Jumpstart, and the staff insisted on fully
owning -- with root privileges -- their own workstations, and
generally lost their shit if we touched them. (We had some laughs
with that. It's how I learnt how to break into things, and I must
tell you some time about how one of the academics deleted everyone's
email because he didn't understand NFS.)

Anyway, I didn't run into configuration management again (unless you
count Jumpstart, at which I became something of an expert) for about
fifteen years, when I went to work on a Chef site. Since then I've
done a fair bit of Puppet and flirted with Ansible, and they all
seemed somehow unsatisfactory. I vaguely remembered the rigourous
"correctness", and speed, of CfEngine, and I thought I'd revisit it.

## Making it Work

I got a book ('cos I'm old and don't like screens) and learnt me a
bit of CfEngine. It's an odd old thing, walking a tightrope of
efficient elegance above a crevasse of incomprehensible terseness.
It feels "proper", but it also feels "old". Not necessarily "old" in
the way that Perl feels old; more like a decent wind-up watch, or a
Garrard 301.

As I choose to live in the increasingly ghettoised world of SmartOS
and Solaris, I had to build a modern version (3.10.4) myself, and
throw in an [additional
module](https://github.com/bahamat/cfengine-smartos-metadata) to get
at SmartOS metadata. The build is pretty simple, and I hacked up [a
quick script to build me a package
on-demand](https://github.com/snltd/smartos-gubbins/blob/master/packagers/package_cfengine/build_cfengine.sh).

Solarish integration isn't bad out-of-the-box, but CfEngine is not
so thick a layer of abstraction as, say, Puppet, and the odd thing
is missing. Off the top of my head I remember having edit files "by
hand" to give my user elevated RBAC privileges, whereas Puppet's
`user` resource exposes nice `roles` and `profiles` attributes.

Still, even learning the language and its idioms as I went,  it
didn't take me long to get CfEngine doing 90% of what I do with
Puppet. (But in considerably less than 90% of the run-time.)

My sticking point was Ruby. I use quite a few gems, and I was
surprised to find that CfEngine didn't have a clue what to do with
them.

At first I thought I was doing something wrong. Ruby's been around
twenty-odd years now, and it's not exactly exotic. So I checked. In
a CfEngine `packages` promises, you can supply a `package_module`
parameter, which specifies handler for the package. Looking at the
modules shipped in the [release
masterfiles](https://github.com/cfengine/masterfiles/tree/master/modules/packages)
there surely isn't one which does gems. I had a quick search, but I
couldn't find anything. No problem, I thought, there is [plenty of
documentation](https://docs.cfengine.com/docs/3.10/reference-package_modules.html),
I'll write one myself. It'll be fun.

Probem is, it turned out not to be quite as simple as I thought,
requiring a fair bit of filling-in-the-blanks. I hope that this
document makes the task a little easier for the next person who does
it.

## How It Works

A package module is an executable which CfEngine executes. It must
respond correctly to a number of specific arguments, and communicates
with `cf-agent` over stdin/stdout.

A module may be written in any language the host can understand
and, as mine was going to install Ruby gems, I thought it was not
unreasonable to write it in Ruby. Admittedly, the overhead of Ruby
is greater than, say, `ksh` or `bash`, but I felt the task would be
complicated enough without having to deal with acres of `sed`dage
and `${GLOBAL_VARIABLES}`.

The [package module
documentation](https://docs.cfengine.com/docs/3.10/reference-package_modules.html)
not only explains the arguments that your module script must handle,
but gives you little snippets of input which which to test your
progress. This was helpful. What it doesn't tell you, at least not
clearly, is exactly how CfEngine interacts with your module. I had
to work a lot of that out with `puts` debugging. (If your module
writes to standard error and you run `cf-agent` in debug mode, you
will see your messages prefixed with `[TRACE]`.)

Let's consider a promise like this:

```
packages:
  'wavefront-cli'
    policy         => 'present',
    version        => '2.6.0',
    options        => { '--no-rdoc', '--no-ri' },
    architecture   => 'ruby',
    package_module => ruby;
```

In real life, I wouldn't bother with the `architecture` parameter:
I've never seen a Ruby gem be anything other than `ruby`. But it's
here for completeness.

When `cf-agent` tries to fulfill this promise, it will call the
`ruby` module multiple times.

1. With the argument `supports-api-version`. The module must
   print `1` to stdout, and exit.
2. With the argument `get-package-data`. Information about the
   required package is streamed to the module via stdin, which must
   accept it and parse it. It looks something like this, though only
   `File` is mandatory.

   ```
   File=wavefront-cli
   Version=2.6.0
   Architecture=ruby
   ```

   The module must pass the following back to CfEngine over stdout.

   ```
   PackageType=repo
   Name=wavefront-cli
   ```

   If the value of `File` looks like it really is file, (I chose to
   decide it did if it contained `File::Sepataror`) then
   `PackageType` would be `file`, and you have to work out the name,
   version and architecture from the value of `File`. In my case,
   these go into a `Struct` similar to the one the
   `Gem::` methods use when they talk about a gem. A limitiation:
   you can't force a gem to be uninstalled if you give a local path.
   CfEngine seems not to be able to use the triplet returned here to
   work that out.

   The module gets to see the `options` parameter here, if there is
   one. Should it be present, and include a `--source=` option, I
   memo the source to disk. You'll see why in a minute.

3. The third call to the module is with the single argument
   `list-installed`. Here CfEngine is expecting to be told, over
   stdout, the name, version, and architecture of every installed
   package for which the module is responsible. In this case, every gem.
   So the module must emit something like this, for each installed
   gem.

   ```
   Name=gem-name
   Version=x.y.z
   Architecture=ruby
   ```

   To do this I now use the Ruby `Gem` module directly, massaging
   the output of `Gem::Specification.find_all` rather than shelling
   out to the `gem` command. CfEngine is fast and lean, and I
   wanted my provider to be as fast and lean as I could make it.

   If the required gem is in the list of triples it receives back
   from the module, CfEngine considers the promise kept, and will
   not call the module again for this gem.

4. If the gem isn't installed, CfEngine calls the module for a
   fourth time, with the `list-updates` update. Nothing goes to
   stdin. This is where I found the documentation confusing.

   > This command is expected to return a list of all the
   > available updates for currently installed updates.

   Okay. Let's assume that second "updates" means "packages". But
   say we've got 1.0.0 of a gem installed, and 1.0.1 and 1.1.0 are
   both up on rubygems.org. Does CfEngine need to know about them
   both? Or just the latest? I opted for "just the latest", on the
   assumption that this information will be used by packages which
   track `latest`. I'm still not sure whether I'm right or not.
   `list-updates` is called even if you specify a package version,
   so maybe I'm not.

   The docs do make it clear, though, that the module's
   output should be a similar list of triplets to that in step 2.

   As I said in step 3, I was mindful of resource consumption. So,
   as I developed the module, I monitored the memory it used, and
   compared it to that used by the minimal `pkgsrc` module, which is
   written in shell. It all looked fine, until I implemented
   `list-updates`, using a `system()` call to `gem outdated`. I was
   developing in a SmartOS zone with 256Mb of RAM, and CfEngine fell
   over with:

   ```
   [FATAL] failed to allocate memory
      error: Error installing package 'wavefront-cli'
   ```

   CfEngine barely uses any memory at all. So what the heck was
   going on?

   ```cmd
   $ time -v gem outdated
   ...
       Command being timed: "gem outdated"
       User time (seconds): 2.14
       System time (seconds): 0.14
       Percent of CPU this job got: 57%
       Elapsed (wall clock) time (h:mm:ss or m:ss): 0:03.98
       Average shared text size (kbytes): 0
       Average unshared data size (kbytes): 0
       Average stack size (kbytes): 0
       Average total size (kbytes): 0
       Maximum resident set size (kbytes): 214016
    ```

   There you go. `gem outdated` uses all the memory on my host. I
   had a dig in [the
   source](https://github.com/rubygems/rubygems/blob/b8fd4614645851607cddf6c65040652505ef0cbb/lib/rubygems/specification.rb#L1203-L1204)

   ```
   # Return a list of all outdated local gem names.  This method is HEAVY
   # as it must go fetch specifications from the server.
   ```

   You're not kidding. This was the point at which I decided not to
   shell out to `gem` for everything.  I went back to the previous
   methods and swapped the `%[x gem...]` type things for `Gem::`
   calls. But even using the `Gem` class natively, I couldn't make
   this work any better. I found myself calling the same methods
   (`Gem::SpecFetcher.fetcher.available_specs`)
   with the same demands. A different approach was required.

   Rubygems [has an
   API](https://guides.rubygems.org/rubygems-org-api/) which can
   give you the latest version of any given gem for the cost of a
   single call. I felt it would be far better to iterate over the
   installed gems and get the latest version of each one from the
   API. It can take a little while if you have a lot of gems, but it
   won't suddenly gulp down a quarter of a gigabyte of memory. I
   haven't measured, but I assume it'll take significantly less
   network traffic too, and I am so old-world that I actually care
   about stuff like that. If you have a thousand gems installed (I'm
   looking at you, `aws-sdk` version 3), this might be prohibitively
   slow. We'll see.

   A gem repo has no obligation to provide an API and as yet I
   haven't run into another that does. So, if the gem's
   source is not `rubygems.org`, I use the same method `gem
   outdated` does. I don't think this will consume inordinate
   amounts of memory on the average private repo.

   The problem is, *we don't know the source*. Remember, I said
   *nothing goes to stdin* on this invocation of the module. So that
   means we can't see the options, so we don't know the source, or
   even the gem name for which we need to find updates. That's why
   we wrote it down in step 2, when we *did* know the source, and we
   retrieve it here.

   I don't like writing temp files, and I *really* don't like
   writing temp files with predictable names, but I don't see a way
   around it in this case. I do my best to make it safe, having
   CfEngine (which runs as root) create a directory based on its
   PID, readable only by root. If you can modify the contents of
   that, you can do anything anyway. If the module finds there's
   already a file with the name it intends to write, it won't do it,
   just in case some chump has managed to link it to `/etc/shadow`
   or something.

   There's a further confusion with `list-updates`, in its
   companion `list-updates-local` argument. The former goes out and
   etches a list of available updates off the network. The latter
   returns a locally cached version. This fits a system like `apt`,
   which stores a cache of exactly what's out there, and has an
   `update` command which refreshes that cash. But gems don't work
   like that.  Every call to install something goes out and finds
   whether the thing exists.

5.  Called with the argument `repo-install`. This, obviously, does
    installs the gem
   I'm not sure whether I'm not doing someth


   I hit some serious frustration with packages installing
   successfully, but CfEngine throwing this error.

   ```
   error: Error installing package 'wavefront-cli'
   ```

   Digging in the `--verbose` output (CfEngine's logs and errors are
   pretty good, [unlike some competitors I could
   mention](https://daily-devops.tumblr.com/post/162863742721/malbolge-was-specifically-designed-to-be-almost)
   I found this:

   ```
   info: Caught unsupported error info: Successfully installed wavefront-cli-2.4.0
   info: Caught unsupported error info: 1 gem installed
     error: Error installing package 'wavefront-cli'
   ```

   It seems that CfEngine treats any unsolicited output as something
   trying to talk to it. So I had to direct the output of `gem
   install` to `/dev/null`.


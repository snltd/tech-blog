---
title: "OmniOS - Broken Puppet"
date: 2021-06-23
tags: [OmniOS, Puppet, Ruby]
category: OmniOS
---

I was deploying some OmniOS zones, using a mechanism I've used a thousand times
before, and the initial Puppet runs all failed with

```
Info: Loading facts
Info: Caching catalog for cube-mariadb.localnet
Info: Applying configuration version '1624443968'
Error: Could not prefetch package provider 'pkg': Unknown format pkg: im-[m]
Error: Failed to apply catalog: Unknown format pkg: im-[m]
```

This being Puppet, the error message isn't the clearest, and running the agent
with `--debug` didn't show me anything obvious.

But it's Ruby, so it's easy to `grep` for the error message on the
failing system, and a couple of minutes of `printf` debugging later, I'd
tracked it down to [this
block](https://github.com/puppetlabs/puppet/blob/c28e71c38d26c17b580d9eb672733e67a79a17c7/lib/puppet/provider/package/pkg.rb#L50-L57)

```ruby
case flags[1..1]
    when 'f'
      {:mark => :hold}
    when '-'
      {}
    else
      raise ArgumentError, _('Unknown format %{resource_name}: %{full_flags}[%{bad_flag}]') %
          { resource_name: self.name, full_flags: flags, bad_flag: flags[1..1] }
    end
```

At this point Puppet is inspecting the `IFO` column in the output of `pkg list`,
and it expects the second character of that column to be an `f` or a `-`. But
in the errant OmniOS zone, I see stuff like this:

```
NAME (PUBLISHER)                                  VERSION                    IFO
ooce/database/mariadb-105 (extra.omnios)          10.5.10-151038.0           im-
ooce/runtime/ruby-26 (extra.omnios)               2.6.7-151038.0             im-
```

I vaguely remembered seeing something about `pkg` changes in the OmniOS r151038
release notes, and a quick search yielded
[this](https://github.com/omniosorg/omnios-build/blob/r151038/doc/ReleaseNotes.md#commands-and-command-options):

> -m shows packages which were manually installed, that is explicitly provided as
> arguments to a pkg install command. Manually installed packages show an m in
> the flags column.

Now the error makes sense, even if the wording made it a little cryptic at
first. Perhaps I was unfair.

So there's a new flag in the IFO column, and Puppet doesn't know how to deal
with it. Options?

You can remove the 'm' flag with the `pkg flag` command,

```cmd
# pkg list -H shell/zsh
shell/zsh                                         5.8-151038.0               im-
# pkg flag -M shell/zsh
Updating package state database                 Done
Updating image state                            Done
1 package updated.
# pkg list -H shell/zsh
shell/zsh                                         5.8-151038.0               i--
```

but I can't see an elegant way to fix the problem with that. There are other
new flag values too, and I think they all provide useful info, so muting them
is off the agenda.

The only solution is to educate Puppet.

I understand why the author wrote the code so defensively. It's better to say
"I don't know" than to wade in and do the wrong thing. (As true in life as in
code.) But, I see no reason why Puppet should care about the any of the new
flags, at least not with its current feature set.[^1]

To have Puppet ignore the new flags, just like it always ignored the `-`, we
only have to change that `when` statement to

```ruby
when '-', 'm', 'M', 'r', 'R'
```

The fix was easy, but deploying the fix is harder. I don't want to do
something long-winded, like building and deploying a forked gem; or doing
something awful like `sed`ding the stock gem after it's installed.

Ideally, of course, I'd like to get a proper fix back into the official
distribution. But even if I managed to do that, I use Puppet 5, which is two
major version numbers out of date now, and I have no idea at all how Puppet
deal with backporting fixes. More importantly, I need if fixed *now* because I
can't build new zones.

My Puppet master already exports [a fork of Oracle's Solaris
providers](https://github.com/snltd/puppet-solaris_providers), with a few
tweaks for Illumos, and my first thought was to copy a modified version of the
provider into there, hoping that the master's version of the provider would
be preferred to the clients. So I did, and it wasn't. Then I spent a good
while trying to coax it into that behaviour with `modulepath`, again without
success.

Eventually I went to [the Puppet community Slack](https://slack.puppet.com/)
and a couple of very helpful people there explained that because the `pkg`
provider is a "built in", if Puppet finds other versions of it, they will
*always* be ignored in favour of the bundled one. It was also suggested I
subclass the `pkg` provider, and use my site manifest to tell the OmniOS
clients to use it, and that's exactly what I did.

This file is
`/opt/local/etc/puppetlabs/code/modules/solaris_providers/lib/puppet/provider/package/oopkg.rb`
on my master.  I inherit from the existing `pkg` provider, and override that
one troublesome method.

```ruby
require 'puppet/provider/package'

Puppet::Type.type(:package).provide :oopkg, :parent => Puppet::Type.type(:package).provider(:pkg) do
  def self.ifo_flag(flags)
    (
      case flags[0..0]
      when 'i'
        {:status => 'installed'}
      when '-'
        {:status => 'known'}
      else
        raise ArgumentError, _('Unknown format %{resource_name}: %{full_flags}[%{bad_flag}]') %
            { resource_name: self.name, full_flags: flags, bad_flag: flags[0..0] }
      end
    ).merge(
      case flags[1..1]
      when 'f'
        {:ensure => 'held'}
      when '-', 'm', 'M', 'r', 'R'
        {}
      else
        raise ArgumentError, _('Unknown format %{resource_name}: %{full_flags}[%{bad_flag}]') %
            { resource_name: self.name, full_flags: flags, bad_flag: flags[1..1] }
      end
    )
  end
end
```

To use the new `oopkg` provider, I put this in my `site.pp`

```puppet
if $facts['os']['name'] == 'OmniOS' {
  Package {
    provider => 'oopkg'
  }
}
```

I intend to send Puppet a proper patch to deal with the new OmniOS features,
but I needed a "right now" fix, and I think the one I ended up with wasn't
*too* messy.

Enough. I have zones to build.

[^1]: I suppose we could have Puppet refuse to remove `M` flagged packages,
      which are implicitly fulfilled dependencies, but I don't think even that
      would be a particularly useful feature.

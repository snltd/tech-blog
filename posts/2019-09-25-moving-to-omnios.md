---
title: "Moving to OmniOS 01: The Global Zone"
date: 2019-09-25
tags: [Solaris, OmniOS]
layout: post
category: OS
---

> In the beginning was the word and the word was Solaris. And Sun did free its
> source, and Solaris begat OpenSolaris and happiness reigned. Yet a darkness
> spread over the world and Oracle seized Solaris and the people fled.
> OpenSolaris begat Illumos, and was imprisoned for its sin. Solaris lived
> in chains in a distant land, while Illumos begat SmartOS and OmniOS, and yet
> more progeny whose names are lost. Though their fathers lay slain by giants,
> these mighty works live on, revealing their secrets to the enlightened.

## The Setup

I have computers at home, and for reasons I cannot explain, it's somehow
important to me that those computers print `SunOS` when I run `uname -s`.

It's a kind of religious thing, and I don't expect anyone to understand.

I no longer run a Solaris desktop, but it's still on my fileserver. I have a
lot of clients' data on there and I need encryption at rest, so I had to stick
with "proper" Oracle Solaris.

Crypto was added to ZFS after Oracle re-closed the Solaris source, so it's
never been available in any of the open source Illumos distributions.  But now
the OpenZFS project has it too, and it's been merged into Illumos. So it looks
like I can finally junk that last, unpatched, unsupported, Solaris box and
migrate to something more libertarian.

If I had any sense I'd move to Linux or FreeBSD, but I don't.  I'm a glutton
for punishment, and I have this inexplicable devotion to one particular
kernel, so I'm installing the Community edition of
[OmniOS](https://omniosce.org/).

## The Plan

`cube` is my Solaris server, named for its shape. It runs about twenty zones
doing all manner of things, though its main responsibility is a file/media
server. Right now it runs Solaris, and it's going to be rebuilt with OmniOS.
It's fully config-managed, and I have my own tooling to deploy and redeploy
zones in seconds with a single command.

`tornado` (`shark` died) is my SmartOS box. SmartOS has been my development
platform for a few years, as I deploy to the Joyent Public Cloud, and like
that homogeneity. But the JPC is being turned off next month, so `tornado` is
redundant. Much as I like SmartOS, it's very datacentre focussed, and not the
ideal home computer OS, so I'm not sticking with it.

I plan to install OmniOS on `tornado`, and duplicate as much of `cube`'s
functionality as possible, building everything with the Puppet code which
already builds the zones on `cube`. When that's all done, I'll reinstall
`cube` with OmniOS and play the config into it, and `tornado` can go back on
eBay, from whence it came.

## The Snags

I expect these things are going to be an issue.

* ZFS. I have a lot of data on Solaris zpools, which cannot be imported into
  OmniOS. We're going to need a bigger `rsync`. I know there are features in
  Solaris' ZFS that OmniOS does not have, but we'll see if they are any of the
  ones I use.
* RBAC. I'm very big on minimal-privilege, and RBAC has changed over the
  last few Solaris releases. I'm expecting to run into a couple of issues.
* Puppet. Solaris 11.4 has pretty nice Puppet integration. Things shoud still
  work once Puppet's up and running, but I may have to do some heavy lifting
  to get to that point.
* IPS. It's a matter of public record that I do not like IPS. I find it
  overcomplicated and slow. I also find it so tiresome to package my own
  software that I tend to use the old SYSV tooling to deploy stuff to my own
  Solaris hosts. I have tooling to build `pkgsrc` packages for my SmartOS
  zones, which presumably will need migrating.
* Applications. Initial `pkg search` experiments show quite a lot of things I
  hoped would be there are not.
* NFS. I use a couple of zones on different subnets to serve up NFS content.
  As far as I know, Illumos derivatives can't run NFS servers in non-global
  zones.

## The Installation

Couldn't be easier.

OmniOS offers two release paths. **Stable** is, well, stable, including LTS
releases. **Bloody** is the experimental "beta" release. I guess it's not
quite fully cooked.

I need ZFS crypto, which hasn't hit stable yet, so I
[downloaded](https://omniosce.org/download.html) bloody, `dd`-ed it to a USB
stick and booted `tornado`.

OmniOS's *Kayak* the nicest manual installer I've used. It's super quick,
console-based, and constantly offers you the option to drop out to a shell and
do whatever you might need to do. I was particularly happy about the
flexibility of *where* to install the OS, having been frustrated too many
times by "whole disk or nothing" installers. Blatting the root zpool onto disk
takes less than ten seconds, and post-install config of networking and a
`pfexec`-enabled admin user didn't take much longer. Five minute job. Lovely.

By the time I've finished working all of this out, the crypto stuff will be in
stable, and I'll rebuild everything on that. I'm big on stability.

## The Configuration

I had a nice Puppet setup for my Solaris and SmartOS boxes. So it should be
simple to have Puppet configure OmniOS exactly the way it configured Solaris.
BUT!

```cmd
$ pkg search puppet
$
```

Looks like we'll have to do this ourselves. Have we at least got Ruby?

```cmd
$ pkg search mediator:ruby
INDEX      ACTION VALUE PACKAGE
mediator   link   ruby  pkg:/ooce/runtime/ruby-26@2.6.5-151033.0
mediator   link   ruby  pkg:/ooce/runtime/ruby-25@2.5.7-151033.0
```

Phew. If you didn't know, "mediators" are how IPS lets you install different
versions of a package side-by-side. I could install both those versions of
Ruby, and flip between them by changing the mediator.

Even from the first couple of commands, `pkg` felt quicker on OmniOS than it
does on Solaris. To stop everyday operations being annoyingly slow, OmniOS
keeps only essential packages in its default repo. (Or, to be more correct
default "publisher".) Ruby is not in there, because most people probably won't
want it. It's in "extra". You can choose to have the extra publisher enabled
as a post-installation option in Kayak, or add it at any time like this:

```cmd
$ pfexec pkg set-publisher -g https://pkg.omniosce.org/bloody/extra/ extra.omnios
```

`pkg publisher` will show you which repos are in your search path.

```cmd
$ pkg publisher
omnios                      origin   online F https://pkg.omniosce.org/bloody/core/
extra.omnios                origin   online F https://pkg.omniosce.org/bloody/extra/
```

There isn't even that much stuff in extra, and I like that. OmniOS knows what
it is: a server operating system. There's more in the repo than core OS
packages, but the tools have been chosen with care. What you *need* is likely
there, but what you *want* might not be.

Anyway, I want Ruby, so let's install it.

```cmd
$ pfexec pkg install pkg:/ooce/runtime/ruby-26@2.6.5-151033.0
           Packages to install:  1
           Mediators to change:  1
       Create boot environment: No
Create backup boot environment: No
$ which ruby
/opt/ooce/bin/ruby
```

I'd have preferred it in `/usr`, but never mind. I stuck `/opt/ooce/bin` in
the `PATH` by editing `/etc/skel/.profile` and moved on. We'll make sure that
gets Puppetted later.

To minimize friction, I'll install the same version of Puppet that I have on
Solaris. I'll also tell `gem` not to install RubyDoc documentation, and to put
its executables in the same place as the `ruby` binary. (I thought it would do
this automatically, but it did not.)

```cmd
$ pfexec gem install puppet -v 5.5.0 --no-document --bindir=/opt/ooce/bin
...
Successfully installed puppet-5.5.0
6 gems installed
$ puppet --version
5.5.0
$ facter operatingsystem
OmniOS
```

I already have a Puppet server, and my internal DNS resolves `puppet` to it.
Let's see what happens.

```cmd
$ ping puppet
puppet is alive
$ pfexec puppet agent -t
Info: Creating a new SSL key for tornado.localnet
...
Info: Loading facts
Error: Could not retrieve catalog from remote server: Error 500 on SERVER:
...
```

Not bad! It's talked to the server, done key exchange, and at least *tried* to
run the code. I didn't expect it to work, because OmniOS is not Solaris, and
though I have a `os/Solaris.yaml` in my Hiera config, I do not have an
`os/OmniOS.yaml`. So I copied the former to the latter and ran Puppet again.
It ran, with a few errors. First:

```
ERROR: Puppet Management is not a valid profile name.
```

I said there'd probably be RBAC problems, and here's the first one. That
profile only exists in Solaris. In fact, I think it only exists in Solaris
11.4. Let's drop it. We can, I suppose, build it into OmniOS's profile
list should we require it later, but we probably won't. For now, at least,
I'll be using the `Primary Administrator` role, which lets me do anything as
root simply by prefixing a command wich `pfexec`. (Oracle have removed
`Primary Administrator` from Solaris; a decision which initially annoyed be
greatly, but which I now think was probably wise.)

The next twenty or so errors were:

```
pkg install: The following packages all deliver file actions to usr/share/man/man1m/ntptime.1m:
pkg://omnios/service/network/ntp@4.2.8.13,5.11-151031.0:20190919T120003Z
pkg://omnios/service/network/ntpsec@1.1.7,5.11-151031.0:20190919T115848Z
```

I've seen this package conflict mentioned in the OmniOS release notes. It was
coming from the Puppetlabs NTP module, which was making a best-guess at this
being a Solaris system. I made an OmniOS-specific call to the `ntp` class, and
included the following lines.

```puppet
service_name => 'svc:/network/ntp:default',
package_name => ['pkg:/service/network/ntpsec'],
```

Fixt!

The next error reminds us that Puppet is only a fancy way to run shell
scripts.

```
Error: Failed to apply catalog: Execution of '/usr/bin/svcprop -a -f *'
returned 2: /usr/bin/svcprop: illegal option -- a
Usage: svcprop [-fqtv] [-C | -c | -s snapshot] [-z zone] [-p [name/]name]...
         {FMRI | pattern}...
       svcprop -w [-fqtv] [-z zone] [-p [name/]name] {FMRI | pattern}
```

I use a fork of [Oracle's Solaris Puppet
module](https://github.com/oracle/puppet-solaris_providers), and it (not
unreasonably) assumes "proper" Solaris. OmniOS's `svcprop`, as you see, does
not have the `-a` flag, because that relates to service templates, and they
came from Oracle after the fork. (They're rather nice, and it's a shame to
lose them.)

The fix for this is a bit of logic in `lib/puppet/provider/svccfg/solaris.rb`.
I made a new method to quickly check the distribution:

```ruby
def self.illumos?
  IO.read('/etc/release') =~ /Solaris/ ? false : true
end
```

Then added an `if` clause to call `svcprop` without the `-a` on Illumos.

The final error was:

```
Error: Could not find a suitable provider for process_scheduler
```

`process_scheduler` is a very simple provider, again from Oracle, which uses
`dispadmin` to set the scheduler. I always set the scheduler to FSS on boxes
with zones. The problem is in
`lib/puppet/provider/process_scheduler/solaris.rb`:

```ruby
confine :operatingsystem => [:solaris]
```

I changed that to

```ruby
confine :operatingsystem => [:solaris, :omnios]
```

and my run completed. Hurrah!  All my internal networking, users, security
policies, automatic snapshotting, and various sundries, configured just how I
like them. Oh, and look at this:

```cmd
$ svcs | grep sysdef
online         15:33:18 svc:/sysdef/puppet:default
online         15:33:23 svc:/sysdef/cron_monitor:default
online         15:33:26 svc:/sysdef/diamond:default
```

I've already been down a similar path on SmartOS, and my Puppet config
contains an SMF manifest and `puppet.conf` suitable for that OS. So we have a
running Puppet agent, with a correctly configured interval and splay. (I just
had to change `/opt/local` for `/opt/ooce` in a couple of places.)

We also have telemetry, from my Solaris [Diamond
fork](/post/2016-04-19-diamond-solaris) and [my cron-job
monitor](/post/2019-02-14-monitoring-cron), and to prove it, here's the CPU
usage on this box and the one it will eventually replace. The spikes are
Puppet runs.

<script src="https://metrics.wavefront.com/embedded/qzBZnCH7mh/js"
id="wavefront-embedded-qzBZnCH7mh" width="700" height="300"></script>

I even started getting alerts from [my telemetry
system](https://www.wavefront.com/), because snapshots weren't being created,
on account of me not yet having migrated any ZFS datasets!

So that's the global zone built and config-managed, with telemetry and
alerting, all ready to be carved up into the zones which will host the
applications. Didn't take a lot of effort really, did it?

Next time: zones.

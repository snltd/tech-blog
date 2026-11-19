---
title: "Moving to OmniOS 02: Zones"
date: 2019-10-15
tags: [Solaris, OmniOS, zones, Ruby]
layout: post
category: OS
---

Following on from [last time](/post/2019-09-25-moving-to-omnios), I need to
migrate twenty-plus zones from a mix of Solaris 11 and SmartOS to my new
OmniOS machine. The Solaris zones are defined in Puppet, the SmartOS ones as
`vmadm` JSON files. The configuration of the operating system inside the zone
is done by Puppet in both cases.

One of my big beefs with Solaris 11 was that, because of IPS, it took Solaris
10's lightweight zone management, and made it heavy and slow. 10 used what we
called "sparse" zones, where filesystems like `/usr` were linked from the
global zone. This meant there was little to install, and patching the global
patched the locals. (You could also install "whole root" zones if you needed
more control, but they took quite a bit longer and had to be patched
independently. Avoiding using them, usually by way of loopback mounts, became
something of an art.)

In 11, Sun made zones much more flexible, but at a cost. Zones were installed
by adding packages to a fresh ZFS dataset: "sparse" mode was no longer a
thing, and spinning up a zone -- particularly if it was the first one on a
system and you didn't have a local package repo -- took ages.

The solution to this was to start off not with an empty ZFS dataset, but
with a clone of a pre-built zone. This, made zone creation much, much faster,
and, in days when such things still mattered, saved a lot of disk space.
On my Solaris 11 box I had a shell script which spun up a "golden zone", and
dropped into it a fully configured Puppet. Then, in the global zone's
Puppet config, I defined the local zones. Each time Puppet ran, it ensured
that the right zones existed.

OmniOS tries to combine the best of the Solaris 10 and Solaris 11 worlds. It
still uses IPS and ZFS, but it brings back sparse-root zones with the `sparse`
brand, and offers as its default `lipkg` (linked ipkg) which shares less
global-zone directories with the local zone than `sparse` does. You can also
install a full-fat `ipkg` zone, which works in the same way as Solaris 11 and,
of course, you can still clone an `ipkg` zone from a golden image.

You can also run Linux if you like, by way of KVM or Bhyve emulation, or using
lx brand zones, which use system-call translation. But I don't use those, so
they won't get discussed here.

## Puppet?

I was pretty certain that the Puppet zone building code wouldn't work in
OmniOS without some modification, but I didn't bother checking. Though it was
a simple thing to do, and felt "correct", I was never overly keen on building
the zones via Puppet, preferring the SmartOS way of defining the zone in a
file and running a one-shot script which built it.

## Oozone!

Lots of people have already come up with a way of doing exactly that. (I knew
about `vmadm`, I've since found `zcage`, `zap`, and `zadm`). But I happened to
have a Ruby programming interview coming up, so to sharpen myself a little, I
decided to reinvent the wheel and write a Ruby imitation of SmartOS's `vmadm`.
Or, at least, the bits of it I needed.

Originally I called it `ozone`, but there was already a gem called that, and
there are two 'o's in 'OmniOS', so I renamed it `oozone`. I like to use a
rising inflection on the long 'oo', sort of like you're pleasantly surprised,
but feel free to make that initial syllable annoyed, owl-ish, or comically
erotic. That's the beauty of open source. It's up to you.

I appreciate that Ruby is not a native OmniOS thing. Python is there (for
`pkg(5)`, and Perl is there (for `intrd` -- I was sure we'd been weaned off
the Perl dependency, though maybe that was just SmartOS). But I'm using Puppet,
so I have to have Ruby on there.

`oozone` is [on Github](https://github.com/snltd/oozone), along with some
documentation. In short, you define a zone as a YAML file (people can't get
enough YAML), including all the things `zonecfg(1m)` requires, and a bunch of
"special" things that `oozone` understands. Then you run the script with one
or more of those files as arguments, and it builds you the zones. It will
create any dependent ZFS datasets; configures the zone's DNS settings; and
runs commands once the zone is up. It will also upload files or install
packages prior to running those commands, so it's easy for me to bootstrap
Puppet. Here's a sample zone configuration.

```yaml
---
brand: lipkg
zonepath: /zones/mariadb
autoboot: true
net:
  - physical: mariadb_net0
    'global-nic': auto
    allowed-address: 192.168.1.152/24
    'defrouter': 192.168.1.1
dataset:
  - name: fast/zone/mariadb
dns:
  domain: localnet
  nameserver:
    - 192.168.1.26
    - 192.168.1.1
facts:
  role: mariadb
  environment: lab
packages:
  - 'ooce/runtime/ruby-26'
run_cmd:
  - '/opt/ooce/bin/gem install puppet -v 5.5.17 --no-document
  - '/opt/ooce/bin/puppet agent -t'
```

Note the `facts` hash. That gets converted into Puppet facts inside the zone.
If you add facts `oozone` drops in a free `zbrand` fact, which is helpful
if you only need to perform certain operations for certain zone types.

## Everything Was Better in the Old Days

For a "dead" operating system, Solaris 11 has been acquiring features at a
fair old rate, and there are some zone-related ones that I miss.

### Datasets aren't Pools

First, OmniOS's ZFS dataset handling isn't quite as nice. In Solaris 11 you
get to give the dataset a name, and it appears in the local zone as a pool
with that name.  I always call mine `local`, and it gives me a lovely clear
way of handling zone data.

```cmd
$ zpool list
NAME   SIZE  ALLOC   FREE  CAP  DEDUP  HEALTH  ALTROOT
local  224G   124G  99.8G  55%  1.00x  ONLINE  -
rpool  199G  47.5G   152G  23%  1.00x  ONLINE  -
```

In OmniOS, the dataset appears as itself:

```cmd
$ zfs list rpool/zonedata/mariadb
NAME                     USED  AVAIL  REFER  MOUNTPOINT
rpool/zonedata/mariadb   168K   440G    24K  none
```

Though the two are functionally identical, I prefer the Solaris way of
doing it. Having dedicated pools makes the zone feel more like a "real"
computer.  The lack of the distinct pool broke a lot of my Puppet config too,
but it was easy enough to fix.

### Zones aren't Services

Another nice Solaris feature is that as of 11.4, individual zones map to SMF
services, which means you can define dependencies between them. Though this is
clearly open to abuse (there's never any excuse for a system which *needs* VMs
to start in the right order), I did like being able to have my telemetry
system up and running before the application zones came up.

Solaris also lets you specify how many zones it should start up (or shut down)
at once. This is great on heavily zoned systems where startup gets *intense*
as a hundred new-borns all pile onto the same resources.

Put together these two features let you get the important stuff up quickly and
painlessly, with the lessers biding their time, and I miss them. Never mind:
you can't have everything.

### Zones can't NFS...

Solaris 11 lets you run NFS servers in zones, and I use this. On OmniOS:

```cmd
$ svcs -H nfs/server
disabled       Oct_16   svc:/network/nfs/server:default
$ pfexec svcadm enable nfs/server
$ svcs -H nfs/server
disabled       15:45:12 svc:/network/nfs/server:default
$ cat /var/svc/log/network-nfs-server:default.log
...
[ Oct 16 15:21:54 Executing start method ("/lib/svc/method/nfs-server start"). ]
The NFS server is not supported in a local zone
```

### ...Unless!

I was interested by something I'd seen on the `brands(5)` man page.

```
+--------+-------------------------------------------------------+
|illumos | An independent illumos environment running under the  |
|        | shared OmniOS kernel.                                 |
+--------+-------------------------------------------------------+
```

`illumos` brand zones, which I presume are analogous to Solaris's `solaris-kz`
"kernel" zones, are made to let you run something like SmartOS or Tribblix in
a zone. I wondered whether that level of virtualization might accommodate
an NFS server. So, I made one.

Instead `zoneadm install`
using locally cached packages or loopback mounts, an `illumos` brand install
blasts a ZFS image into the zone's root pool in a similar way to the Kayak
installer.

So I made a quick "golden" image with `oozone`:

```yaml
---
brand: ipkg
zonepath: /zones/tornado-gold
```

Then made that zone, unconfigured it and took a snapshot.

```cmd
$ pfexec oozone create tornado-gold.yaml
$ pfexec zlogin tornado-gold
root@tornado-gold:~# /usr/lib/brand/ipkg/system-unconfigure
root@tornado-gold:~# halt
root@tornado-gold:~# ^D
$ pfexec zfs snapshot rpool/zone/tornado-gold/ROOT/zbe@cloner
$ pfexec zfs send -Lce rpool/zone/tornado-gold/ROOT/zbe@cloner \
  | gzip -c9 > illumos_golden_image.zfs.gz
```

Here I ran into my first proper snag. Whatever I did, I couldn't get a
working network connection in my Illumos zone; at least not on first boot.
After a bit of study I found that if I manually created an interface on top of
the zone's VNIC:

```cmd
# ipadm create-if $(dladm show-link -polink)
```

then rebooted, it all worked.

It seemed like the `illumos` brand install mechanism was probably, under the
hood, identical to a standard zone `clone` operation. So I tried cloning zones
and got the same behaviour.

This felt like a bug, so I reported it in [the OmniOS gitter
channel](https://gitter.im/omniosorg/Lobby) and in an hour or so I had
a patch that fixed it.

But better than that: one of the maintainers had spun off a hotfix patch of a
branch which properly supported NFS in zones. Wow. How's that for service?

I abandoned the `illumos` experimentation (I don't think it would have worked
anyway) and ended up running my NFS server from a zone, having `oozone`
install the hotfix as a post-build command. Seamless!

UPDATE: as of the `r151034` release, OmniOS supports NFS in zones.

Back to the "problems".

## Zones are Not Immutable

You get a lot of talk about "immutable infrastructure" these days. It isn't
really of course: you *can* change it, you just *don't*. It's like doing
functional programming in Python by just *choosing* to create new data
structures instead of modifying existing ones. It might make you feel cool,
but you're kidding yourself.

But Solaris 11 lets you make zones that are *genuinely* immutable. Inside one,
you cannot change *anything*. This is managed by the global zone's kernel, and
it's non-negotiable unless the global zone administrator turns it off, or
sneaks into the zone via the trusted path. (You can also configure zones which
allow modification of files under, say, `/var`, should you need to perform
such 20th century actions as logging to disk.)

OmniOS may not have immutable zones as such, but sparse zones are reasonably
close.

```cmd
root@sparse:~# df -h -Flofs
Filesystem             Size   Used  Available Capacity  Mounted on
/lib                   443G  1.00G       442G     1%    /lib
/sbin                  443G  1.00G       442G     1%    /sbin
/usr                   443G  1.00G       442G     1%    /usr
/usr/lib/libc/libc_hwcap1.so.1
                       443G  1.00G       442G     1%    /lib/libc.so.1
root@sparse:~# touch /lib/a /sbin/a /usr/a
touch: cannot create /lib/a: Read-only file system
touch: cannot create /usr/a: Read-only file system
touch: cannot create /sbin/a: Read-only file system
```

Smaller, faster, more secure. I like `sparse` zones.

### OmniOS doesn't Have Many Packages...

As of right now, [the OmniOS pkg
repo](https://pkg.omniosce.org/r151030/core/en/index.shtml) has 759 packages
in it. [The Solaris 11.4
equivalent](http://pkg.oracle.com/solaris/release/en/index.shtml) has 6444.
Sounds pretty rubbish doesn't it? Except it's not, because having that small
number of core packages makes IPS *work*. Using `pkg(5)` on OmniOS is a
different experience from using it on Solaris, even if you also have [the
extra repo](https://pkg.omniosce.org/r151030/extra/), which serves up things
like Ruby.

### ...Except!

But what good is a fast base system if it can't run any applications?  What if
you need stuff like Clojure, or Elixir? I had those in some of my SmartOS
zones, pulled straight from [Joyent's pkgsrc
repo](https://pkgsrc.joyent.com/packages/SmartOS/2019Q1/x86_64/All/).

If you need all kinds of crazy software, OmniOS lets you create a `pkgsrc`
branded zone.  This builds a base image in the same way as other zones, but
installs and configures everything you need to access the aforementioned
Joyent repo. It even installs things in `/opt/local` just like SmartOS does.
All my SmartOS tooling worked with *no changes at all*.

The only downside of the `pkgsrc` brand is that `/usr` is mounted read-only,
so you cannot install (most) normal OmniOS ipkg packages. (I say "most"
because things from the `extras` repo install into `/opt/ooce`, so are fine.)
This caught me out, as things *seemed* to have installed but hadn't. It's not
a big deal once you're aware of it, and so far as I can tell everything the
OmniOS repos offer is also in pkgsrc.

I think the `pkgsrc` brand is great, and it's typical of the kind of creative,
elegant thinking that typifies Illumos. The Illumos way is not to throw code
at a problem, or to invent a slightly different wheel, but to take a step
back, look at what's there, have a think, and adapt. The different zone types
are all driven by a few shell scripts hooking into the branded zones
framework. It's a slight bending of a proven solution, and that's my kind of
engineering.

In building my first half-dozen zones I'd found uses for `lipkg` (faster and
smaller than `ipkg` but still lets you add packages); `sparse` (faster and
smaller than `lipkg`, for when you don't need much configuration); and
`pkgsrc` (for when you need funny applications).

## Doing It

I built my test machine off the old Solaris Puppet zone. When time came to
nuke that and build OmniOS on the old hardware, I hit the ourobourus of
building the Puppet server.

Puppet's perfectly happy to Puppet itself and add all the fine-detail like
users and whatnot, so all I had to do was build a zone which could do that.
Fortunately there's a decent Puppet package in the Joyent pkgsrc repo. Here's
the `oozone` config that builds a zone, installs the needful, and Puppets
itself.

```yaml
---
brand: pkgsrc
zonepath: /zones/cube-puppet
autoboot: true
net:
  - physical: puppet_net0
    'global-nic': auto
    allowed-address: 192.168.1.51/24
    'defrouter': 192.168.1.1
fs:
  - dir: /home
    special: /export/home
    type: lofs
dataset:
  - name: fast/zone/puppet
dns:
  domain: localnet
  search: localnet
  nameserver:
    - 192.168.1.26
    - 192.168.1.1
facts:
  role: puppet
  environment: lab
upload:
  'files/cube-puppet/puppet-master.xml': /lib/svc/manifest/site/puppet-master.xml
  'files/cube-puppet/puppet.conf': /etc/puppetlabs/puppet/puppet.conf
run_cmd:
  - 'yes | /opt/local/bin/pkgin in ruby26-puppet-5.5.2'
  - '/opt/local/bin/gem install fast_gettext -v 1.1.2 --no-document'
  - '/usr/sbin/groupadd -g 40 puppet'
  - '/usr/sbin/useradd -u 40 -g 40 -s /bin/false -d /var/tmp puppet'
  - '/usr/sbin/svccfg import /lib/svc/manifest/site/puppet-master.xml'
  - '/bin/mkdir -p /opt/ooce/bin'
  - '/bin/ln -s /opt/local/bin/puppet /opt/ooce/bin/puppet'
  - '/bin/sleep 10'
  - '/opt/ooce/bin/puppet agent -t'
```

The Puppet code is brought into the zone through the delegated dataset, and
the code in said dataset is kept under version control. That dataset also
contains additional configuration files for things like automatic certificate
signing.

I'd never put a `sleep` in anything that mattered, but this is a task run so
rarely, and always under supervision, that I'll take a deep breath and let it
go. We just need the Puppet server to be up, and it probably takes less than a
second. Yes, `sleep` is awful, but OmniOS doesn't offer `watch(1)` [UPDATE: it
does now] and I don't have a great deal of love for the idea of embedding
shell loops in a YAML file to later be executed by Ruby.

Next I built the DNS zone, with an additional command to temporarily pop
`puppet.localnet` into `/etc/hosts` so it will always find the Puppet server.
After that building zones was entirely straightforward.

Any zone can be rebuilt from a single command. I have full telemetry going
into [Wavefront](https://wavefront.com), with alarms for all things
traditional as well as failed SMF services, failed Puppet runs, [failed cron
jobs](/post/2019-02-14-monitoring-cron).

The Solaris to OmniOS migration was not only painless, but enjoyable. OmniOS
feels very professional, polished, and focused. Its user community is small,
but extremely helpful and inclusive. Long may it prosper.

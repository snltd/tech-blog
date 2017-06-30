---
title: "Building Solaris 11 AI Server in a Dedicated Zone"
tags: [Solaris, Solaris 11, AI]
date: "2012-07-28"
layout: post
category: Solaris
---

As of the first proper release of Solaris 11 (11/11) you can put an AI
server in its own zone.  This wasn't possible previously because of
issues, if I recall correctly, with the multicast DNS service.  I like
things to have their own zones, and I have a need for an AI server. I
also require a repository server, so let's do both. It seems sensible to
me to consolidate the install and repository servers in a single
"install" zone, and as they use different ports, it's possible with
out-of-the-box configurations.

# Building the Zone

The zone is going to be on the server `tap`, and will be called
`tap-install`. I've put it in my internal DNS, on `192.168.1.24`.

AI repos take up a lot of space, so I'm going to delegate a dataset to
the zone and carve it up later. I put my zone data in
`space/zonedata/zone_name`, so:

```cmd
# zfs create -o mountpoint=none space/zonedata/tap-install
# zfs create space/zonedata/tap-install/ai
```

Now to make a zone and give it that dataset. From inside the zone, I
want it to look like a proper zpool called `ai`. I also want to tell the
zone it can only be configured to use `192.168.1.24`, to avoid problems
should someone try to change the address later. Finally, I want to
loopback mount the global zone's `/export/home` as `/home`, so I don't
have to set up automounter in the new zone.

```cmd
# zonecfg -z tap-install
tap-install: No such zone configured
Use 'create' to begin configuring a new zone.
zonecfg:tap-install>create
create: Using system default template 'SYSdefault'
zonecfg:tap-install> set zonepath=/zones/tap-install
zonecfg:tap-install> add dataset
zonecfg:tap-install:dataset> set name=space/zonedata/tap-install/ai
zonecfg:tap-install:dataset> set alias=ai
zonecfg:tap-install:dataset> end
zonecfg:tap-install> select anet linkname=net0
zonecfg:tap-install:anet> set allowed-address=192.168.1.24
zonecfg:tap-install:anet> end
zonecfg:tap-install> add fs
zonecfg:tap-install:fs> set special=/export/home
zonecfg:tap-install:fs> set dir=/home
zonecfg:tap-install:fs> set type=lofs
zonecfg:tap-install:fs> end
zonecfg:tap-install> commit
```

Here's a pro-tip. The first time I tried to do this, none of my clients
could get a DHCP address. I cranked up the logging by editing
`/etc/inet/dhcpd4.conf` and configuring an appropriate syslog facilty,
and it told me

```
[ID 702911 local7.info] DHCPDISCOVER from 00:50:56:3c:69:a3 via net0
[ID 702911 local7.info] DHCPOFFER on 192.168.1.194 to 00:50:56:3c:69:a3 via net0
```

over and over again, but the client never got the address. Hmmm. It thinks
it's sending an address; let's see what `snoop` says.

```cmd
# snoop port 67 or port 68
OLD-BROADCAST -> BROADCAST    DHCP/BOOTP DHCPDISCOVER
OLD-BROADCAST -> BROADCAST    DHCP/BOOTP DHCPDISCOVER
OLD-BROADCAST -> BROADCAST    DHCP/BOOTP DHCPDISCOVER
```

Nothing going out there is there? Obviously it was something network
related, and my first (educated) guess was the right one. I'd turned on
`ip-spoof` protection in the zone's `anet`, and that was blocking the
outgoing `DHCPOFFER`. So don't turn that on in this instance!
(`mac-spoof` is okay though.)

I could install the zone now, and configure it interactively on the
console via `zlogin`. Alternatively, I can go through the interactive
configuration now using `sysconfig`. This is a kind of half-baked way to
create the huge chunk of XML that's replaced the `syidcfg` file we used
to use. It's interactive only, so you can't script it, which is rubbish,
but look children, it's colourful!

We'll save the config file as `tap-install.xml` in the current working
directory. Run

```cmd
# sysconfig create-profile -o tap-install.xml
```

And answer the questions. Note that it only lets you configure a single
NIC.  This is a current limitation of AI itself. Anyway, you can now use
the XML file to install the zone.

```cmd
# zoneadm -z tap-install install -c $(pwd)/tap\-install.xml
```

Note that the path to the XML file has to be fully qualified, otherwise
it chokes. Who is writing system software at Sun these days?

Now, wait whilst it pulls everything over the network from Oracle and
installs the zone. At the time of writing there's 175.8Mb of stuff to
download.

Once that's done, boot it up and do whatever post-install configuration
you need to do. I only had to add my normal user account.

# Setting Up an Install Server

One of the difficulties in learning AI (and IPS) is that it uses a lot
of jargon which often doesn't succinctly describe how things work.
"Install server" is a good example, because really, it's just a boot
server. It's a DHCP server that gives clients a mini-root. Admittedly,
that mini-root contains sufficient code to initiate a network install,
but in truth it's the client that does its own installation, and the
software it installs comes from the repository server, which usually
isn't the install server.  (Though in this case it is!)

Anyway, remember earlier I mentioned that DNS multicasting didn't used
to work in a zone? It does now, and we need it. (All commands from now
on are in the `tap-install` zone.)

```cmd
# svcadm enable dns/multicast
```

We need to install the `installadm` package that contains all the tools
needed to manage AI. IPS will resolve dependencies and also install the
DHCP and TFTP services clients need to boot, as well as the customized
version of Apache which presents the repository. Solaris 11 uses the ISC
DHCP server, which is good, because the old Sun one was pretty horrible
to manage. (ISC is not without its faults - I heard Joyent wrote their
own for SmartDatacenter.  (And they didn't write it in bloody Python...)
Anyway, do the business with

```cmd
# pkg install installadm
```

Filesystems now. Remember I delegate a dataset and used `alias` to make
it look like a real pool?

```cmd
# zpool list -H ai
ai      1.58T   1.45T   127G    92%     1.05x   ONLINE  -
```

In this pool I want to create a dataset for the repo to go in, and mount
it under `ai/repo`. I'll also make one for client data, one for the
install images (i.e. miniroots) and get rid of the damn `/export/home`
that `zoneadm` always creates these days.

```cmd
# zfs create -o mountpoint=/ai/repo ai/repo
# zfs create -o mountpoint=/ai/clients ai/clients
# zfs create -o mountpoint=/ai/images ai/images
# zfs destroy -r rpool/export
```

## Creating Install Services

Now I'm ready to add my first install service. This is like a Jumpstart
mini-root - it's what your install clients boot off. I like naming
systems, and I've decided my AI naming system will be
`arch-release_data`. So, my SPARC Solaris 11 11/11 image will be called
`sparc-1111`, and I'm going to put it in `/ai/images/sparc-1111`. We'll
see how good and idea this is over the years, as my collection of
install images grows. (It's actually not such a big deal, because you
can rename install services now.)

I want my server to install clients from a DHCP pool of 5 addresses,
beginning at 192.168.1.190, and I've already downloaded my AI ISOs. So,
for the x86 service:

```cmd
# installadm create-service \
> -n x86-1111 \
> -c 5 \
> -i 192.168.1.190 \
> -d /ai/images/x86-1111 \
> -s /net/hp-bk-01/export/iso/os/solaris/x86/solaris-11/sol-11-1111-ai-x86.iso
```

Now the SPARC. There's no need to specify the DHCP info - the macros are
already set up.

```cmd
# installadm create-service \
> -n sparc-1111 \
> -d /ai/images/sparc-1111 \
> -s /net/hp-bk-01/export/iso/os/solaris/sparc/solaris-11/sol-11-1111-ai-sparc.iso
```

You may notice that in the output of the `installadm` command above, it
says `Creating default-sparc alias`. Install service aliases are new in
11/11, and they let you associate different groups of clients, profiles
and manifests with the same physical image on disk, which I think is a
good idea, though it does add a little complexity and gives you one more
thing to learn.

```cmd
# installadm list
Service Name  Alias Of   Status  Arch   Image Path
------------  --------   ------  ----   ----------
default-i386  x86-1111   on      x86    /ai/images/x86-1111
default-sparc sparc-1111 on      Sparc  /ai/images/sparc-1111
sparc-1111    -          on      Sparc  /ai/images/sparc-1111
x86-1111      -          on      x86    /ai/images/x86-1111
```

If you do a `df` or a `mount`, you'll see a bunch of new loopback
mounts, mapping all the above image paths into `/etc/netboot`.

We've got enough there to network boot SPARC and x86 clients, which we
could install from the main `pkg.oracle.com` repo.

If you want to do that, and check things work, run

```cmd
# installadm create-client -e <client_mac-address> -n <service name>
```

and boot your client. It'll install a minimal Solaris 11 with a DHCP
`net0`.

# Building a Repository Server

If we plan to do a lot of network installs, it would be nice to have our
own package repo.  I've already downloaded the 'full repo' ISO from
Oracle, so I'm going to install it in the `repo` dataset I made earlier.

```cmd
# lofiadm -a /net/hp-bk-01/export/iso/os/solaris/sparc/solaris-11/sol-11-1111-repo-full.iso
# mount -Fhsfs /dev/lofi/1 /mnt
# rsync -aP /mnt/repo/ /ai/repo
```

The `rsync` command comes from the ISO's README file. It copies 6.6Gb of
data, so it takes a while.

The SMF service that presents the repo is
`svc:/application/pkg/server:default`, and you're going to have to tell
it where you just put the repository and, of course, turn it on.

```cmd
# svccfg -s pkg/server setprop pkg/inst_root=/ai/repo
# svcadm enable pkg/server
```

You should now be able to query the repository with `pkgrepo`.

```cmd
# pkgrepo info -s  /ai/repo
PUBLISHER PACKAGES STATUS           UPDATED
solaris   4292     online           2011-10-26T17:17:30.230911Z
```

And you can connect to it on port 80 with any web browser. An
improvement from Solaris Express is that the repo is properly searchable
by default now.

## Using the Repository Server

Once I had my repo server set up, I had to tell my existing machines to
use it. Some still pointed at the Oracle repo, and all I wanted to do
was change the URI to my own local server. Maybe it would be better to
point at the local repo first, with a fallback to the 'official' one,
but as I don't have an Oracle support contract, I've nothing to lose,
and it keeps my machines consistent as I know they're all being built,
upgraded and installed from a single source.

```cmd
# pkg publisher
PUBLISHER            TYPE     STATUS   URI
solaris              origin   online   http://pkg.oracle.com/solaris/release/
# pkg set-publisher -G '*' -g http://tap-install solaris
$ pkg publisher
PUBLISHER            TYPE     STATUS   URI
solaris              origin   online   http://tap-install/
```

`-G` says 'replace this origin', and as I only have one origin I told it
to replace them all; '-g' is the new origin, and the final argument
specifies the publisher.

Once this is done in the global zone, the local zones will automatically
use the new publisher through the pkg proxying system, so you shouldn't
need to make any further changes.

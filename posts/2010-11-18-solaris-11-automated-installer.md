---
title: "Solaris 11 Automated Installs"
tags: [Solaris, install, AI]
date: "2010-11-18"
layout: post
category: Solaris
---

**DISCLAIMER - I wrote this article based on a preview release of
Solaris 11. (Solaris Express, specifically).  AI, and a lot of other
things, changed in the FCS release, so I'm not entirely certain that
what follows can be completely trusted. The bit about setting a static
IP address is definitely wrong.**

Solaris 11 is, in its first official form, with us. However much we
might hate IPS, bloat, GNOME, bash as root's shell, and all the other
Linux-isms, we've got to accept that this is the future of Solaris
(assuming Solaris has a future) and embrace it.

I'll miss Jumpstart. I liked Jumpstart. I was good at Jumpstart. So,
from a Jumpstart perspective, what's the new automated installer all
about?  Hopefully it's a great deal better than the interactive
installer, which lets you choose the timezone, the root password, and
nothing else. Don't want the whole O/S in a single zpool covering the
whole available disk? Want a static IP address?  Tough. But to get back
on topic, what follows is me thinking out loud and learning about AI and
IPS. Hope it makes sense.

Jumpstart, for SPARC at least, was very straightforward. Send a RARP
request, get your IP address, TFTP your kernel across, NFS mount root,
create local filesystems under `/a`, install packages, run finish
scripts, reboot. Job done. AI relies on DHCP, which, compared to RARP
and bootparams, is a can of worms (at least if you're using the Solaris
DHCP server). It also doesn't just install packages from the install
server, rather, it must connect to an IPS repository. If you're a
serious admin and you're going to be doing a lot of installs, you'll
probably want to set up an in-house repository. If not, you can use
Oracle's.

# Setting Up an Install Server

Though it was possible to Jumpstart any Solaris from any other Solaris
(you could even set up an install server on Linux or BSD, if you were
exceptionally perverse), AI requires a Solaris Express server. So,
install one of those using the LiveCD or the text installer.

# The Repository Server and the Install Image

It you remember your Jumpstart, you'll recall `setup_install_server`,
which copied all the `SUNW` packages from the CD or DVD onto disk, and
also installed a mini-root which install clients used to boot.

AI uses a repository server for its packages, and they're passed to the
client by an HTTP server. You can build your own if you like (it isn't
hard, and I'd recommend you do it), or you can use Oracle's own.

The Jumpstart `Solaris_x/Tools/Boot` mini-root is replaced by AI's
install image. They're pretty much the same thing, a skeleton filesystem
clients can use to get up and running before they create and populate
their own filesystems.

As Jumpstart had `setup_install_server`, `add_install_client` and so-on,
so AI has `installadm`, which should already be installed
on your Solaris Express install server.  Check with

```cmd
$ pkg list install/installadm
```

If it's not there, grab it from Oracle's repository with

```cmd
# pkg install install/installadm
```

I'm going to create install images in a moment, but I need somewhere to
put them. There's a lot of data going in, and much of it, especially if
you start adding later images without removing old ones, will be
duplicated. So,

```cmd
# zfs create rpool/ai
# zfs set mountpoint=/export/ai rpool/ai
# zfs set compression=on rpool/ai
# zfs set dedup=on rpool/ai
```

If you don't have an absolute tonne of memory, don't dedupe. It's a
performance killer.

Get the AI boot image ISO files you need from [Oracle's download
site](http://www.oracle.com/technetwork/server-storage/solaris11/downloads/index.html),
and we'll look at creating the install images, each of which is part of
its own install service.

## Install Services

The install service is to AI what RARP, bootparams, TFTP and NFS were to
Jumpstart. That is, the mechanism by which a client is able to boot up
to a point where it can install software.

`installadm` is closely tied in with DNS. It won't even run if the
multicast service isn't up.

```cmd
# svcadm enable svc:/network/dns/multicast
```

So I'm going to create an *install service* from an install ISO held
on `tap`, my main NFS server. This is a combination of an install
image, which is created from the ISO file and contains just enough for a
remote boot (a boot archive, and `/dev` and `/platform`
files). A service can also include DHCP information if you're having your
install server also be your DHCP server. I am, because my network doesn't
already have DHCP. I'm going to have a pool of ten addresses from
192.168.1.230 to 192.168.1.239, and I choose to call my service and my
images *date-architecture*, following the convention set by the names
of the downloaded files.

```cmd
# installadm create-service \
  -n 201011-sparc \
  -c 10 \
  -i 192.168.1.230 \
  -s /net/tap/export/iso/solaris-express/sol-11-exp-201011-ai-sparc.iso \
/export/ai/201011-sparc/target

Setting up the target image at /export/ai/201011-sparc/target ...
Registering the service 201011-sparc._OSInstall._tcp.local
Creating DHCP Server
Created DHCP configuration file.
Created dhcptab.
Added "Locale" macro to dhcptab.
Added server macro to dhcptab - lw-01-sx.
DHCP server started.
Added network macro to dhcptab - 192.168.1.0.
Created network table.
Service discovery fallback mechanism set up
Creating SPARC configuration file
```

I also added an x86 install image, simply changing `sparc` to `x86` in
the above command.

You'll now find you've gained a service:

```
online         15:54:09 svc:/system/install/server:default
```

Let's investigate it.

```cmd
$ svcs -p svc:/system/install/server:default
STATE          STIME    FMRI
online         15:54:09 svc:/system/install/server:default
               15:54:02     3409 webserver
               15:54:09     3429 httpd
               15:54:10     3430 httpd
               15:54:10     3431 httpd
               15:54:10     3432 httpd
               15:54:10     3433 httpd
               15:54:10     3434 httpd
```

Looking at those processes with `pfiles` tells us the Apache webserver
is listening on port 5555 and writing logs to
`/var/ai/image-server/logs`. If you connect to that port, you'll find
it's exporting the directory structure of your install image directory.
In this case we can navigate everything below `/export/ai`.

We can look at the DHCP magic that `installadm` did in the background
by running

```cmd
# dhtadm -P
```

I've always found using Solaris as a DHCP server complicated and
troublesome, so it's great that Sun have taken the hassle out of it by
having `installadm` create the macros.

`installadm` can show us what install images we can serve up to
clients.

```cmd
$ installadm list
Service Name Status       Arch  Port  Image Path
------------ ------       ----  ----  ----------
201011-sparc on           Sparc 46501 /export/ai/201011-sparc/target
201011-x86   on           x86   46502 /export/ai/201011-x86/target
```

If you use a browser to connect to the ports given in the fourth field
(these are being served by a Python program), you'll see a
`Default` manifest. This is located in the `auto_install` subdirectory
of the `Image Path`, and it's kind of like a profile in Jumpstart. So,
you have an install service for each O/S you want to be able to install,
each one running its own webserver on its own port. You can delete,
stop, and start services through `installadm` as required.  (Though you
have to clean DHCP table up yourself.)

# Installing a Client

We've done no customization (and practically no work) yet, but we're
already in a position where we can install a client.

## Generic x86 Install

I'm going to try an install, with a VirtualBox. The MAC address of the empty
VBox is `08:00:27:e7:d0:54`. Setting up a vanilla install, using the
default manifest we just looked at requires a single invocation of
`installadm create-client`. We only have to identify the client by its
MAC address and give the name of the install service we wish to use

```cmd
# installadm create-client -e 08:00:27:e7:d0:54 -n 201011-x86
```

That's a lot simpler than the old `add_install_client` kerfuffle isn't
it? (And quicker.) This writes a DHCP macro, and puts a PXE boot loader,
a GRUB menu, and a Solaris miniroot into the install server's
`/tftpboot` directory.

I started my VirtualBox, hit F12 to get the boot menu, then hit `l` to
boot off the LAN. It got a DHCP address straight away, and gave me a
menu with the option of booting from the net or doing a network install.
I chose the latter. It's a little confusing now, because you are
presented with a console login, with all the installation work going on
in the background. If you log in as `jack/jack`, you can follow the
installation by doing:

```cmd
$ tail -f /tmp/install_log
```

The default installation, on my test system, took about 15 minutes to
pull all the required packages down from Oracle's repository server,
then a further minute or two to configure the system to boot.

It took me a minute or two to reboot the client, because the `jack` user
no longer has the Primary Administrator role, so

```cmd
$ pfexec reboot
```

doesn't work. (It did in OpenSolaris.) Turns out I had to `su` to root
(I'm such a luddite), using `solaris` as the password.

## Generic SPARC Install

Next I'll try installing Express on a v245. AI requires an OBP version
with WANboot functionality, which the v245 has. The command is the same
as before, just using the SPARC install service.

```cmd
# installadm create-client -e 0:14:4f:c3:88:5e -n 201011-sparc
```

Then on the v245 console,

```cmd
ok boot net:dhcp - install
```

The first time I tried this, the install failed. Examining
`/tmp/install_log` I found

```
<OM Apr  8 15:29:05> Ignoring c3t0d0 because of bad Geometry
<OM Apr  8 15:29:05> Ignoring c3t1d0 because of bad Geometry
<OM Apr  8 15:29:05> Ignoring c3t2d0 because of bad Geometry
<OM Apr  8 15:29:05> Ignoring c3t3d0 because of bad Geometry
<AI Apr  8 15:29:07> No disks found on the target system
```

This was because all my disks had EFI labels. To clear them I did

```cmd
# format -e
```

chose `label`, and put an SMI label on the disk. I cleared the service,
and it failed again, saying it couldn't create the swap space. This was
because I'd accepted the default SMI layout, which has a pretty small
slice 0, so I repartitioned the c3t0d0 with all the space in slice 0 and
cleared the service again.

```cmd
# svcadm clear svc:/application/auto-installer:default
```

And away we went. It's nice to not have to completely restart the install.

By the way, do you know that if a Jumpstart fails because of an error in the
profile, you can change the profile and re-run `suninstall`?

## Customizing Installs

Unfortunately, the default install is as useless as the text install. (I
think they're the same thing.) For AI to be of any practical value, we
need to customise the way it installs.

In Jumpstart, this was done with a combination of the `sysidcfg` file,
which identified the system's network interfaces, time zone, language
and so-on, and the `profile`, which laid out disks and mirrors, selected
the install cluster, and added and removed packages.

### Install Manifests

The main difference between Jumpstart files and AI files is that, as
with many things modern in Solaris, AI manifests are XML. Different
people have different views on XML. I think it sucks ass in pretty much
every situation.

As you'd expect, this is where things start to get complicated. We have
to more-or-less define the configuration of a Solaris host with an XML
file.

In my Jumpstart setup I always have an `/export/js/clients` directory,
with each install client having its own directory containing its
`sysidcfg` `profile` and finish script list. I'll repeat that with my AI
setup.

```cmd
# mkdir -p /export/ai/clients
```

### The SC Manifest

First we'll look at the System Configuration, or SC manifest. This is
pretty much your `sysidcfg` equivalent, because here you define the
primary IP NIC (you can't define any others), the terminal type, and DNS
info.

It can be embedded, as a complete XML file, inside the main AI manifest
(more of which in a moment), or in its own file which the AI manifest
must reference. I prefer to have it as a separate file, and I create
mine from the example provided in Solaris.

```
/usr/share/auto_install/sc_profiles/static_network.xml
```

For the keyboard types, I think
`/usr/share/lib/keytables/type_6/kbd_layouts` contains a canonical list
of names. Mine is `UK-English`. I got my timezone name (`GB`) from
`/usr/share/lib/zoneinfo`.

A nice improvement over Jumpstart is that you can create default users
in your SC manifest. (In fact, you have to, as Solaris Express won't let
you log on as `root` by default.) It was never really a problem with
Jumpstart -- it was trivial to write a finish script that added users --
but it always seemed wrong that you had to.

By the way, if you do want to be able to log in as root (and, let's be
honest, who doesn't?), set the `root_account` property group's `type`
propval to `normal`.

I saved my amended manifest as
`/export/ai/clients/lw-01-sx-02/sc_manifest.xml`. (lw-01 is the name of
my laptop, (`l` for laptop, `w` for Windows, `sx-02` denotes my second
`S`olaris e`X`press virtualbox.)

If you aren't using IPV6 (and my guess is that you aren't) then I
recommend you completely delete the `install_ipv6_interface` property
group. If you leave it all unset, you'll get an SMF error once the
client is installed.

### AI Manifest

Now on to the biggie, the AI manifest. This is the equivalent of the
Jumpstart `profile`.

Oracle's official documentation tells us to create manifests by hacking
the default. (This gets worse and worse, doesn't it?) There's a default
manifest for each install service, so I have two to choose from:

```
/export/ai/201011-x86/target/auto_install/default.xml
/export/ai/201011-sparc/target/auto_install/default.xml
```

Let's go.

```cmd
# cp /export/ai/201011-x86/target/auto_install/default.xml \
  /export/ai/clients/lw-01-sx-02/ai_manifest.xml
```

The first thing to learn about are the "group packages", or
"metaclusters". These are analagous to Jumpstart's install clusters
(remember `SUNWCreq`, `SUNWCuser` and friends?).

The group packages define lists of IPS packages which will be installed
from your repository server (which, by default, is Oracle's repository
server).

Now, this is important, and, IMHO, this is weird. You can't uninstall a
single package without first uninstalling its parent group package
definition. Group packages can contain other group packages, so to omit
a package you don't want, you're probably going to have to install at
least one group package definition. Got that? Me neither.

First, change the `ai_instance_name` from `default`. I'm not sure if it
matters what you change it to, but the client hostname works for me.

I don't want a GNOME desktop, and all that other junk, and as I only
speak English, I don't much care about languages. So, I don't want the
`babel_install` cluster. I want `server_install`.

In the default manifest you'll see, commented out, an
`sc_embedded_manifest` tag. We've already done our SC manifest in a
separate file, we just need to tell the AI manifest to refer to it.

So add, near the end of the file, just before you close off the
`ai_instance` element, insert

```xml
<sc_manifest_file name="AI" URL="./sc_manifest.xml"/>
```

I like my clients to reboot after install. By default, AI doesn't do this,
you have to add

```
auto_reboot=true
```

to the `ai_instance_name` tag. I've found this doesn't always work on
VirtualBoxes, but at least it tries, and you're no worse off than it
just sitting there waiting for a biscuit.

Because I like to keep my data separate from my operating system, my
machines tend to have two zpools, `rpool`, and `space`. This is partly a
hangover from the old days of slicing up disks, but primarily so that
if, somehow, the O/S gets utterly hosed, I can reinstall it from
scratch, preserving the data on the slices holding the `space` zpool.

I happen to know that my VitualBox is assigning the its virtual disk as
`c7t0d0`, so I can request that disk be carved up like so.

```xml
<target>
  <target_device>
    <disk>
      <disk_name name="c7t0d0" name_type="ctd"/>
      <slice name="0" is_root="true" force="true">
      <size val="25gb"/>
      </slice>
      <slice name="3" force="true"/>
    </disk>
  </target_device>
</target>
```

You can also specify disks by volume IDs, device IDs, but you don't yet
seem able to set up mirrors or more complicated zpool arrangements. It
also seems possible only to create a single zpool, which must be the
root pool. So, in my example above, I put a 25Gb root pool in slice 0,
then, by omitting a size specification, put the rest of the disk space
in slice 3. (I created my `space` zpool by hand later.) The `force`
keyword means that if the slice already exists, the installer will
re-create it rather than failing. This is helpful if you're learning AI
by reinstalling the same client over and over.

AI will automatically assign swap space, but I chose to define a 6Gb
space in the following manner.

```xml
<target>
  <target_device>
    <swap>
      <zvol action="create" name="swap">
      <size val="6gb"/>
    </zvol>
    </swap>
  </target_device>
</target>
```

I checked my two manifests with `xmllint`, and they both looked good.
I'm not sure yet if there's a better way to validate manifests,
something like `svccfg validate` would be great. If you have errors
though, you'll be shown them when you try to add the manifest.

### Install Criteria

When you Jumpstart clients, the client finds out what profile to use by
consulting the `rules.ok` table. In AI, *install criteria* map clients
to manifests.

You can't use a custom AI manifest without adding it to an install
service and specifying criteria which clients must meet before they can
use it. This is done with the `add-manifest` sub-command of
`installadm`.

Install criteria aren't (currently) as flexible as Jumpstart rules, and
they're far more complicated to create. At the time of writing you can
only match a client on its architecture, MAC address, IP address, amount
of memory, CPU type (i386 or SPARC) or platform type.

It's possible to create an XML manifest which lays down install
criteria, but for my purposes so far, that's seemed like overkill. You
do, however, have to have install criteria if you want to use custom AI
manifests, so I supplied mine with the `-c` flag, which is kind of a
"one-shot" solution.

```cmd
# installadm add-manifest -m /export/ai/clients/lw-01-sx-02/ai_manifest.xml \
  -n 201011-x86 -c cpu=i386
```

Note: if you choose to match on IP address, be aware that the IP address
that is matched is the IP address assigned by DHCP, *not* the one
assigned by the SC manifest.

Then I could finally add the install client and network boot.

```cmd
# installadm create-client -e 08:00:27:e7:d0:54 -n 201011-x86
```

Overall, I'd say AI isn't quite ready for showtime yet. I strongly
dislike having to write XML, and hopefully someone will write tools so
we don't have to. (I'll do it myself if no one else does.) There are
sever limitations on configure NICs and Zpools which I find
unacceptable, but I'm sure they'll be addressed soon.

AI's not bad, but I still think think I'm going to miss Jumpstart.

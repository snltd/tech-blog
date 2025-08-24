---
title: "Gurping Zones"
date: 2025-07-25
tags: [OmniOS, Rust, Janet, Gurp]
layout: post
category: Gurp
---

With Gurp now able to build most of my zones, I thought about whether it should
build the zones themselves. Like most illumos users, I
[already wrote my own zone manager](https://github.com/snltd/oozone) which
builds zones from YAML definitions, but hey, YAML.

After a bit of experimentation I thought this seemed like a pretty good way to
define a zone.

```janet
(zone/ensure "serv-media"
             :brand "lipkg"
             (zone-fs "/home" :special "/export/home")
             (zone-fs "/storage/mp3" :special "/export/mp3")
             (zone-fs "/storage/flac" :special "/export/flac")
             (zone-network "media_net0"
                :allowed-address "192.168.1.24/24"
                :defrouter "192.168.1.1")
             :dns {:domain "lan.id264.net"
                   :nameservers ["192.168.1.53" "192.168.1.1"]})
```

I know there's a slightly ugly mix of functions and structs there, but the
alternative is defining filesystems and nets (both of which there can by many
of) as one big struct, and I didn't like that at all. There's no point making a
`(brand "brand")` function which would map to `:brand "brand"`, and there's no
obvious name for the `:dns` block to have, so that would feel forced. The `:dns`
struct expands to a couple of `attr` blocks in the real zone config, and, as
`(zone-attr)` is a thing, you could do it that way if you preferred, but I like
my config with with sugar.

The `--dump-config` flag will make Gurp dump the `zonecfg` script it creates to
stdout if you're curious, or need to check it.

If you've used zones you will notice some essentials like `:zonepath` and
`:autoboot` are missing. These have defaults filled in by the Janet front-end.

A state machine brings zones up and down. I'm just a dumb-ass ops guy, and I
don't often get the chance to break out even the simplest proper programming
techniques, so wrapping a Rust `enum` with a few methods felt nice. So far my
state transitions are all via `zoneadm` and `zonecfg`, as they should be, but
I've seen `bhyve` zones get pretty wedged when they come down, so it's not
impossible I'll end up having to do something nastier in the future. The state
transitions can all time out, so at least if a zone does get wedged Gurp will
give up and move on.

To know when a zone is "ready", I use `svcs` to check if the multiuser milestone
is online. This is more trustworthy than grepping `zoneadm` output.

I generally create a gold zone, then clone it. I added `:clone-from` to the
`(zone/ensure)` definition, as well as `:final-state` to shut the zone down so
it can be cloned.

I also like to exercise my infrastructure creation as much as possible, so I
gave the zone doer a `:recreate` property. This takes an integer value _n_, and
gives the zone a 1-in-_n_ chance of being destroyed and recreated when Gurp
ensures the definition. So, a value of 1 recreates it every time, 0 leaves it
alone, and 10 means it will be rebuild roughly once in every ten runs.

There isn't much point recreating a zone if it doesn't also recreate what's
inside it. So you can `:bootstrap-from <file>`. When this is present, Gurp
copies itself into the zone's `/var/tmp` and, once the zone has booted into
multiuser mode, uses `zlogin` to run that copy, `apply`ing the given file.

This works fine for me, because I have my home directory loopback- or
NFS-mounted everywhere and I can put by Gurp config there. But I've had this
vague notion for some time that Gurp could run as an HTTP server and client,
which would allow the zone being bootstrapped to pull config and files from a
central server. I think that might also be a decent way to handle secrets, which
I've avoided doing so far.

The `zone` doer can only create and destroy zones. It can't modify in place. I
started looking at doing this, but it clearly wasn't a five-minute job, and I
don't need to be able to do it. I think it's almost always going to be better
practice to recreate a zone, and I have a proven mechanism for that. I might do
it at some point in the future though, as it might be interesting to do it with
a proper parser like [pest](https://pest.rs).

## LX

Broadcom turned off my Wavefront account, which means I need some other way of
collecting and graphing metrics. OmniOS provides a
[VictoriaMetrics](https://victoriametrics.com/) package, but no Grafana. I had a
quick look at building a native package, but it looked somewhere between loads
of work and impossible. It should, however, run pretty easily in an LX Zone.

For those who don't know, an LX zone is an illumos container which converts
system calls from the Linux to SunOS. This means that you can run the vast
majority of Linux software with zero effort. Once you have the zone, that is.

Whereas native zones install by adding packages from a repo, LX zones install
from a pre-baked image. The OmniOS project provides
[images for various Linux distributions](https://github.com/omniosorg/lx-images/releases),
but I didn't want to have to get my `wget` on every time I wanted to build a
zone. So I gave Gurp a helper which pulls images down and caches them in
`/var/tmp`. It looks at the latest release in the lx-images Github which matches
the pattern you give it. Say these are the latest releases:

```
lx-alma-8-2025-04-10_13-01-56.tar.xz
lx-alma-9-2025-04-10_13-01-56.tar.xz
lx-alpine-3-2025-04-10_13-01-56.tar.xz
lx-centos-stream-9-2025-04-10_13-01-56.tar.xz
lx-rocky-8-2025-04-10_13-01-56.tar.xz
```

If you specify `:lx-image "lx-alma"`, you'll get the latest alma, in this case
`lx-alma-9-2025-04-10_13-01-56.tar.xz`. If you specify `alma-8` you get
`lx-alma-8-2025-04-10_13-01-56.tar.xz`. Images are cached in `/var/tmp`.

Building a fully working LX zone was then as simple as:

```janet
(zone/ensure "serv-grafana"
             :brand "lx"
             :lx-image "alpine"
             (zone-attr "kernel-version" :value "4.4")
             (zone-fs "/home" :special "/export/home")
             (zone-network "lx_net0"
                :allowed-address "192.168.1.44/24"
                :defrouter "192.168.1.1")
             :dns {:domain "lan.id264.net"
                   :nameservers ["192,168.1.53" "192.168.1.1"]})
```

Note the `kernel-version` `attr`. Without that, things won't work properly.

Remember I said LX zones run Linux binaries? Well, they also run native
binaries, and even give you access to illumos tools through `/native/usr`. So,
Gurp will run in the LX just like every other zone. Why not use it to configure
LX zones?

One of my guiding principles when writing Gurp was "It is illumos-specific. It
will not support any other OS". To build a Grafana zone, I only need to install
the `grafana` package, drop a couple of config files, and start a service. And
remember, one of my other principles was to not allow execution of arbitrary
shell commands.

First, I cheated. I used the zone doer's `copy-in` and `;run-in` to do what
needed to be done, but I didn't like it. It was cheating, and it wasn't config
management, it was setting something up then leaving it alone, like Jumpstart
in 1996.

I chose to write a super-basic `apk` doer. It can install and remove packages.
Nothing else. The `file` and `file-line` doers were capable enough to install my
Grafana config and modify a couple of files.

Here's the full config, with annotations. I share a ZFS dataset from the global
zone which holds persistent data. (In this case, just the VictoriaMetrics
plugin: everything else is in a MySQL DB.)

````janet
(import ../globals)
(import ../secrets)

(def zfs-mounter "/etc/init.d/zfs-mount")
(def data-dir "/var/lib/grafana")
(def grafana-init "/etc/init.d/grafana")

(role grafana
      (zfs/ensure (zfscat globals/fast-pool "zone" "grafana"))

      (zfs/ensure (zfscat globals/fast-pool "zone" "grafana" "data")
                  :properties {:mountpoint data-dir})

      (section mount-zfs-filesystems
               # An LX Zone can see delegated datasets, but it won't mount them
               # unless it's told to. This script does that. We could also use
               # :from and keep it a separate file, but I wanted to show what's
               # happening.
               (indoc zfs-mount-script ```
                    #!/sbin/openrc-run

                    description="Mount delegated ZFS dataset"

                    depend()
                    {
                        need localmount
                        before *
                    }

                    start()
                    {
                        ebegin "Mounting ZFS dataset"
                        /native/usr/sbin/zfs mount -a
                        eend $?
                    }```)

               (file/ensure zfs-mounter
                            :content zfs-mount-script
                            :mode "0755")

               # This is all `rc-update` does. The script above will run in the
               # boot runlevel, which is the first one. So our ZFS data will be
               # visible when the service starts later.
               (symlink/ensure "/etc/runlevels/boot/zfs-mount"
                               :source zfs-mounter))

      (section configure-grafana
               (apk/ensure "grafana")

               # The 'net' dependency is never resolved, because an LX zone
               # doesn't run a proper init, But there is networking, so we
               # can just remove the dependency.
               (file-line/remove grafana-init
                                 :match "contains"
                                 :pattern "need net")

               # Make the grafana service part of the default runlevel 
               (symlink/ensure "/etc/runlevels/default/grafana"
                               :source grafana-init)

               # Accept external connections.
               (file-line/ensure "/etc/conf.d/grafana"
                                 :replace "127.0.0.1" :with "0.0.0.0")

               # Configure Grafana through a template. Again, you'd likely keep
               # this in its own file.
               (indoc grafana-ini-template ```
                    [paths]
                    data = {{ data-dir }}
                    logs = /var/log/grafana
                    plugins = {{ data-dir }}/plugins
                    provisioning = conf/provisioning

                    [server]
                    protocol = http
                    http_port = 3000

                    [database]
                    type = mysql
                    host = {{ mysql-host }}:3306
                    name = grafana
                    user = grafana
                    password = {{ mysql-password }}

                    [log]
                    mode = console file
                    level = info

                    [news]
                    news_feed_enabled = false

                    [metrics]
                    enabled           = true
                    ```)

               (file/ensure "/etc/grafana.ini"
                            :content (
                              template-out grafana-ini-template
                                           {:data-dir data-dir
                                            :mysql-host "mysql"
                                            :mysql-password secrets/mysql-password}))))
````

This doesn't actually start the `grafana` service, so I added a `:final-state`
property to the `zone` doer that reboots the zone. The service starts on boot,
and it's never a bad idea to reboot-test.

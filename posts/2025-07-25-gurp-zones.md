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
quick look at building a native Grafana package, but it looked somewhere between
"loads of work" and "impossible". It should, however, run pretty easily in an LX
Zone.

For those who don't know, an LX zone is an illumos container which converts
system calls from the Linux to the SunOS kernel. This means that you can run the
vast majority of Linux software with zero effort. Once you have the zone, that
is.

Whereas native zones install by adding packages from a repo, LX zones install
from a pre-baked image file. The OmniOS project provides
[images for various Linux distributions](https://github.com/omniosorg/lx-images/releases),
but I didn't want to have to get my `wget` on every time I wanted to build a
zone. So I gave Gurp a helper which pulls images down and caches them in
`/var/tmp`. It looks at the latest release in the `lx-images` Github which
matches the pattern you give it. Say these are the latest releases:

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

Like so many people, the first time my principles were challenged, I threw them
out of the window, in this case, by writing a super-basic `apk` doer. It can
install and remove packages. Nothing else. The `file` and `file-line` doers were
capable enough to install my Grafana config and modify the couple of things that
needede changing.

Here's the full config, with annotations. I share a ZFS dataset from the global
zone which holds persistent data. (In this case, just the VictoriaMetrics
plugin: everything else is in a MySQL DB.)

````janet
(import ../globals)
(import ../secrets)

(def data-dir "/var/lib/grafana")
(def grafana-init "/etc/init.d/grafana")
(def zfs-mounter "/etc/init.d/zfs-mount")

(role grafana
      # No mountpoint property means it is not mounted at all
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

               # Configure Grafana. Gurp will turn this struct into an ini file
               (def grafana-config
                 {:paths {:data data-dir
                          :logs "/var/log/grafana"
                          :plugins (pathcat data-dir "plugins")
                          :provisioning "conf/provisioning"}
                  :server {:protocol "http"
                           :http_port 3000}
                  :database {:type "mysql"
                             :host "mysql"
                             :name "grafana"
                             :user "grafana"
                             :password secrets/grafana-mysql-password}
                  :log {:mode "file"
                        :level "info"}
                  :news {:news_feed_enabled false}
                  :metrics {:enabled true}})

               (file/ensure "/etc/grafana.ini"
                  :from-struct grafana-config
                  :to-format "ini")))
````

This config doesn't actually start the `grafana` service. I drew the line at
managing rc services, so I added a `:final-state` property to the `zone` doer
that reboots the zone. The service starts on boot, and it's never a bad idea to
reboot-test.

Note that though Grafana is configured by an INI file, we do so here with a
Janet struct. This was suggested by a friend, who I think got it from Nix. The
`file` doer can take a `:from-struct` parameter, in which you define
configuration as, obviously, a struct. You then supply a `:to-format` value
which, at time of writing, can be `json`, `yaml`, `toml`, `ini`, or `kvp`. The
first three can hold any struct, so you're guaranteed to get what you ask for.
INI files are more limited, so you must write a struct that will fit into one.
`kvp` is key-value-pair, so you just need a flat struct for that. This, I
believe, is far more civilised than templating YAML files from other YAML files
templated from a YAML file.

Back to zone management though and, as I was doing a lot of testing, I found it
convenient to make a `(recreate)` helper function to recreate zones on demand.

```janet
(defn recreate?
  "If GURP_RECREATE_ZONE is a zone name, recreate that zone. If it's all, do them all"
  [zone-name]
  (def env-val (os/getenv "GURP_RECREATE_ZONE"))
    (if (or (= env-val "ALL") (= env-val zone-name)) 1 200))
```

It sits in the same file as the zone definitions which call it thusly:

```janet
(zone/ensure "serv-ws"
             :brand "lipkg"
             :recreate (recreate? "serv-ws")
             ...
```

If I want to just rebuild the package server zone:

```cmd
# GURP_RECREATE_ZONE=serv-pkg gurp apply zones.janet
```

will do it, and if I want to recreate all my zones, perhaps because I've changed
the gold zone config:

```cmd
# GURP_RECREATE_ZONE=all gurp apply zones.janet
```

will do it. And there's a 1-in-200 chance any zone will be recreated on any Gurp
run, just to keep things spicy.

## v1.1 update

I'm not sure if it's good form to go back and update blog-posty things, but I
reckon worse things are going on on the Internet today, so here's news.

As of v1.1.0, Gurp can create (and, obviously, destroy) `bhyve` zones. Bhyve
zones run a single process (other than the zone scheduler), which provides
standard virtualization via BSD's [bhyve](https://omnios.org/info/bhyve)
hypervisor. (I say BSD, but you'll find it everywhere now, not least as
[Oxide's hypervisor](https://docs.oxide.computer/guides/architecture/os-hypervisor-storage).)

```cmd
# ps -fz gurp-bhyve
     UID   PID  PPID   C    STIME TTY         TIME CMD
    root 22897     1   0 12:26:47 ?           0:00 zsched
    root 22979 22897   0 12:26:47 ?           3:32 bhyve-gurp-bhyve -k /etc/bhyve.cfg
```

Bhyve has a ton of options, the vast majority of which I've never had to deal
with, and the zone brand puts a simple shim around the ones you need to get
things going. Gurp puts a hopefully even simpler shim around that. Here's Just
Enough Gurp to create a bhyve zone.

```janet
(def zone-name "bhyve-example-1")
(def zone-addr "192.168.1.61/24")
(def zone-disk (zfscat "rpool/test" zone-name))

(host "serv"
      (zfs/ensure zone-disk :size "10G")

      (zone/ensure zone-name
                   :brand "bhyve"
                   (zone-network "bhyve1_net0"
                                 :defrouter "192.168.1.1"
                                 :allowed-address zone-addr)
                   (zone-bhyve
                     :vcpus 4
                     :ram "2G"
                     :image-url "https://dl-cdn.alpinelinux.org/.../generic_alpine-3.22.1-x86_64-uefi-cloudinit-r0.qcow2"
                     :boot-volume zone-disk)))
```

The first difference from a native zone is that bhyve needs a boot disk, which
is why we do that `(zfs/ensure)` with a volume size. The other difference is
that `(zone-bhyve)` function, here shown with its four mandatory arguments. We
need to know how much resource to give the zone, and we need to know where that
boot disk is, and what's going on it. A Bhyve zone could be anything: Linux,
Windows, BSD, Solaris, or something properly weird: all you have to do is write
an image to the disk.

You can define that image, like here, as a URL, which Gurp will download to, and
cache in, `/var/tmp` (Predictable filename! Security alert!).

```cmd
# gurp apply bhyve-1.janet
2025-09-29T15:38:32.773392Z  INFO doers::host: Configuring host: serv
2025-09-29T15:38:32.899375Z  INFO doers::zfs: creating filesystem: rpool/test/bhyve-example-1
2025-09-29T15:38:32.964795Z  INFO doers::zone::doer: Must create zone bhyve-example-1
2025-09-29T15:38:34.061336Z  INFO doers::zone::doer: installing bhyve-example-1 [bhyve]
2025-09-29T15:38:34.686614Z  INFO doers::zone::bhyve: Waiting for zone to be ready
2025-09-29T15:38:34.698758Z  INFO doers::zone::bhyve: Logging console output to /var/tmp/gurp-c2d9beeb-d6e9-449a-9e33-f036f2cfd3f3.log
2025-09-29T15:40:38.587242Z  INFO commands::apply: Run time: 125.849s
2025-09-29T15:40:38.587360Z  INFO commands::apply: resources: 2  changes: 2
# zlogin -C bhyve-example-1
[Connected to zone 'bhyve-example-1' console]

Welcome to Alpine Linux 3.22
Kernel 6.12.38-0-virt on x86_64 (/dev/ttyS0)

localhost login:
```

Now you can manually log in and configure it. How about not doing that though?
Gurp doesn't work on Linux, we've talked about that before, but it can get
started on configuring your new VM, via the "magic" of cloud-init.

```janet
(import ./globals)
(def zone-name "bhyve-example-2")
(def zone-addr "192.168.1.62/24")
(def zone-disk (zfscat "rpool/test" zone-name))
(def router-ip "192.168.1.1")

(host "serv"
      (zfs/ensure zone-disk :size "10G")

      (zone/ensure zone-name
                   :brand "bhyve"
                   (zone-bhyve
                     :vcpus 4
                     :ram "2G"
                     :image-url "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
                     :image-format "qcow2"
                     :boot-volume zone-disk
                     :cloudinit-files [(config-file "cloud-init/user-data")]
                     :cloudinit-struct
                     {:meta-data (cloudinit-meta-data zone-name)

                      :network-config
                      {:network {:version 2
                                 :ethernets
                                 {:enp0s6 {:addresses [zone-addr]
                                           :mtu 1500
                                           :nameservers {:search [globals/local-domain]
                                                         :addresses globals/dns-servers}
                                           :routes [{:to "0.0.0.0/0"
                                                     :via router-ip}]}}}}})

                   (zone-network "bhyve_net0" :allowed-address zone-addr)))
```

Gurp makes a temporary directory of cloud-init config which it turns into an ISO
image with `mkisofs`. This is mounted inside the zone, masquerading as a CD-ROM.
(Ask your dad.) Cloud-init sees this, looks for a `user-data` file inside it,
and uses same. As soon as the zone starts to boot, Gurp removes all of this from
the zone config, so it isn't there after a reboot.

You can copy local files into the image with `:cloudinit-files`. Here, we've
used the `(config-file)` helper to refer to files in `../files/` relative to our
config dir. `:cloudinit-files` is good for static policy type things that are
the same across all your VMs.

We also have a `:cloudinit-struct`. This struct's top-level keys are the names
of the files which will be created, and their values are a Janet struct which
will be converted to YAML. This suits dynamic content like the network config
here. In real life I abstract this away in a helper function, but I wanted to
show you the real-deal here. `(cloudinit-meta-data)` is a built-in Gurp library
function which creates a `meta-data` file to set the host name of the VM.

Debugging cloudinit can be a real pain. To help with this, Gurp streams the
console log into a local file, which has a random name, in `/var/tmp`. You can
see it mentioned in the output from earlier. It is also possible to have Gurp
exit as soon as it tries to boot the zone, by setting `:wait-for-boot false`,
and this can be useful in conjunction with `zlogin -C` if you're having problems
getting an image to work.

I have a Kubernetes cluster built on bhyve zones, and I managed to get most of
the configuration done with cloud-init, leaving only a couple of manual
operations. Maybe Gurp's bhyve support will be useful for you too.

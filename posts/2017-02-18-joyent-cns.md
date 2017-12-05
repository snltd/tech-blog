---
title: "Joyent CNS"
tags: [SmartOS, Joyent, DNS]
date: "2017-02-18"
category: Cloud
layout: post
---

It's a matter of public record that I'm a big fan of all things
[Joyent](https://www.joyent.com/). There are two reasons. First,
the Solaris heritage -- I'm an unapologetic Solaris fanboy, and the
only thing better than Solaris is SmartOS. Second, everything Joyent
offer is properly engineered. They don't reinvent wheels, but are
very adept at building simple, innovative products out of old
battle-hardened technologies.

An example of this is their Container Name Service, or CNS. This is
a for-free service-discovery mechanism, using old-as-the-hills DNS,
and not a lot more.

## Turn it On

If you have a JPC account, you've got to turn CNS on. All the
interactions in this little walk-through will use [the `triton`
CLI](https://github.com/joyent/node-triton). This is a nice,
intuitive tool with a clearly thought-out interface. It's simpler to
use than `aws`, but that might just be because Joyent's cloud is
nowhere near so featureful as Amazon's. And because it does't have
`--filters`.


```cmd
$ triton account get -j | json triton_cns_enabled
false
$ triton account update triton_cns_enabled=true
$ triton account get -j | json triton_cns_enabled
true
$ triton account get -j | json id
4c19787d-405b-477a
```

## Make Something

Okay. Done. Now, launch a SmartOS zone with a tag. This is going to
be a Wavefront proxy. All my other zones will use this to send
telemetry, so they all need to be able to find it.

```cmd
$ triton create \
    --firewall \
    -n wavefront-proxy \
    -m "user-script=curl -k https://us-east.manta.joyent.com/xxxx/bootstrapper.sh | sh" \
    -m environment=production \
    -m role=wavefront \
    -t triton.cns.services=wavefront \
    -t environment=production \
    b2d3c018 \
    14aea8fc
```

`--firewall` will block all access to the host unless external rules
allow it. We'll come back to that later.  `-n` is the name the
container will get. Each `-m` refers to some item of metadata: the
first downloads and runs my bootstrap script, which will look for
the `environment` and `role` values when it runs. The two arguments
are the image (think "AMI") and package (think "instance type").
Each `-t` declares a tag, and here we're interested in the first
one, which tells Joyent's system that I want this instance to get a
CNS DNS name with `wavefront` at the start.

Though I'm using a SmartOS instance, it could equally well be a
Linux instance, a Docker container or even something weird running
under KVM.

## CNS for Service Discovery

Once the instance is up (and it doesn't take long, because it's a
zone), we can ask for its DNS names.

```cmd
$ triton instance get wavefront-proxy | json 'dns_names'
[
  "dad27200-0a56-6aa9-c901-cba9715ac335.inst.4c19787d-405b-477a.eu-ams-1.triton.zone",
  "wavefront-proxy.inst.4c19787d-405b-477a.eu-ams-1.triton.zone",
  "wavefront.svc.4c19787d-405b-477a.eu-ams-1.triton.zone",
  "dad27200-0a56-6aa9-c901-cba9715ac335.inst.4c19787d-405b-477a.eu-ams-1.cns.joyent.com",
  "wavefront-proxy.inst.4c19787d-405b-477a.eu-ams-1.cns.joyent.com",
  "wavefront.svc.4c19787d-405b-477a.eu-ams-1.cns.joyent.com"
]
```

(A nice feature of `triton` is that you can refer to intances by
either the name you give them, or the unique start of their UUID.)

You can see the instance has automatically been given six DNS names,
all of which contain `4c19787d-405b-477a`. This is my account ID.
(It's not a real account ID, they are longer, but this one doesn't
mess up my formatting.)

The `.joyent.com` names resolve to the box's internal address, and
the `.triton.zone` ones to its external address, and they
refer to, in increasing order of scope,  that specific instance; any
instance with that name (which will be the same if I kill that one
and build another); or any instance with that tag, of which I may
have arbitrarily many.

From a box in my account, you can see the DNS search path is already
set.

```cmd
$ sed 2q /etc/resolv.conf
domain svc.4c19787d-405b-477a.eu-ams-1.cns.joyent.com
search svc.4c19787d-405b-477a.eu-ams-1.cns.joyent.com
```

So I can refer to my proxy just as `wavefront`, and it'll resolve.
If I add another Wavefront proxy (which would be wise), it will be
added to the reverse mapping, and clients are free to use either.

```cmd
$ dig +short wavefront.svc.4c19787d-405b-477a.eu-ams-1.triton.zone
37.153.109.201
37.153.111.77
```

Now service discovery isn't code registering instances from the Chef
index, or everything having to tell Consul where and what it is, or
`Ref()`s in a swathe of Cloudformation, or any of that nonsense. I
stand something up with, say, the `redis` tag, and anything smart
enough to know the Redis service is called `redis` will find it.

There is a potential problem in that the DNS name may resolve, and
be in the maps, before the service running on the host is fully up.
But you've written your applications defensively, right? So that
won't be a problem?

## CNS for Real DNS

In Triton, all my webserver hosts have the `www` tag. In my public
DNS I set `www.sysdef.xyz` as a `CNAME` to the
`www.svc.4c19787d-405b...` name.

When I deploy a new stack, I don't need to touch my DNS anywhere.
There's no need for jiggery-pokery in my Terraform config, or API
calls as part of my launch script or awful scripts that track an IP
address and update some `A` record somewhere. Instances can come and
go, but the ones that come, if they're tagged, will come into
service seamlessly.

As an aside, the final DNS piece, for me, is an
[NS1](https://ns1.com/)'s `ALIAS` to link the naked domain name to
the `www.` `CNAME`. I like NS1 a lot. You should have a look at
them, too.

## CNS for Security

To allow, or disallow, communication between instances and the
world, Triton uses what it calls a "Cloud Firewall". Like a normal
firewall, it lets you define rules base around `FROM`, and `TO`. My
Wavefront proxies, obviously should not be accessible to the outside
world. (I probably should put everything on a private subnet, but
that's for another article.) For now I shall a rule that says "let
all my instances talk to the Wavefront proxies on 2878 and 5044".
And it looks as simple as this:

```
FROM all vms TO tag "triton.cns.services" = "wavefront" ALLOW tcp (PORT 2878 AND PORT 5044)
```

So with CNS and Cloud Firewall, the joining-together of services
isn't done by creating security groups with in and out rules, and
giving things membership of (hopefully) the right groups.  It's done
by saying "these things can talk to those things", then calling
things what they are.  It's an extremely simple, and deceptively
powerful approach.

## CNS for the Win

Throughout this article I was tempted to use expressions like "by
magic". But CNS is most definitely *not* magic: what's happening is
obvious, simple, and very easy to understand.

We've tagged things in our clouds since time immemorial (2006-ish),
but those tags have always been passive. Things you probably won't
ever look at, possibly used by horrible API-calling scripts that
them to find things, or maybe for cost-allocation, but Joyent saw
the power of making them an *active* thing, with meaning throughout
your infrastructure.

On the surface, Triton doesn't seem to do much. It has three or four
services, a CLI without many commands, and a rather sparse UI. But
it's enormously powerful: it takes the "ops" approach of cleverly
using existing things, rather than AWS' "dev" approach of "write a
tool for that". Manta is the epitome of this, a concept so clever
and subtle that it seems to bypass most people altogether. I might
write something about that one day.

For now though, CNS: stupidly simple, brilliantly useful.

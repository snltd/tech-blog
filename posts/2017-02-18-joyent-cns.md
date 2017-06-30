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

If you have a JPC account, you've got to turn CNS on. All the
interactions in this little walk-through will use [the `triton`
CLI](https://github.com/joyent/node-triton). This is a nice,
intuitive tool with a clearly thought-out interface. It's simpler to
use than `aws`, but that might just be because Joyent's cloud is
nowhere near so featureful as Amazon's.


```cmd
$ triton account get -j | json triton_cns_enabled
false
$ triton account update triton_cns_enabled=true
$ triton account get -j | json triton_cns_enabled
true
$ triton account get -j | json id
4c19787d-405b-477a
```

Okay. Done. Now, launch a SmartOS zone with a tag. This is going to
be a Wavefront proxy. All my other zones will use this to send
telemetry, so they all need to be able to find it.

```cmd
$ triton create \
    -n wavefront-proxy \
    -m "user-script=curl -k https://us-east.manta.joyent.com/xxxx/bootstrapper.sh | sh" \
    -m environment=production \
    -m role=wavefront \
    -t triton.cns.services=wavefront \
    -t environment=production \
    b2d3c018 \
    14aea8fc
```

`-n` is the name the container will get. Each `-m` refers
to some item of metadata: the first downloads and runs my bootstrap
script, which will look for the `environment` and `role` values when
it runs. The two arguments are the image (think "AMI") and package
(think "instance type"). Each `-t` declares a tag, and here we're
interested in the first one, which tells Joyent's system that I want
this instance to get a CNS DNS name with `wavefront` at the start.

Once the instance is up (and it doesn't take long, because it's a
zone):

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

You can see the instance has six DNS names, all of which contain
`4c19787d-405b-477a`. This is my account ID, truncated it for
formatting reasons.

The `.joyent.com` names resolve to the box's internal address, and
the `.triton.zone` ones to its external address, and let me easily
refer to, in increasing order of scope,  that specific instance; any
instance with that name (which will be the same if I kill that one
and build another); or any instance with that tag, of which I may
have arbitrarily many.

If I add another Wavefront proxy (which would be wise), it will be
added to the reverse mapping, and clients are free to use either.

```cmd
$ dig +short wavefront.svc.4c19787d-405b-477a.eu-ams-1.triton.zone
37.153.109.201
37.153.111.77
```

There is a potential problem in that the name may resolve before the
service running on the host is fully up. But you've written your
services defensively, right? So that won't be a problem?

I can also use these tags in my firewall rules, so it's simple to
allow all my instances to talk to anything with the `wavefront` tag
on port 2878, or give all `app` instances access to `redis`
instances on 6379.

It's not a replacement for Consul, but it's good enough for my
needs, and would still be good enough if my requirements were
significantly more complicated. And it's all built on top of proven
technology that we all understand.

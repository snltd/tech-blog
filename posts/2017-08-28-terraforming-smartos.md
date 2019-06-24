---
title: "Terraforming SmartOS, from SmartOS"
date: 2017-08-28
tags: [SmartOS, Terraform, Go]
category: Terraform
---

My friend said:

> I've been building my own tooling with Terraform and Ansible. I
> call it "Terrible".

I loved that. For context, the team we worked in had been mired in
pointless, circular bikeshedding about what tools we should use to
deploy and configure our platforms.  At one point we were standing
up boxes with Fabric, raw Cloudformation, CFNDSL, shell scripts, a
home-grown Boto wrapper (which, to my satisfaction, pre-empted some
of the big features in Boto 3), and Footman, an in-house,
supposedly cloud-agnostic tool whose lasting legacy seems to be the
fact that a successful operation would be reported as `error:
undefined error`. Configuration management was a little better, with
warring limited to two main factions: the pre-existing Puppet, and
the would-be usurpers who wanted Ansible on their CVs. (By that
point we had managed to get rid of the inherited Chef repo which
included -- and used -- Puppet.  That was quite special.)

I've tried the back half of Chris' portmanteau, and found
configuration management with Ansible rather reminded me of the old
joke about the gynaecologist who painted  his hall through the
letter-box. I found the logic-in-YAML config files more distasteful
even than that. Watching the Footman project flounder and fail,
I came to the conclusion:

> Infrastructure as code. Yes. Infrastructure as config file. No.

This comes from using all the technologies listed above. If you want
to put six web servers behind a load-balancer, a config file might
just about describe it. Go much beyond that though, and you need to
start putting variables into your config file, and references, and
possibly ordering, and conditions, and templating. By that point,
what you've got is effectively code, but expressed in a very forced
and clumsy way. So I'd prefer someone to be straight up, and give us
some kind of DSL, that looks and behaves like a real language. After
all, aren't we all supposed to be devs these days?

Our client eventually standardised on CFNDSL-generated
Cloudformation, which is a mix of code and config-file, or a mix of
bad and worse, depending on your opinions. Most of the rest of the
world seems to like Terraform, and even though we work in an
industry where decisions tend to be made more on "what is everyone
else doing?" than "what is the right (or best) tool" I think it's
very important to properly try as many things as you can. By "try" I
mean use in some real sense, rather than following through one
elementary blog post. (Like this.)

My little pet projects, for the time being, use Puppet for their
config-management. The infrastructure, which runs on SmartOS VMs in
Joyent's "Triton" cloud, was originally deployed by a couple of
extremely simple shell scripts which wrap commands rather like this:

```cmd
$ triton create \
  -n www-$(date "+%Y-%m-%d-${RANDOM}") \
  -m "user-script=curl -k \
            https://us-east.manta.joyent.com/snltd/public/bootstrap-puppet.sh \
            | sh" \
  -m environment=production \
  -m role=sinatra \
  -t triton.cns.services=www \
  -t environment=production \
  2f538996 \
  14aea8fc
```

I'm hardly deploying Netflix here, but I thought it might be fun,
and informative, to give Terraform a go at deploying my little
system. The obvious, and well-trodden path would mean launching
AWS services from a Mac, but that's been done a million times and
I'd learn next to nothing. I'm a (reluctant) contrarian, and I'm
going to launch SmartOS instances, from a SmartOS instance.

Triton only provides compute, network, and storage services, so even
a tiny exercise like this has some value: it still covers most of
the things Triton can do. I won't be doing any Manta (object
storage) stuff here as the stack doesn't do anything with it.
(Though it fetches a pre-existing bootstrap script from there.)

## This is SmartOS

Everyone, apparently, thinks all kernels are Linux, all clouds are
Amazon's, and all shells are `bash`.  This can mean that running
modern tooling on SmartOS is more "interesting" than you might
expect.

Terraform, like anything with SRE pretensions, is written in Go, and
I was pleasantly suprised to see that [you can download a readymade
Solaris executable](https://www.terraform.io/downloads.html).  To date
I've found that Go programs built on Solaris always work on SmartOS
and vice-versa, so I grabbed it and closed the terminal with the `$
cd $GOPATH` in it.

Terraform has a core which manages its state engine and whatnot, but
all the actual work is done by "providers" which are not built into
the `terraform` binary. Most people probably never get beyond the
AWS ones, but we're going to need [a Triton
provider](https://www.terraform.io/docs/providers/triton/index.html).

To get it, we have to create the config file that will eventually
define our infrastructure. I made a `terraform` directory, opened up
`vi`, and declared my providers and credentials thus:

```json
provider "triton" {
  account = "snltd"
  key_id  = "e7:07:82:5d:f1:47:99:4d:6c:80:52:2d:f4:0f:ec:d5"
  url     = "https://eu-ams-1.api.joyentcloud.com"
}
```

I had to specify the `eu-ams-1` datacentre as my API endpoint,
because the provider defaults to US east, and, like Vincent Vega,
I've spent the last three years in Amsterdam. Note that the key ID
is supplied as a fingerprint. This means you need `ssh-agent` to be
running, and for it to be aware of the key. This caught me out,
because, for no particular reason, I don't generally use
`ssh-agent`.  If you're as backward as I am, you might have to do
something like:

```cmd
$ eval "$(ssh-agent -s)"
$ ssh-add ~/.ssh/id_rsa
```

I ran `terraform init`, and it went off to fetch everything I
needed. Except it didn't.  I have to jump forwards a little here,
for the sake of a more fluent article, and tell you that much of
what comes later does not work with the (at the time of writing)
default Triton provider.

The provider I got didn't support metadata correctly, and had no
idea what [CNS](/post/2017-02-18-joyent-cns) even was. Fortunately,
there's [a more up-to-date
one](https://github.com/terraform-providers/terraform-provider-triton),
but unfortunately, as of now, it needs to be compiled by you. I knew
I shouldn't have closed that terminal.

I had Go 1.6.4 installed. That was too old.  I tried 1.8 next, which
was the current "supported" version. But that [doesn't compile on
Solaris](https://github.com/golang/go/issues/20832).  I tried
1.9rc2, and that worked. Then I was able to build the better
provider.

A very nice thing about Terraform is that you can use as many
providers as you like. An obvious use for this would be to
simultaneously launch stacks in, say AWS and Azure, but providers
don't have to be cloud platforms. The next provider I'm going to use
is made by the very clever people at [Space
Ape](https://github.com/spaceapegames/terraform-provider-wavefront),
and it lets you configure [Wavefront](https://www.wavefront.com/)
alerts and dashboards as part of your stack. They haven't built
SmartOS support in, which is a little sad given that I banged on
about it constantly when I worked there, but it's easy to build.


```cmd
$ mkdir -p $GOPATH/src/github.com/terraform-providers
$ cd $_
$ git clone git@github.com:terraform-providers/terraform-provider-triton
...
$ cd terraform-provider-triton
$ gmake build
...
$ go get github.com/spaceapegames/terraform-provider-wavefront
$ cd $GOPATH/src/$_
$ go build
...
$ cd ~/work/terraform
$ terraform init -plugin-dir=$GOPATH/bin
...
```

The final command tells Terraform where to look for its providers.
Once it knows that, we're ready to go.

## This is Brilliant -- So Easy!

With everything installed and working I was ready to write a
configuration file describing my tiny little project: a couple of
native SmartOS zones, a few simple firewall rules, and two or
three Wavefront alerts.

Specifying a machine is, presumably to be more consistent with
Terraform standard practice, slightly different to the way to you do
it with the `triton` CLI.

The last two arguments to the `triton` command near the top of the
page are the short UUID for the image and the package. "image" is
like an Amazon AMI: the base OS. The, in my opinion, poorly named,
"package" is the instance size. Terraform insists that you use the
long UUID for the instance but the provider allows us to query the
API for a specific semantic version, or simply ask for the
`most_recent`. Great: that's far better than hardcoding instance IDs
(assuming we trust Joyent not to make breaking changes).  So put

```json
data "triton_image" "base" {
  name        = "minimal-64"
  most_recent = true
}
```

into the config file, and you can reference the value it fetches
with the not *too* onerous

```json
image = "${data.triton_image.base.id}"
```

Terraform also forces us to specify the package by name, rather than
by UUID. This is also good: `g4-highcpu-512M` makes a lot more sense
than `14aea8fc`.

Metadata and tags are specified as hashes (maps, technically), so
they don't need any explanation other than to point out that you
quote the values but not the keys. CNS requires that you use a hash
where the values are arrays. Putting all of that together, here's my
instance specification for a box which runs Sinatra-based websites.

```json
resource "triton_machine" "sinatra" {
  name             = "www-terraform"
  package          = "g4-highcpu-512M"
  image            = "${data.triton_image.base.id}"
  firewall_enabled = true
  user_script      = "curl -k \
                      https://us-east.manta.joyent.com/snltd/public/bootstrap-puppet.sh | sh"

  metadata {
    environment = "production"
    role        = "sinatra"
  }

  tags {
    environment = "production"
  }

  cns {
    services = ["www"]
  }
}
```

You can put comments in Terraform configuration files, but surely
there's no need in any of that? Terraform config is written in
Hashicorp Configuration Language. In my opinion "language" flatters
it. It's tarted up JSON with variables and references.

Creating Wavefront alerts was even simpler than making instances. I
exported the alerts I needed with [the Wavefront
CLI](https://github.com/snltd/wavefront-cli), and massaged them into
HCL.

```cmd
$ wf alert list | grep JPC
1490980663852  CHECKING  JPC: no metrics
1497275466684  CHECKING  JPC Failed Services
1502624543569  CHECKING  JPC zone out of memory
$ wf alert describe -f yaml 1497275466684
```

YAML is close enough to HCL that a bit of quick seddage converts it.
HCL accepts raw JSON (which the CLI can produce), but I wasn't
certain whether the provider would.  In any event, I also had to
delete most of the exported fields. Some can't be used in a
Wavefront API create operation (`id`) others aren't yet supported by
the provider (`description`).  The "failed services" alert ended up
like this:

```json
resource "wavefront_alert" "failed_services" {
  minutes   = 2
  name      = "JPC Failed Services"
  target    = "target:T0in8AtVb56Zkzlz"
  condition = "ts(\"smf.svcs.maintenance\", env=production)"
  severity  = "SMOKE"
  tags      = [ "JPC" ]
}
```

You have to supply at least one tag. Omitting the field or using an
empty array produced an error. I'm not sure if this is the fault of
the provider or the API, but you should be tagging anyway, so just
do it.

The `target` in that block is a pre-existing alert target which uses
a webhook to write to a Slack channel. You can (and obviously
should!) create alert targets with the provider. Just make a
resource and define it with HCL.

We're cooking now: stack, alerts, dashboards, everything. This is
brillant, right? Zero effort!

## Hang On, this is Harder than I Thought

When we defined the instance we set `firewall_enabled = true`.
Triton doesn't have IAM and security groups, which is good because
it means you don't have to deal with IAM and security groups. But
it's bad because there's less power. (For a start, you don't have
instance roles, which are great.)

Instead, Triton has its cloud firewall. Cloud firewall rules are
quite nice. They're flexible, and they're obvious to anyone with any
kind of networking knowledge. I find them easier to work with than
security groups as they express *relationships* rather than
permissions. I find, oddly, I can work just fine with security
groups so long as I don't think about them too much. When I start
thinking, I overthink, and convince myself they don't work how I
think they work. But I digress.

The Terraform SmartOS provider takes the lazy, but sensible shortcut
of having you define your cloud firewall rules  with native
[CloudAPI](https://docs.joyent.com/public-cloud/network/firewall/cloud-firewall-rules-reference)
data, rather than providing, say, native `from` and `to` attributes
in the way the Wavefront provider does. I originally made my
firewall rules through the UI, but getting the raw CloudAPI data was
easy. I've folded the last line to stop it overflowing the right
margin.

```cmd
$ triton fwrule list
SHORTID   ENABLED  GLOBAL  RULE
5782f65b  true     -       FROM any TO tag "triton.cns.services" = "www" ALLOW tcp PORT 80
c073ee65  true     -       FROM ip 217.169.11.241 TO all vms ALLOW tcp PORT 22
d407db1e  true     -       FROM all vms TO tag "triton.cns.services" = "wavefront" ALLOW tcp \
                           (PORT 2878 AND PORT 5044)
...
```

I've always wished AWS did something like this: create a resource in
the console, and view the Cloudformation that would create it.

It wasn't *quite* a copy-and-paste job to get the rules into
Terraform, as it's very finnicky about quoting. For instance, that
first rule has to be phrased *exactly* thus:

```json
resource "triton_firewall_rule" "http" {
  rule    = "FROM any TO tag \"triton.cns.services\" = \"www\" ALLOW tcp PORT 80"
  enabled = true
}
```

Get the case wrong anywhere, or don't soft-quote the `www`, and
every time you run Terraform it will think it needs to make a
change.

This is where I started to feel the difference between Terraform and
Cloudformation. There's a significant sense of what I might call
*disconnect* with Terraform. Action at a distance. Though I have
many beefs with Cloudformation, it has a sense of integration,
consistency and solidity which I don't get with Terraform.
Everything Terraform does is a mesh of public-internet API calls and
string parsing, and it feels like it.  Abstraction upon abstraction
upon abstraction.  Its approach to rollback -- pretty much "pick the
bones out of *that*" -- and its way of maintaining state feel crude.
But how else could it be? When I think about tools like Terraform
or, God forbid, Footman, I feel a sense of hopeless, endless
API-chasing. Endless 1:1 mapping. Endless issues and pull requests
and slippages and regressions. I'm not saying it shouldn't be done,
or that it isn't worth doing, or that nothing useful can be
produced, but it's not a job I'd want.

Still, this is better than using the shell scripts. Or, even if it
isn't, it's at least more "Google SRE Book". And apparently that's
what matters now.

## Oh. That.

Notice the final firewall rule above, which allows metrics and logs
through to a [Wavefront
proxy](http://sysdef.xyz/post/2016-03-30-wavefront-solaris). The
proxy host also gets a `triton_machine` definition much like the one
we saw before. But, it needs a secret: the token which the proxy
uses to connect to the Wavefront server. Yep. We're distributing
secrets. I'm using Puppet, so I could use something like
hiera-eyaml-gpg, but I would prefer the token to be made available
to the host as metadata. On SmartOS, Puppet automatically exposes
all metadata pairs as facts.

Being a by-the-book SRE, I want to keep my Terraform configuration
in Github, but obviously I don't want my secrets there. I don't need
something as heavy-duty as [Vault](https://www.vaultproject.io/), so
I put the following into my spec.

```json
variable "wf_token" {}
...
resource "triton_machine" "wavefront-proxy" {
...
  metadata {
    environment = "production"
    role        = "wavefront-proxy"
    wf_token    = "${var.wf_token}"
  }
...
}
```

You have to define the variable before you use it, which is not
unreasonable, but I somehow missed the fact when I read the
documentation, and it took me ages to work it out.

In a file called `sysdef.auto.tfvars` (my main spec file is called
`sysdef.tf`) I define the variable,

```json
wf_token = "---REDACTED---"
```

and Terraform will automatically include that file, parse it, and use
the value to put my token in the instance metadata. This
is good enough for me. Yes, if someone gets `root` on the box, they
can read the metadata, but they can also read the config file, or
the process memory, with the token in. Nothing's perfect, especially
when it comes to secrets.

So long as `sysdef.auto.tfvars` is kept safe, and not committed to
Git, our secrets stay secret. Right? Everything else is
version-controlled and we're golden.

Well, no. Because there's one so far unmentioned problem Terraform
has to deal with.  Developers of a particularly modern sensibility
might wish to retreat to a safe space, because I'm about to drop a
trigger word.

State.

No one likes state these days. They don't like it because it's
messy, and it's hard to do with their beloved immutable containers.
And because they don't want to deal with things that are messy and
hard, they dream up reasons why the hard thing shouldn't exist and
why you shouldn't ask them to do it.  But state is unavoidable in
anything non-trivial, and Terraform is capable of some seriously
non-trivial lifting, so it needs to store state.

Terraform compiles your desired configuration into one description,
which it compares with a second description of what is already
there. Then it diffs the two and works out how to get from A to B.
That second description is your `terraform.tfstate` file; a honking
great pile of JSON which a provider can turn into API calls and make
the magic happen.

`terraform.tfstate` therefore has to be kept safe. If it's lost,
Terraform won't know what your infrastructure looks like, so it
won't be able to calculate the differences it needs to make. And
because it's *calculated* state, it contains the secrets. In
plaintext.

Terraform has a bunch of
[backends](https://www.terraform.io/docs/backends/types/index.html)
which at least promise to take away the misery of storing state.
Different backends will suit different needs, and my needs couldn't
be simpler. I'm the only person working on a tiny stack. ZFS gives
me a versioned filesystems, and my workspace is automatically backed
up to Manta.  Losing the state file, frankly, doesn't much matter to
me. But if you were a team of a dozen people, making regular changes
to a complex infrastructure, you'd need something far more
sophisticated.

I can't get away from the thought that this model gives too much
scope for disaster: that is, for losing, corrupting, or getting
conflicts in the state file so it no longer reflects reality. This
isn't a worry I've ever had with Cloudformation. (So long as people
aren't tweaking things in the console after you've done a deploy,
but that applies equally to Terraform and everything else. You can't
be protected from that level of recklessness.)

## Nothing's Ever Simple is It?

The files I'd made by now were fine for standing up the stack in a
single-shot. But I regularly destroy and recreate instances, and I
couldn't see a way to do a rolling relaunch. (I miss ASGs when I
work with Triton.)

Being a small, clearly defined stack, blue-green deployments seemed
perfect. If I stood up a second stack alongside the first, my CNS
tags would automatically pull the new boxes into service, and I
could destroy the old stack at my leisure.

So I made `green/`, `blue/` subdirectories for each stack. Into
a third `common/` directory I moved everything that was the same
across stacks, and symlinked it into the stack directories. I put
the stack colour a variable (in `colour.auto.tfvars`) and added a
stack-specific name to the instance resources:

```json
name = "www-${var.colour}"
```

But.

## What?

Imagine the `blue` stack is up. When I applied the `green` stack, it
only created instances -- no firewall rules. Then when I destroyed
`blue`, the network rules disappeared.

Look again at the firewall resources. They have no `name`, `id`, or
anything else which can make them unique. They are identified purely
by their properties. So when it built `green` Terraform created, and
overwrote, the rules that were already there.  When `blue` was
destroyed, it included the network rules, so they were deleted, and
everything broke. I tried putting the stack colour in the
description field, but it seems Terraform ignores that when
calculating differences.

My solution was to have a `base` stack which contains all the
non-identifiable network rules. This goes up first, and the
application stacks sit alongside, or on top of it, depending on your
point of view. This works well enough

## Something's Been Bothering Me

I don't like this local storage thing. It's asking for trouble. And
what if this website suddenly takes off to the point that I have to
hire a team of crack SREs to keep it running? I should use a proper
backend. We should all use a proper backend.

If you looked at  the list of Terraform backends above, you'd have
seen there's [one for
Manta](https://www.terraform.io/docs/backends/types/manta.html).  We
don't need to compile it. We don't even need to `init` it.  it's
built into the core `terraform` binary.

The `base` stack is easy: I just added this:

```json
terraform {
  backend "manta" {
    path       = "terraform"
    objectName = "sysdef.base.tfstate"
  }
}
```

and made the remote directory I defined in it.

```cmd
$ mmkdir ~~/stor/terraform
```

For obvious reasons, the backend assumes your path is under
`~~/stor`, which is your private storage area. Therefore, you're
going to need credentials In addition to the usual creds needed for
the `mmkdir` command to work, I also had to declare
`MANTA_KEY_MATERIAL` in my shell. Its value is the path to the SSH
key I use to access Manta. It seems the backend can't pick the key
up via `ssh-agent` like the `triton` provider can.

Running `terraform plan` told me there was no remote state, and
asked if I wanted to take the local copy and upload it. I did.
Sweet.

I said the base was the simplest stack. If you recall, the blue and
green stacks use the same configuration, one being a symlink. All
stack-specifics are put in through the `${var.colour}` variable. So
the obvious thing to do is pop this into `sysdef.tf`

```json
terraform {
  backend "manta" {
    path       = "terraform"
    objectName = "sysdef.${var.colour}.tfstate"
  }
}
```

Obivious, right? And like most obvious things, it doesn't work.

```cmd
$ terraform plan
Failed to load backend: Error loading backend config: 1 error(s)
occurred:

* terraform.backend: configuration cannot contain interpolations
The backend configuration is loaded by Terraform extremely early, before
the core of Terraform can be initialized. This is necessary because the
backend dictates the behavior of that core. The core is what handles
interpolation processing. Because of this, interpolations cannot be
used in backend configuration.

If you'd like to parameterize backend configuration, we recommend
using partial configuration with the "-backend-config" flag to
"terraform init".
...
```

Wow. Whoever writes the error messages for Puppet needs to have a
word with whoever writes them for Terraform, because that is great.
I looked up `-backend-config` ([single-dash long
options are wrong
btw](https://twitter.com/no_identifier/status/902508998003482624)),
and it was plain all I had to do was
delete the `objectName` property from the `backend` definition,
then re-initialize the stack directories.

```cmd
$ pwd
/home/rob/work/terraform/green
$ terraform init -plugin-dir=$GOPATH/bin \
  -backend-config="objectName=sysdef.green.tfstate"
Initializing the backend...
Do you want to copy state from "local" to "manta"?
...
$ cd ../blue
$ terraform init -plugin-dir=$GOPATH/bin \
  -backend-config="objectName=sysdef.blue.tfstate"
Initializing the backend...
...
```

That creates, in both directories, a `.terraform/terraform.tfstate`
file, which contains the full backend configuration. There's no need
to reference it explicitly. Check the remote:

```cmd
$ mls -l ~~/stor/terraform/
-rwxr-xr-x 1 snltd          2867 Feb 25 13:28 sysdef.base.tfstate
-rwxr-xr-x 1 snltd         13630 Feb 25 13:42 sysdef.blue.tfstate
-rwxr-xr-x 1 snltd           317 Feb 25 13:42 sysdef.green.tfstate
```

remove the local state files, and rest easy.

## So?

My considered professional opinion on Terraform puts somewhere near
the top corner of Gartner's "err, yeah, it's okay, and some things
are really nice but it also feels a bit hacky and I'm not that sure
how much I trust it" quadrant.

Truth is, much as I frequently find myself hating it, Cloudformation
is miles ahead of anything else in the infrastructure-as-config-file
world. For the massive sprawl of AWS -- and assuming all my stuff
was in AWS -- I wouldn't use anything else.

Triton is not like AWS. It has very few services, and very few
resource types, to the point that a single, small, Terraform
provider covers them all. This makes infrastructure definition far
simpler, and I'd like to see a dedicated Clouformation-style
infrastructure building service in Triton.  Perhaps it could be
Terraform, the state stored by Joyent, with a tighter coupling to
what's really there, rather than what Terraform's state file says is
there.

I've been running my "triple-stack" approach for a few months now,
and it works just fine. Because my stacks are so tiny, it doesn't
save me any work, and clearly it's grossly over-engineered.
But, it's given me some learning, and that's never a bad thing.

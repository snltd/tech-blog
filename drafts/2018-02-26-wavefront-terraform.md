---
title: "Making Telemetry Part of a Deployment"
date: "2018-02-26"
tags: [Terraform, Wavefront]
layout: post
category: Terraform
---

> This article is based on a segment of [an earlier
> one](https://sysdef.xyz/post/2017-08-28-terraforming-smartos).
> The original offers far more opinon on deploying a stack with
> Terraform, whilst this concentrates solely on integrating
> Wavefront with Terraform. I'm not going to talk about state files,
> or secret management, or any of that.

Once upon a time, I worked in aerospace, and I built boxes for test
environments. I would spend the morning following a printed list of
instructions, to the letter, and the afternoon filling in forms to
confirm I had done what I was told. Virtually nothing was automated.

When Sun released Jumpstart, things changed. We could automate the
configuration of boxes: in 1998 I wrote a web portal which let users
deploy hosts with Jumpstart, customising various templated
configurations. *Plus ça change, plus c'est la même chose*.

Twenty years later, Terraform takes that idea a layer down the
stack, allowing you to configure *infrastructure* (and
Chef/Puppet/Whatever configures the hosts -- assuming you still use
hosts!).

People tend to think of Terraform as a thing which deploys VMs, but
it's more flexible than that. It uses plug-in *providers* to talk to
different APIs, and there's no reason at all why those APIs should
end with Amazon, Azure, or Triton. They can be *anything*.

For example, the very clever people at [Space
Ape](http://www.spaceapegames.com/) have made a [Wavefront
provider](https://github.com/spaceapegames/terraform-provider-wavefront),
which can deploy [Wavefront](https://www.wavefront.com/) alerts and
dashboards as part of your stack. This is particularly useful
because, although Wavefront's UI lets you clone dashboards and
alerts, we don't want to go back to the days of doing things by a
literal book. We want to stamp out full environments, from the VPC
subnet layout to the executive dashboard the boss likes on his big
TV.

## Introductions

The Wavefront provider isn't part of the core Terraform
distribution, so your first job is to install it. This is
particularly easy if you're on Linux or a Mac, in which case you
only have to [grab a
binary](https://github.com/spaceapegames/terraform-provider-wavefront/releases)
and `mv` it to `~/.terraform/terraform-provider-wavefront_v1.0.2`
(or whatever the version number is). We're going to use the
[wavefront-cli](https://sysdef.xyz/post/2017-07-26-wavefront-cli)
here, so you may wish to install that. That's even easier (assuming
you have a modern-ish Ruby):

```cmd
$ gem install wavefront-cli
```

Now we can start writing our configuration. I'm going to use a
standalone file called `wavefront.tf`, but you'd more likely want to
embed this in a larger file with the resources you plan to monitor.

We have to tell Terraform we want to use our new provider, and
whilst we're doing that we're going to have to tell the provider
itself who it needs to talk to.

I'm going to put this in `wavefront.tf`. Your company name will be
different of course, unless you actually work for MyCompany PLC.

```json
provider "wavefront" {
  address = "https://mycompany.wavefront.com"
  token   = "67a0de4d-2b18-a24e-8cea-2c9ae9b00a15"
  version = "~> 1.0"
}
```

That's not a real token, so don't go getting any ideas, okay? On the
subject of tokens, in real life you'd be storing this config in your
VCS, so you obviously wouldn't leave any secrets in there. Terraform
has multiple ways of dealing with this, but they're not in the scope
of this discussion.

## Let Me Give You My Number

Dashboards are nice, but alerts are essential, so let's start with
those. Actually, let's not, because the correct way to handle alerts
in Wavefront is via *alert targets*, or in API-speak, *notificants*.

You can point multiple related alerts at the same target, then if
the people who need to be notified, or the method by which that is
done, changes, you only have to update the target. They're smart, so
let's send our alerts using one.

I've found the simplest way to Terraform my Wavefront stuff is to
make my alerts and whatnot in the console and get them just right,
then export them. Let's use the CLI to find out what notificants we
have,

 ```cmd
$ wf notificant list
CHTo47HvsPzSaGhh  WEBHOOK  Slack alert webhook
EKdKFv1rJ6iPahqI  EMAIL    Alerts from lab machines
T0in8AtVb56Zkzlz  EMAIL    alerts from JPC production instances
...
```

I'm going to take everything related to my
[JPC](https://www.joyent.com/) stack, and control it with Terraform.
So let's get that last target.

The CLI has recently (in vesion 2.4.0) acquired the ability to
output information in a way that is broadly compatible with
the Wavefront Terraform provider. That is, in
[HCL](https://www.terraform.io/docs/configuration/syntax.html).

So we can pull an existing alert target out of Wavefront and into
our configuration-as-code by doing:

```cmd
$ wf notificant describe -f hcl T0in8AtVb56Zkzlz >>wavefront.tf
```

The CLI does its best to write compatible HCL, and jumps through a
few hoops.  Some of the keys chosen for the provider don't quite
align with the keys used inside Wavefront, and the provider
sometimes insists a resource has properties which you may not have
given it. For instance, the provider insists alerts and dashboards
have tags, but Wavefront itself does not. So if you see this:

```
$ terraform plan
1 error(s) occurred:

* wavefront_alert.4030f5b9-18ee-47e9-ad4d-726f5184c74d: "tags":
* required field is not set
```

you'll have to manually add some tags inside the given resource:


```
tags = ["tag1", "tag2"]
```

(The array can be empty, but tags are good. Tag. You'll feel better.)

You can see from the error above that Terraform resources
have a unique identifer. Thi is used when one resource
cross-references another. The CLI generates a random UUID for each
resource it creates, but you can change it to something meaningful
if you want.

Running

```cmd
$ terraform plan
```

and assuming you don't get the `require field` error, you should see
that Terraform wants to create an alert target. Great! We have enshrined
that target in code now, so it should (should!) be safe to delete
it, either from the console or the CLI.

```cmd
$ wf notificant delete T0in8AtVb56Zkzlz
```

## Call Me

We have a target that knows how to get hold of us. Let's set up an
alert. Again, I'm going to export an existing one.

```cmd
$ wf alert list
...
1502624543569  CHECKING           JPC zone out of memory
$ wf alert describe -f hcl 1502624543569 >>wavefront.tf
```

That's added the alert to our Terraform config, but we want to use
the target we just created, which didn't exist at the time the alert
was created.  This easy to do with Terraform.

In `wavefront.tf`'s `wavefront_alert` block, just change the `target`
value to

```
"target:${wavefront_alert_target.<uuid>.id}"
```

where `<uuid>` is the UUID attached to the `wavefront_alert_target`
resource we made earlier.

Now, a `terraform plan` will tell you that it wants to create two
things. Terraform prints out resources alphabetically, but the
variable reference means that it knows to create the target first.


## What's Up?

Dashboards are big, complicated objects with lots of nested
properties.

```cmd
$ wf dashboard describe log -f yaml | wc -l
1220
```

The Terraform provider, at the moment, does not cover all of those
properties, and I've had varying levels of success creating
dashboards. The CLI code which generates the dashboard HCL is a bit
hairy and hacky too. Still, it might well work for your use-case,
and the provider will become more complete over time. As it does,
the CLI will grow to keep up.

You can tell what's coming, can't you?

```cmd
$ wf dashboard list | grep JPC
jpc-telegraf                            JPC telegraf
jpc-webhost                             JPC Website Host
$ wf dashboard describe -f hcl jpc-webhost >>wavefront.tf
```

Just like before, we dump and existing dashboard to Terraform, and
`terraform plan` tells us it's going to create it. If you have
faith, you may delete the existing one (dashboards deleted once go
in to the trash, so you can get them back), but you might also
prefer to change the dashboard name in `wavefront.tf` and see if it
imports alongside the old one.

## We Should Do This More Often

So now you have working templates for alerts, notificants, and
possibly dashboards. You're likely building up and tearing down
stacks like it's going out of fashion, possibly as part of a CI/CD
pipeline. Get that Terraform config in there! When you stand up or
recycle an environment, or product, the alerting and monitoring
should "just happen" without a second thought.

Any part of any property of any resource can be a variable,
populated from some other input to Terraform. We already saw HCL's
variable interpolation when we referenced the alert target earlier,
so you already know how easy it would be to customize your embedded
queries with, say the environment name, or to have an alert target
write to the Slack channel of the team which owns the product.

Infrastructure as code is vital today, and monitoring is an
essential part of any infrastructure. It should be defined in
code, version-controlled, templated, and repeatable.

## Postscript: We're Just Not Compatible

What if you don't use Terraform?

At my client's site, they're committed to using AWS services
wherever possible, so everything is deployed with Cloudformation.

We still wanted to create our alerts and dashboards with our stacks
though, and have settled on a pattern of exporting everything
relevant with the CLI, and turning the output into an ERB template.
Simply, we change a string like `env=dev` to `env=<%= @environment
%>`. The
variables are populated, and the template rendered, by a `Rakefile`
which also kicks off the `cloudformation create` operation. So, the
telemetry comes up with the stack.

As a part of the tear-down of a stack, the `Rakefile` invokes the
CLI to do `delete` operations on the relevant resources.

This isn't as nice as the Terraform solution, because nothing
happens on a `cloudformation update`, so it doesn't let us tweak an
existing config, or guarantee that what's in Wavefront is what's in
Git.  On the plus side, since the CLI deals in raw JSON, it's not
dependent on anyone else's code, and we don't have to wait for the
provider to cover new features as they arrive.

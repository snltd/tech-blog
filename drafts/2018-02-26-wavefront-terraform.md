---
title: "Wavefront and Terraform"
date: "2020-09-28"
tags: [Wavefront]
layout: post
category: Wavefront
---

I currently work on a project to facilitate cloud migrations within a large
corporation. We customize AWS and Azure accounts, trying to balance the user's
need for freedom with the regulatory requirements of the business as a whole.
We offer all our customers easy access to Tanzu Observability by Wavefront.

Everything we do happens via a pipeline, and when that pipeline applies its
various guardrails and facilitators to a customer account, it builds Wavefront
proxies, links Wavefront to the customer's AWS or Azure account with a
suitable integration, and creates alerts specific to that customer. We use the
proxies ourselves too, collecting telemetry on the customer's behalf,
aggregating all manner of useful information in dashboards and alerts.

We think of Wavefront as an essential infrastructure component, so it is
deployed, like all our other infrastructure, with Terraform.

I'm going to assume you're at least familiar with the concept of Terraform, so
I won't be talking about installing it, or ways of managing state, or any of
that.

Instead I want to talk about how we use the Terraform [Wavefront
provider](https://registry.terraform.io/providers/vmware/wavefront/latest)
in the context of a CI/CD pipeline, running in AWS CodeBuild.

## The Basics

The Wavefront Terraform provider was born in 2017 at [Space
Ape](http://www.spaceapegames.com/) (from whom I first heard of Wavefront,
back before it even had a website). Wavefront took over maintenance in early
2020, and now it's an official Terraform provider in the VMware namespace.

Because it's an official provider, there's no work to do beyond telling
Terraform you wish to use it and, since it needs to talk to Wavefront's API,
declaring your API endpoint and a suitable token.

It's good practise to keep your provider definitions in one place. So let's
make a `versions.tf` file to tell Terraform we want to do Wavefront stuff. As
of right now, Terraform is at version 0.13.3, so that's what we'll assume
through this article.

Here's a bare-bones `version.tf`.

```
terraform {
  required_providers {
    wavefront = {
      source = "vmware/wavefront"
    }
  }
  required_version = ">= 0.13"
}
```

Though you can pass  the endpoint and token when you initialise the provider,
it's best not to: after all, this file is likely to go into version control,
where it might be seen by goodness knows who.

The provider can also take information from the `WAVEFRONT_ADDRESS` and
`WAVEFRONT_TOKEN` environment variables, so we populate those early in our
pipeline, taking them from encrypted values in AWS Parameter Store.  Your
secret management may be different from ours, but you're going to have to put
that token somewhere safe, and make it visible to Terraform through that
`WAVEFRONT_TOKEN` variable.

If you want to play along at home, `export` your `WAVEFRONT_ADDRESS` and
`WAVEFRONT_TOKEN` now. Any kind of user will work, but we have a dedicated
[service account](https://docs.wavefront.com/accounts.html#service-accounts)
for our pipeline, with its own token and [ingestion
policy](https://docs.wavefront.com/ingestion_policies.html).

Now we can make a `main.tf`:

```hcl
provider "wavefront" {
}
```

Then run `terraform init` to install the provider. Now we're ready to make a
resource.

## Alert Targets

Let's start with an alert target, or in API-speak, a _notificant_. We send all
our alerts to a Slack channel, and SEVERE ones also go to Pagerduty. Let's
have a look at the Slack one for now.

Assuming you have [a Slack channel set up to receive
alerts](https://docs.wavefront.com/slack.html#slack-setup), making Terraform
create and manage the target is as simple as putting this into, say,
`alert_target-slack.tf`.

```hcl
resource wavefront_alert_target example {
  name         = "An example Slack hook for example alerts"
  description  = <<-EODESC
    An example of how to create a Wavefront alert target from Terraform.
  EODESC
  method       = "WEBHOOK"
  recipient    = "https://hooks.slack.com/services/${var.slack_hook_key}"
  content_type = "application/json"
  triggers     = ["ALERT_OPENED", "ALERT_RESOLVED"]
  template     = file("${path.module}/resources/slack_hook.tmpl")
}
```

You can create e-mail or Pagerduty targets just as easily. Note that the alert
template is in a separate file. This lets us have multiple targets which use
the same Slack template, which we've tailored to our (minimal) needs.  Keeping
things like templates in their own files also makes for cleaner Terraform
code, as that big blob of text is a bit unweildy.

The easiest way to get the target template is to create a target in the UI and
copy and paste the template out.

We pass the `recipient` key in as a variable, so we can use the same Terraform
module to create targets for different customers using different Slack
channels. The pipeline, or course, populates the variables.

We also create an `outputs.tf` file which we'll use later on. The output for
the alert target is its ID.

```hcl
output target_id_slack {
  description = "ID of example Slack alert target"
  value       = wavefront_alert_target.example.id
}
```

If you run `terraform apply` now, you'll see the target configured in
Wavefront. `terraform destroy` will, of course, remove it.

## Alerts

Creating an alert to use that target is no harder. Here is a nice simple one.
(With a nonsense condition for the sake of brevity.) This might go in
`alert.tf`.

A `wavefront_alert` resource may have [many
properties](https://registry.terraform.io/providers/vmware/wavefront/latest/docs/resources/alert)
Here

example of one. Put it in a file `alert-example.tf`.

```hcl
resource wavefront_alert example {
  name                   = "Example alert"
  condition              = "2 > 1"
  additional_information = <<-EODESC
  This is a really simple alert that will always fire.
  EODESC
  display_expression     = "2 > 1"
  severity               = "WARN"
  alert_type             = "CLASSIC"
  minutes                = 5
  resolve_after_minutes  = 5
  tags                   = ["Wavefront", "example"]
  target                 = wavefront_alert_target.example.target_id
}
```

Hopefully it's clear that the `target` property references the alert target we
created earlier. Terraform is smart enough to know to create the target first,
get its ID from Wavefront, then use that ID in the API call which makes the
alert. `target_id` is a special property: alerts reference a target
not just through its sixteen-character ID, but through a string prefixing that
ID with `target:`. The `target_id` property does that prefixing for you. If
you want multiple targets, comma-separate them in a single string.

Our pipeline has a Terraform variable holding the tags we apply to all alerts
we manage, and we add any extra tags on like this:

```hcl
tags = concat(var.alert_tags, ["Wavefront", "example"])
```

This makes it easy to identify the alerts we own. We use the
`additional_information` field for our runbook. When an alert fires, the
engineer looking at it should not only see what's going wrong, but should get
useful information on how to diagnose the fault further. We include likely
causes, links to dashboards, and even contact information. We also try to make
the `display_expression` as useful as possible. Sometimes it can be quite
different from the expression which triggers the alert.

An interesting problem we found with deploying alerts as part of a pipeline,
along with the infrastructure they observe is that the alerts are often up and
running long before the infrastructure exists which will satisfy the alert
condition. So, we have to think carefully about writing conditions which can
detect a non-reporting source, but not fire before any data has been seen. Up
to now we've managed this by wrapping our alerts in `if(lag())`s, but the
provider now supports maintenance windows, and we are considering applying a
short maintenance window to alerts in a new deployment, silencing false
alerts and avoiding potentially confusing logic in the alert conditions.

## Access Control

Though our customers are free to create their own alerts in the UI or
(ideally) through their own pipeline, we don't want them to modify ours.
Though Terraform would revert any modifications back to the state defined in
the code, it's better to lock the alerts down with ACLs.

Let's make an `alert_managers` group, with a role granting the required
privilege. You might put these in `groups.tf`.

```hcl
resource wavefront_user_group alert_managers {
  name        = "Alert Management"
  description = "Users with the power to manage alerts"
}

resource wavefront_role alert_management {
  name        = "Alert Management"
  permissions = ["alerts_management"]
  assignees   = [wavefront_user_group.alert_managers.id]
}
```

Again, we should add the IDs of those resources to our `outputs.tf`, along
with the ID of the alert we made earlier.

Now we can add this line to our `wavefront_alert` resource:

```hcl
  can_modify = [wavefront_user_group.alert_managers.id, "sa::pipeline"]
```

Note that we have our pipeline user in that ACL.  It's very easy to forget the
account doing the Terraforming and end up creating resources your pipeline
can't modify. Think carefully when using ACLs!

Though we only want Alert Management people to be able to modify the alert, we
might want anyone to be able to have a look at it. Or, rather, `Everyone`.
`Everyone` is a default Wavefront group to which new users are added, unless
they are specifically created as members of some other group.

`Everyone` has a randomly generated ID, and we just saw that ACLs need an ID,
not a name. Fortunately, the Wavefront provider gives us a _data source_ that
will let us access it.

So if we put this in our Terraform code:

```hcl
data wavefront_default_user_group everyone {}
```

We can add this to our alert resource.

```hcl
  can_view = [data.wavefront_default_user_group.everyone.group_id]
```

That's pretty much a finalized, production-ready alert, in a very little work.

## Cloud Integrations

Installing a proxy isn't done with the Wavefront provider. Proxies sit in,
say, AWS, or Azure, so they are deployed with the AWS or Azure providers.

Installing a Cloud Integration, however requires teamwork between your cloud
and Wavefront providers.

So, to integrate with AWS we'll need to revisit `versions.tf` and add the AWS
provider. We'll also need `time`.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    wavefront = {
      source = "vmware/wavefront"
    }
    time = {
      source = "hashicorp/time"
    }

  }
  required_version = ">= 0.13"
}
```

You'll also need to make your AWS credentials visible to the provider. If
you're running locally, this is probably as simple as `export
AWS_PROFILE=profile_name`. You'll also have to re-run `terraform init`.

Here's a much-simplified version of the code we use to create AWS
integrations. We scrape Cloudwatch metrics, and get the [AWS
Metrics+](https://docs.wavefront.com/integrations_aws_metrics.html#aws-metrics-data).

```hcl
resource wavefront_cloud_integration_aws_external_id default {}

resource aws_iam_role wavefront {
  name               = "example-wf-integration"
  assume_role_policy = <<-EOPOLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::301213811993:root"
          },
          "Action": "sts:AssumeRole",
          "Condition": {
            "StringEquals": {
              "sts:ExternalId": "${wavefront_cloud_integration_aws_external_id.default.id}"
            }
          }
        }
      ]
    }
  EOPOLICY
}

resource aws_iam_role_policy_attachment read-only {
  role       = aws_iam_role.wavefront.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource time_sleep sleep {
  depends_on      = [aws_iam_role.wavefront]
  create_duration = "10s"
}

resource wavefront_cloud_integration_cloudwatch cloudwatch {
  depends_on                      = [time_sleep.sleep]
  name                            = "example AWS integration"
  role_arn                        = aws_iam_role.wavefront.arn
  external_id                     = wavefront_cloud_integration_aws_external_id.default.id
  service_refresh_rate_in_minutes = 5
  force_save                      = false
}

resource wavefront_cloud_integration_ec2 ec2 {
  depends_on                      = [time_sleep.sleep]
  external_id                     = wavefront_cloud_integration_aws_external_id.default.id
  name                            = "example AWS integration"
  role_arn                        = aws_iam_role.wavefront.arn
  service_refresh_rate_in_minutes = 5
  hostname_tags                   = ["host", "source", "name"]
  force_save                      = false
}

output external_id {
  description = "integration external ID"
  value       = wavefront_cloud_integration_aws_external_id.default.id
}
```

This tells Terraform to fetch an "external ID" from Wavefront. This is a
random string used a little like a shared secret between Wavefront and AWS.
Terraform then uses the AWS provider to create an IAM role which allows the
Wavefront account (301213811993) read-only access, provided it also passes the
correct external ID. Then it creates two integrations in Wavefront, telling
them the external ID they must pass, and the ARN of the IAM role they need to
assume.

Our real code uses a lot of variables, to adapt the allow/deny lists for
metrics and so-on.  I've left in the `force_save` parameter, because for a
time we had this set to `true`, and experienced a number of silent failures.
We prefer our pipeline to fail the moment anything goes wrong.

The `time_sleep` resource and dependency are there because we found that
sometimes the call to create the integrations happened before the IAM role was
available, causing the task to fail. The `time_sleep` gives more than enough
breathing space to fix this. I'm not fan of sleeps in any kind of program as
any kind of fix, but here it was necessary.

## Dashboards

The Wavefront Terraform provider offers a couple of ways to get dashboards
into Wavefront.

First, you can write your dashboard in HCL. This, in my opinion, is not a
great idea. Dashboards can get very big very quickly, and they were never
meant to be built in a text editor.

Second, there's the `wavefront_dashboard_json` resource type. This simply
takes a big chunk of JSON and plonks it into the dashboard API. Now, writing
your dashboards in JSON would be even worse than writing them in HCL, but
you can easily export an existing dashboard.

In the UI, edit the dashboard, and you'll see a `JSON` button in the bar at
the top. Click that, then in the editor that opens up, there's a drop down for
`Tree` or `Code`. Select `Code`, ctrl-a, ctrl-v (or whatever works on whatever
you use) and you have the raw JSON, ready to paste a
`wavefront_dashboard_json` resource.

Alternatively, make an API call youself, or use [the `wf` CLI
tool](https://sysdef.xyz/article/wavefront-cli).

```
$ wf dashboard export -f json <id>
```

`wavefront_dashboard_json` is happy for you to embed the JSON in the `.tf`
file with a `<<-HEREDOC`, but I much prefer to store each dashboard in its own
file, and pull it in with the `file()` function like we did with the alert
template.

You may, like us, choose not to Terraform most of your dashboards at all.
Having used Wavefront for some years now, I find dashbaords are a never-ending
project.  Every query in every chart constantly proves its value -- or lack of
value. I find I'm constantly tweaking: honing a query, changing the chart
type, taking out things I never look at or adding new charts which have just
helped me out of a tight spot. Our dashboards end up being very collaborative,
and we encourage everyone to improve them Our dashboards end up being very
collaborative, and we encourage everyone to improve them.

We want our customers to make Wavefront work for them, so we prefer to clone
them dashboards as a starting point, which they can adapt to their particular
needs.

Remember also that Wavefront keeps a history of dashboards: if you want to
roll back to a previous version, you can do it in the UI. So you don't have to
dig through Github to get that one chart back.

All of that said, on a previous job, we needed to stamp out immutable,
finished dashboards for new stacks and new environments. If that's your
use-case, `wavefront_dashboard_json` is your friend.

## Minority Interests

The provider is still growing, and though it most likely offers all you need,
it doesn't yet cover every resource type.

The Wavefront API is very good though, and very easy to use. Before Cloud
Integrations were supported in the Wavefront provider, we  had no problem
managing them with Mastercard's [REST
API provider](https://github.com/Mastercard/terraform-provider-restapi).

So if you need to manage external links, or ingestion policies, there is a way
to do it.

But better still, implement any missing functionality in the provider and
share it with the world -- it's open source after all!

## Pipeline Stuff

We run our pipeline often, and there are often multiple runs in progress,
which must all be kept separate. We use Terraform workspaces, and we have
different phases of our pipeline (dev, integration, gatekeeping) run in
different accounts. But there's only one Wavefront, and all our pipelines have
to manipulate that.

To avoid runs treading on each other's toes, we have our pipeline generate a
random string of fixed length which is appended to the identifiers of all
resources the pipeline creates. When we do a "real" deployment, that suffix is
blank.

Don't worry about creating and deleting stuff all the time. The provider
hard-deletes, so things don't end up hanging around in the trash. (And even if
they did, trashed alerts don't count towards your quota.)

It's not related to the Terraform provider, but our pipeline, reports lots of
information into Wavefront, giving us detailed statistics on all our builds
and deployments.

## Tests

Our pipeline doesn't just deploy to our own accounts, but to those of our
customers. So, we have to be very careful, and test everything we do.

Mostly this means end-to-end functional tests. When we create Wavefront
proxies, for instance, we send real data to them, then run real queries against
Wavefront, guaranteeing the data we see arrives and is as it should be. We
apply preprocessing rules, so we must guarantee the metrics not only arrive,
but are tagged correctly. We've written a nice library of `assert_()`
functions based on [Space Ape's Go
SDK](https://github.com/spaceapegames/go-wavefront). Sadly I can't share that
with you at the moment.

Alerts are tricky to test.

Often it is difficult or impossible to deliberately cause an alert to fire.
For instance, we monitor our point rate, and alert if a significant proportion
of our telemetry disappears, or if we send more points than we pay for.  We
can't do either of those things for real.

Some alerts also have very long trigger times, or use long time-window
functions.  Triggering one of these and waiting to see the alert would add
many minutes to a pipeline run. So in most cases the testing of our alerts is
a simple check that the thing we asked to be created has been created.

All our test files contain a function which uses
[Terratest](https://github.com/gruntwork-io/terratest) to execute our
Terraform code, capture the outputs (remember I said we'd need them later?),
then tear down everything it made.  Then we inspect and `assert()` on the
output objects, checking whatever we feel we should.

With most of the detail removed, it looks something like this:

```go
func TestWavefrontAlerts(t *testing.T) {
  testInfra := createInfra(t)
  testHighPointRateAlert(t, testInfra)
}

func createInfra(t *testing.T) *terraform.Options {
  infra := &terraform.Options{
    TerraformDir: "../examples/wavefront-alert",
    Vars: map[string]interface{}{ /* we set module variables here */ },
  }

  t.Cleanup(func() {
    terraform.Destroy(t, infra)
  })

 terraform.InitAndApply(t, infra)
  return infra
}

func testAlerts(t *testing.T, testInfra *terraform.Options) {
  id := terraform.Output(t, testInfra, "alert_id_broken_integration")
  wavefront.AssertObject(t, "alert", id, "target", targetWarn.String())
  wavefront.AssertObject(t, "alert", id, "severity", "WARN")
  wavefront.AssertObject(t, "alert", id, "condition", "ts(\"sre.wavefront.integrations\") = 0")
}
```

`wavefront.AssertObject()`  has this signature:

```
func AssertObject(t *testing.T, objType string, id string, chkField string, chkVal string)
```

It asks Wavefront for an `objType` object (e.g. an alert, or dashboard) with
with the ID from the object's `output{}`.  Then, if the object exists, the
function looks to see whether it has a property `chkField` with the value
`chkVal`.

We test Cloud Integrations similarly: waiting to see the data would take too
long, so we don't do it. But we do [monitor for Cloud Integrations which are
not collecting any
data](https://github.com/snltd/wavefront-integration-checker), so should the
pipeline break one, or fail to set one up correctly, we'll soon know about it.

## End

Once you start using Wavefront, it quickly becomes a core component of your
infrastructure. So treat it as such. Automate it, test it, and reassert its
state just like you would with a VPC, an ALB, or any other first-class
component.

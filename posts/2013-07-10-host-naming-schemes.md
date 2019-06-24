---
title: "Host Naming Schemes"
tags: [policy, Chef, anal-retentiveness]
date: 2013-07-10
category: Chef
---

You wouldn't think that, in 2013, you'd still have to tell people the
importance of a decent host-naming scheme. Surely we've all grown out of
calling things after *Star Wars* characters. But, having just been in a
meeting with Amazon, and hearing about its Chef-based
[OpsWorks](http://aws.amazon.com/opsworks/) project, we apparently
haven't.

I work as a contractor, and I move between a lot of sites. I appreciate
documentation of all kinds, but I like nothing more than things with
document themselves. The most obvious of these is the host naming
scheme.

# War Stories

I've seen more than a few ways of naming hosts on my travels. One site
took "host names" literally, and used names for their hosts. People's
names. Given names *and* family names. Every machine had an internal and
an external DNS name. So, from the inside, you'd refer to one of the
webservers as "leonardo" from the inside, but from the outside it
resolved to "davinci". Obvious, right?  The problem was that you needed
a reasonable knowledge of literature to understand that "nadine" and
"gordimer" referred to the same machine, and be a good-spelling
astrophysicist to remember "subramanyan" was also known as
"chandresehkar". As a contractor, I spent over half a day on that site
trying to find "george". It turned out to be a virtual circuit on a
content switch. Work that out from the name. Someone had to pay me half
a day's rate, and push everything else back half a day, because someone
else thought they were being "clever".

Another site used a lot of Sun Clusters, and the pairs were thematically
named. For instance, "flyover" and "underpass". Great, you can tell
which machines form pairs with only a little lateral thinking.  But what
you can't tell is what those servers might do, which business unit they
belong to or, more imporantly, which server is on which site.  Every
cluster had a node in each of the two data centres the business owned,
and there was also a SAN in each. As I was doing a SAN migration, I
needed to know which SAN was local to which host. I couldn't tell from
the hostname, and no one else knew which was where either. So, lots of
time finding people and asking, resolved eventually by a time-consuming
trip to a data centre. We also had an alternative energy naming theme,
including "solar", "wind", "wave", and "tidal".  Can you spot the two
nodes of a cluster in there? Me neither.

Way back in the day I took delivery of a lab full of Sun workstations.
Now, here's where the old "call them after anything" scheme isn't too
offensive. If it's called after a colour, it's in the second floor lab
- I can just about live with that, workstations aren't important, and as
admins, we'll rarely have to log into them. BUT, we had one user, a
mathematician, who wanted to name all the new hosts by alternative
spellings of "Chebyshev", his favourite number-theorist. Wikipedia lists
only seven transliterations, but my user believed there were many more
than that, and gave a list of them to put into my Jumpstart
configuration. I declined.

# Where, What, Who, How Many?

I built a completely new infrastructure at the site with "subramanyan
chandresehkar". We had almost all Sun gear, with a dash of Linux, and at
the time things were being built, a single data centre near Coventry,
with plans to move some kit to another in London. I wanted anyone to be
able to look at the hostname of a machine, and tell where and what it
was doing. For instance: `cs-infra-01`. `C`oventry datacentre.
`S`olaris host. `infra`structure server number `01`.  Simple, and the
dashes, though they make it a little longer to type, make it much easier
to read than `csinfra01`. A Linux mailhost in the London datacentre?
That'll be `ll-mail-01`. Obvious.

That site used a lot of Solaris zones. In fact, pretty much everything
was in a non-global zone, with globals acting only as hypervisors, much
in the way SmartOS does things now. Mail didn't run under Linux in
London, but under Solaris in Coventry, in a zone on each of the
aforementioned infrastructure servers. `cs-infra-01z-mail`. It's a mail
zone, on the first infrastructure server, running Solaris, in Coventry.
A bit long, I admit, but I think much more helpful than "gustav", which
it replaced.

I did run into problems when we started using zones inside Logical
Domains, ending up with things like `cd-01d-dbz-mysql01`, which I admit
needed a bit of unpicking. (`C`oventry `D`omain server `01`; `D`omain
`db`; `z`one `mysql` instance `01`  We didn't have many of those though,
and I never said the system was perfect!  Perhaps you can have too much
information?

# Naming Schemes and Configuration Management

Finally, I get to the point I wanted to make, which is that under
configuration management, naming schemes are more important than ever.

To date, I have worked on two Chef projects of significant size and
complexity. In one, the site already had a strong naming scheme of the
form `environment-product-service[0-9][0-9]` The second had a kind of
half-baked system where you could tell the physical location of the
host, possibly work out its environment, and probably tell at least some
of the purpose.

At the first site, a `knife` plugin expanded the hostname of the
instance you wished to start, and could easily work out what environment
the node should be in, and which roles it needed. This gave us an
elegant, easy to maintain and understand system with little repetition.
In the second, we had to use node files to describe everything.
Time-consuming and error-prone.

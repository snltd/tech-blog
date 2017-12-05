---
title: "Case Study: Virtualizing an Existing Solaris ISP Environment"
date: "2012-03-05"
tags: [Solaris, ZFS, zones, virtualization]
layout: post
category: articles
---

# The Context

My client was a mid-sized not-for-profit organization. It was made up of
a number of departments, all of whom had access to "hosting", which
existed to provide whatever was required for those departments' online
presence.  Effectively, hosting was a small, independent ISP.

Hosting was nothing but trouble. From the customer's point of view, the
service was unreliable, with terrible security issues. From management's
point of view, it was overcomplicated, a drain on resources, and
generally far more trouble than it was worth.

I had worked on the old platform a few years before, when the job was
constant firefighting. When I was hired again, it was with the brief to
"fix hosting".

# The Problem

## A Broken Platform

There had been nothing approaching a CTO, or any kind of strategy, for
most of the prior lifetime of hosting. Customers had been given whatever
they wanted, whether it was the right thing to do or not, poor decisions
had been made early on, and much of the infrastructure felt like a
loosely connected bunch of CV-building exercises.

We ran a mix of Solaris 8 and 9 on a variety of [mostly old SPARC
hardware](http://en.wikipedia.org/wiki/Sun_Fire). The racks were
primarily full of  v100s and v210s, with a few T2000s and a v480 cluster
with a bunch of [Photon
arrays](http://sunsite.uakom.sk/sunworldonline/swol-11-1997/swol-11-photon.html)
hanging off it.  The cluster was Veritas (VCS), with the disks managed,
naturally, through VxVM.  The license cost a fortune, no one in the
organization really knew how to work it,  and it wasn't even configured
properly. (It once took a whole weekend to fail over an NFS service.)
Add to this the fact that the big 480s and the Photons, with sixty-six
10,000rpm disks, were probably sucking down more power than everything
else put together. This had to go.

The UPS and the air-con were sweating, constantly above 90% capacity,
and we were paying too much to Sun for support on too much ageing
hardware, the vast majority of which was overspecced for the job it was
doing.

Nothing was built the same way; the only constant was that everything
was built with everything: we were spending hours every night backing up
entire distributions.

It was clear that the way to fix hosting was to rebuild it, from the
ground up. But what exactly did I have to rebuild?

## No Documentation

The first problem was that we had little idea what we had. Everything
was scattered everywhere, and the problem was this basic:

* We didn't have a definitive list of sites we hosted
* We didn't know which sites were hosted on which servers
* We didn't know the specs or support agreements of any hardware
* We didn't know which of the hundreds of DNS names, Apache vhosts, or
  MySQL databases we had were still current, or which organizational
  units owned them.

The only documentation I could find was that which I'd written three
years before, and that was no longer current. Throw in [the world's
worst host naming
scheme](http://snltd.co.uk/snippets/index.php?c=v&sn=naming_scheme.php),
completely inconsistent and illogical naming and layout of everything
cluster-related, and you had a heck of a knot to unpick before any kind
of work could be done.

## Poor Dialogue With Customers

We hosted a lot of legacy and third-party sites. In many cases we
weren't able to find out who owned the things we knew we had. A lot of
code which did have an owner was very old and unmaintained, and people
were not prepared to spend money to have it fixed or updated. This led
to...

## Frequent Security Issues

Sites had been hacked several times, through gigantic security holes
down to poor coding and exploits in ancient software. The nature of the
shared hosting (many Apache vhosts on a small number of servers; content
shared by NFS, writable by the web server user) meant than when one site
was compromised, many others were too. Even the people who did look
after their code had their sites defaced or removed due to the neglect
of those who didn't.

When I started looking around, I found autoindexed directories visible
to the world, containing, among other things, raw SQL dumps of the
production databases!

## A Mess of Software

We had a lots of software, in lots of versions. Many sites were PHP, and
no two servers ran the same version. We had MySQL 3.0, 4.0, 4.1 and 5.0
services on the cluster, as well as Oracle. ColdFusion, Tomcat and JRun.
We had two backup systems (NetBackup and Amanda), some email was handled
with Exim, some with sendmail. We ran a Lotus Notes on old Netra T1.
And, as I said earlier, it wasn't clear how much of this was current or
essential to the business, and even less clear how it hung together.

## A Messy Network

We had about forty servers, and eight or nine subnets. We therefore had
too many NICs in use, too much cabling, too many routers, and a horrific
situation where a Cisco CSS had been strongarmed into becoming the heart
of the network. It joined pretty much everything together, and had the
most dreadful configuration. I say we had too many routers, but from
another point of view we didn't have enough. The CSS handled most of the
routing, and it handled it slowly.

NFS was over-used. Everything was on NFS. When you requested a page, the
content came from one of a number of NFS shares on the cluster. The logs
were on NFS too, and the subnets hosting the NFS shares communicated
with the web servers by going through the aforementioned CSS *twice*.

## No Monitoring or Alerting

We had Nagios, but it did pretty much nothing, and no one looked at it
anyway. Almost everything in it was red because the config was years out
of date. We had no off-site monitoring of the web sites.

## The System was Live

I had to build a new system, but it had to be done alongside the old
one. Minimal downtime was vital.

## No Hardware

I had little or no budget, so a new platform had to be build on on the
existing hardware.

# The Solution

The first thing I did was prioritise. The constant security issues meant
a new, heavily virtualized, web-server tier couldn't come soon enough. I
also had a lot of machines serving web content, and consolidating them
would free up some much-needed hardware. The lowest priority was the
backups: there was a well set-up L25-backed Netbackup system.

## Policy

I have a lot of jobs, and I have to deal with a lot of mess people leave
behind. This only adds to my obsession with the following aims.  In my
opinion, systems should be:

* **minimal**. Everything that exists should exist for a reason. Just
  enough to do the job. No more.
* **standard**. Use industry-standard tools wherever possible, and
  configure them in the standard way. Scripting in weird languages, or
  using some weird 0.0.0.x version of something from Github instead of a
  simple shell script is not the way to be a good Ops guy. It's the way
  to be a devops hipster, and no one likes devops hipsters.
* **documented**. Don't tell me in detail *what* you've done: I can see
  that for myself. I do want a high-level overview of the system, but
  most of all I want to know *why* you've done what you've done. If I
  see some weird anomaly on a box, I might be tempted to change it to
  match everything else, but that might break something. If you tell me
  why it has to be like that, I won't. Documentation is great, but not
  as good as a system which is
* **self-documenting**. Good naming schemes. Comments in scripts and
  config files. These things shouldn't need pointing out any more, but
  apparently they do. CMDBs are very useful, so long as they are
  dynamically updated. I *really* want an overview of the system
  that isn't Nagios.

Solaris 10 was a perfect fit for this project, with its lightweight
virtualization. It was still pretty new back then, with few
best-pracices defined, so I had to come up with rules myself. The
following seemed sensible.

* **Every service in its own non-global zone**. The global zone should
  act almost solely as a hypervisor.
* **Similar services share a box**. Webserver hosts contain only
  webserver zones and so-on. This allows you to do:
* **Management from the global zone**. Why run monitoring or
  log-rotation in hundreds of NGZs when you can run it in a dozen
  globals? Configure it smartly in the global so it can handle the
  appearance and disappearance of zones, and you can set it and forget
  it.
* **Separation of OS and Data**. I've always been a big believer in
  this. Put the OS in its own partition or pool, and if you need to
  reinstall it, you don't have to migrate data off and back on. I took
  this further, by having my third-party software installed under
  `/zonedata/zone-name/local` in the global, and mounted, where possible
  read-only, under `/usr/local` in the NGZ. The `/zonedata` datasets
  where in the data pool, so they could also survive a rebuild of the
  OS. So `local` software directories could be shared between zones,
  software was built or run to find its config files in `/config`,
  which was loopback mounted from `/zonedata/zone-name/config`.
* **Least privilege**. Solaris has very sophisticated RBAC, tightly
  integrated with SMF. I wanted every service I created to run with only
  the OS privileges it absolutely needed. I also wanted software to be
  built with only the extensions it needed, which leads to:
* **Build software ourselves**. This is a bit contentious I know, but,
  as I said earlier, I had my reasons. For performance, and because I
  hate having to carry around `libgcc_s.so` and `libstc++.so`, I used
  Sun Studio.

## Safety and Security

Every box was a properly minimal build: extraneous packages and users
were removed, and only essential services ran. I did this through the
Jumpstart server, and applied every hardening method I'd picked up in 15
years as a Solaris admin. Everything was, of course, behind a firewall,
and the various subnets could only talk to one another on the ports they
absolutely had to.

As I've said, all the action happened inside a zone, so it was important
to protect those zones from one another. In those days you couldn't
throttle ZFS on a per-zone basis, so there was no way to stop an I/O
intensive zone from interfering with the others, but it was possible to
stop a runaway dataset filling the disk and DOSing the rest of the box.
So, all zone datasets were capped with ZFS quotas.

Sparse zones were not only quicker to install, quicker to patch, and
more economical on disk than whole-root ones, but also have the
advantage of mounting most of the operating system read-only, which is a
very nice security feature. We didn't have Crossbox in Solaris 10, so I
mostly used shared IP instances. As like services shared physical hosts,
and were therefore on the same subnet, this was generally fine. (Except
in a couple of cases, which I'll come back to.)

I resource-capped all non-global zones, on CPU and memory. Initial
limits were educated guesses, but I watched usage closely, and didn't
have to make many adjustements. The shared IP meant that, theoretically,
a single zone could consume all available bandwidth, but there wasn't
much I could do about that, given the limits of the technology.

The principle of least privilege mentioned above was followed through by
analyzing all our custom services with `ppriv`, and removing or adding
privileges from the SMF manifests as required. Things like Apache and
`named`, which normally run as root, didn't. They ran as specially
tailored users, usually with less privilege than a normal interactive
user would be given.

Just in case of compromise, globals had different passwords from the
NGZs, and you couldn't SSH into the global from the NGZ anyway.

## Audit

Working out what we had was the first hands-on job. I wrote
scripts that scoped out all the hardware and OS configurations;
worked out what Apache configs applied to which DNS names; generated IP
address maps and compared to the internal DNS; things like that. Most of
this eventually ended up in [s-audit](https://github.com/snltd/s-audit).


## Begin at the Beginning: A Build Server, a File Server, and a Repo

This meant a first, clean Solaris 10 install with Sun Studio and just
enough tools to build the Open Source software I wanted to use. I hated
the "install everything" approach the previous sys-admins had used, and
I knew that with the amount of legacy we had to accomodate, I couldn't
rely on Sun's provided packages of things like Apache, MySQL and PHP.  I
never like the third-party freeware options, with their dependency
rabbit-holes and weird filesystem layouts. Better, I thought, to do it
ourselves, and build what we needed, how we needed it.

I didn't just need to build software though, I needed to build servers.

I wanted everything configured uniformly right from the start, so a good
Jumpstart setup was vital.  I already had [a proven Jumpstart
framework](https://github.com/snltd/Gentle-Jumpstart), which I'd used on
a number of jobs, and I didn't need the complexity and overhead of JET.
I put together minimal profiles, and was ready to build.

I also built a new NFS server. We had a 3510 array that was supposed to
replace the Photons, but the previous admins had never been able to get
it to work properly. We spent a little money buying a new v245, because
we didn't have any hosts which could take two HBAs, and we obviously
wanted as few single-points-of-failure as possible.

After much reading and benchmarking, I decided to use the 3510 as a
JBOD, having ZFS handle the RAID.  The 3510 was given fully up-to-date
firmware, its controllers set for full redundancy, and it was configured
for in-band and, in case of emergency, out-of-band management.

## Custom Tooling

It very quickly became apparent that the amount of zones we were
building required something quicker and easier to use than a manually
driving `zonecfg` and `zoneadm`. So, I wrote what ended up as
[s-zone](https://github.com/snltd/virtualization-tools/blob/master/s-zone.sh).
This let us build a variety of heavily customized zones from a single,
concise command, and also expunge them completely from the system when
we didn't need them any more.

The Jumpstart framework grew a little, s-audit grew a lot, and, with
hindsight, you'd call it devops. I wrote [ZFS
tools](https://github.com/snltd/ZFS-tools), to automatically snapshot,
and recursive-send datasets long before things like time-slider, the
`auto-snapshot` service, and `zfs`'s `-R` flag were available.

## The Web Tier

I managed to snag a few T2000s from a defunct project. With their large
number of CPU threads and super-fast IO, these were perfect for the
virtualized web-server tier.

Beginning with a pair of top-spec machines, the plan was to have a
separate sparse zone on each one for each website we hosted, with a
load-balancer in front handling the traffic. If we needed more capacity,
we could scale horizontally.

When I found legacy sites which weren't being developed any more, I put
the code into Subversion, exported it on both zones, and loopback
mounted the `/www` filesystems read-only. That way, if the sites
continued to be compromised, they couldn't be defaced, and no one else
would be affected.

I custom-built Apache, with only the modules essential to the sites. It
was installed in `/usr/local`, loopback mounted, read-only. Where sites
didn't need their own Apache or PHP (which it turned out most did), the
`/usr/local` mounts were shared between zones. This made it easy to
upgrade software across multiple zones.

We always tried the latest-and-greatest versions of software, and if
sites didn't work, went backwards until we hit the latest version that
did. Sometimes that got complicated and long-winded, with a couple of
sites requiring PHP extensions that in turn required very specific
versions of various libraries. (We ended up building a PHP 3.0.8 server
in 2009!)

The new zones were configured in the existing front-end load balancer,
clearing out all the old config as we went, so we ended up with a
super-simple, tiny configuration. Sensible naming conventions built
around zone names, which came from the site names they served, made for
a self-documenting configuration anyone could understand at a glance.

Apache logged locally, rotating via `cronolog`, which gave us a
performance boost over the old NFS logging. A script on the file
server harvested old log files every night, being smart enough to know
what should and shouldn't be there, and alerting accordingly. It made
one query to the global zone, accepting the coming-and-going of NGZs
without complaint. It also expired the very old logs at the file server
end as it went.

Another T2000 was added as a dev/staging box. It began as a direct clone
of live, giving the developers the chance to easily trial on a
equivalent-to-live environment.

## Releasing Code and Content

As our NFS server was a single-point-of-failure, I wanted to get away
from NFS-mounted content as much as possible. To that end I wrote a
script which sat on the file server and deployed code. A flat file
mapped site-names to directories and target hosts, and a single
invocation would take a ZFS snapshot of the source directory and `rsync`
from it to the appropriate hosts. (This guarantees all targets get the
same, consistent, data.) Once that was done, the snap was removed. If
nothing had changed, it did nothing, so it could run via `cron` for
rudimentary CI. I also wrapped it with a simple web interface, so
developers could release their own code on demand.

The CRM system was built around webDAV, and people wrote and read a fair
bit of data through Subversion.  So, it seemed natural to put webDAV and
SVN in their own zones on the fileserver, with direct access to the
disks they needed. In the past people had had difficulties getting
permissions of things uploaded by DAV, the CRM system itself,
Subversion, and normal users to play nicely, and ended up with horrible
"777" `umask` and `chmod` hacks. A bit of careful thought and UID
mapping eliminated this, and got things working in an elegant, secure
fashion.

## Infrastructure

Migrating all web servers on to the T2000s gave me a stack of v210s I
could re-use, and a stack of v100s I could throw in a skip. So, I next
set about migrating DNS, mail, DMZ SSH hosts, log archiving, and a whole
bunch of other services onto a couple of said v210s.

I made two of everything, splitting primary and secondaries across the
two hosts so losing one was no more significant than losing the other.

As we moved DNS, I wrote a script to automatically test everything in
the zone files, weeding out the dead entries. The infrastructure
migration took over a dozen unpatched, messy as hell servers and put
everything they did on two tight, economical boxes.

By rejigging the IP address space we managed to lose a couple of
subnets, and by being smarter with scheduling, eliminated the need for a
dedicated backup network entirely. This was also helped by the fact we
were backing up a fraction of the data we were before.

We also took the opportunity to completely recable, clearing out more
redundant wiring than we ever imagined, losing a couple of switches, and
colour-coding cables to subnet. We turned miles of incomprehensible,
tangled, sagging pink spaghetti into something you could understand by
glancing at it.

System logs went over the network to a super-locked-down syslog server
zone. We were able to analyze these, and the archived webserver, logs
with [Splunk](http://www.splunk.com).

As hosts were built in the new system, their LOMs were brought
up-to-date, configured to present the hostname in the prompt, password
protected, and put on the management subnet. Internal DNS was updated to
have the hostname of the node with `-lom` attached to it.

The infrastructure boxes needed to have legs on all the subnets, as some
of the zones only needed to talk to  particular subnets. It's no problem
just to give a zone ownership of a physical NIC port, but a few things
needed some non-trivial routing, which ended up in a a slightly nasty
transient SMF service that waited for zones to come up, then dropped in
routing according to a config file. Of course, with Crossbow, we
wouldn't have to do that today.

## Databases

We had another contractor in who knew more about MySQL than me, and he
chose to have a pair of DB servers, with each version of MySQL running
in a separate zone on each host. They were in master-master replication
mode, and behind a load-balancer. Where we had access to the code, we
migrated applications by changing the database host, and once we'd
proved the new database servers were good, we pointed everything else at
it by remapping DNS and turning off the cluster services.

Again, we tried every database on the latest (at the time 5.0) MySQL,
and moved backwards if there were problems. We ended up with four zones
on each DB host.

We had hundreds of databases which we suspected weren't being used. I
wrote a DTrace script which watched filesystem activity to see which
databases were being read from or written to (ignoring backups and
dumps), and left it running for several weeks. By looking at the
aggregated buckets in the output, we had a realistic view of usage, and
were able to get rid of a huge amount of unneeded data.

Development databases ended up being put in a dedicated zone on the dev
box (which opened me up to the "joys" of tuning MySQL for the
T-series!). This protected live from mistakes, and, working with the
devs, let us trial new configs or versions of MySQL on live-like data.

## Oddballs and LDOMs

A couple of [weird
applications](http://snltd.co.uk/snippets/index.php?c=v&sn=webx.php)
wouldn't run in zones, because they required system calls which weren't
permitted inside a container. (Now, you can usually fix this with the
`limitpriv` setting, but that wasn't available then.)

## Monitoring

This was early days for zones, and none of the industry standard
monitoring frameworks knew how to deal with them. We inherited a broken
Nagios setup, and made some token attempt to fit the new hosts into it.
(We had a contractor in whose first attempt to write zone-aware NRPE
plugins resulted in a fork-bomb that DOSed everything he ran it on. We
let him go.)

We also had the remnants of a poorly implemented Big Brother setup, but
I like that even less than I like Nagios. As the system settled in, I
had some free time, and ended up writing a [small, very zone-aware
monitoring system](https://github.com/snltd/snltd-monitor) from scratch.
It was simple, but worked very well.

I've always believed very much in monitoring the service, rather than
the boxes. We had nothing like that in the original setup, so we set up
a [Site24x7](http://www.site24x7.com) account to keep an eye on the
service as a whole.

## DR

I was kept a couple of spare chassis racked up, so should one of our
creaky old boxes fail, all I had to do was pull disks and network
cables, stick them in the spare, and be back up and running in a couple
of minutes. I tweaked the OBPs of the spares to boot as quickly as they
possibly could. I thought about some kind of clustering for the 3510,
but it seemed too complex a solution for this system. So, I built and
maintained a spare v210 with an HBA that could be manually swapped over,
and the Zpool re-imported.

I also wrote a [disaster recovery script for
zones](https://github.com/snltd/virtualization-tools/blob/master/s-dr.sh),
which worked in tandem with s-zone to rebuild a trashed zone in seconds.
As soon as Solaris supported it, I migrated all the zones to ZFS roots,
to take full advantage of snapshotting. (I was slower to migrate whole
servers to ZFS root, but got there eventually.)

We took nightly incremental backups with Netbackup, but also flash
archived the servers regularly, so we could quickly bare-metal restore
from the FLARs should the need arise. The Jumpstart framework was
adapted to handle FLARs automatically: a simple `boot net - install` of
an existing server would rebuild from the latest archive, preserving the
data and `local` Zpools.

## Backups

Though the existing NetBackup solution had been a good one, we had an
entirely new estate. We were also two major version numbers behind
current on the NetBackup software and the OS which hosted it, so we
built a new box, with fresh policies for the new system. As our builds
were so minimal, we realized we could get a lot of benefit from a
disk-based media server. If we needed to recover in a hurry, there would
be a good chance that whatever we wanted would still be on that staging
host, and recovery would be fast and simple, likely with no need to
revert to tape.

We commandeered a stack of unused commidity hardware, and built up a
media server, using Solaris 10 X86, chucking all the disk (other then
OS) into one huge compressed zpool.

I wrote a [script which harvests NetBackup log
data](https://github.com/snltd/misc-scripts/blob/master/bpdb_get_records.sh)
and fed it to a special [s-audit](https://github.com/snltd/s-audit)
panel.

## Patching

I believe in patching aggressively. Like CI, applying patches as they
come along isn't likely to break things; applying huge great bundles
every couple of years is. With minimal builds, patching is quick, and
with ZFS snapshots, it's easy to roll back if you need to.

I wrote [a script to patch servers
consistently](https://github.com/snltd/misc-scripts/blob/master/patch_system.sh).
You would patch a dev box, and once it was proved good, the script would
patch live to the exact same specifications. We never had a patch break
anything.

# What Would I do Differently If I Did it Again?

Surprisingly little. Bearing in mind that the majority of this work was
done in 2007, when the technology was new and the territory relatively
unexplored, I think we got a lot right. It's been nice to see certain
design decisions vindicated by the likes of Joyent.

Today, I'd do the more complicated scripting in Ruby, and dashboards
with Sinatra, rather than the mix of shell and PHP I used before.

I'm not sure what OS I'd use. Solaris 10 still gives me everything I'd
want, and it's still fully supported. The more heavyweight approach to
zoning in Solaris 11 has plusses and minuses; and I dislike IPS.

Another interesting area is configuration management. I have strong Chef
experience now, and given that we had a dynamic, scalable, virtualized
environment, it's very tempting to think Chef would be an excellent fit.
But, the environment was also small. I've worked on a multi-thousand
instance estate, and you simply can't run something like that without
sophisticated configuration management. But, there's a curve of
effort-in versus benefit-out, and I'm not

Logging has (finally) moved on in the last couple of years, and
I would probably  not have anything logging straight to disk any more,
but everything going into, say, Logstash.

We had a few bad experiences with master-master replication. Nowadays,
I'd look at Percona and MariaDB's native clustering.

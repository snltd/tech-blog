---
title: "Why I Hate DevOps"
date: "2015-05-05"
tags: [DevOps, Rant, "Professsional Suicide"]
layout: post
category: articles
---

Since, I think, 2011 I have earned my living as something called "a
DevOps Engineer". For about fourteen years before that, I was a
sys-admin.

In the late 1990s I enjoyed being a sys-admin. You ran the systems,
so you had to know something of everything which affected them. You
understood the hardware well enough to spec it, order it, rack it,
cable it, upgrade it and diagnose it to an extent where you could
make meaningful support calls. You understood the operating system
in detail: you had to, because the OS was king, and everything else
was about keeping it happy and ticking along. You understood
storage, DNS, how mail worked, IP networking, webservers, security,
and you touched on all of these things every day.

You knew how to code too. You scripted, in shell and maybe Perl,
because no fool does things by hand which can be automated, and
computers are very good at automation. You likely knew C as well,
because most of the stuff you worked with came as source code, and
it wouldn't be surprising if it didn't build cleanly on whatever you
were using, so you'd be fettling at least `Makefiles` and `.h`es
until it did. You also knew a bit of whatever language your
developers were using (probably Java), because you'd have to help
with code releases, application tuning and debugging.

Of course, you didn't understand all of these things in depth; that
would be ridiculous. And, as time went on, parts of the job grew,
and duly became specialisms. Networking and security went early,
with sophisticated appliances which required vendor training and had
to meet increasingly complex requirements. Soon we were asking the
SAN teams for LUNs instead of VxVMing arrays, and then you had "the
DNS guy" and we didn't even touch the maps. It had to happen: more
and more was being asked of us, and new tools came so quickly, from
companies desperate to sell us things whether we needed them or not,
that keeping on top of it all quickly became impossible.

We still had the OS, but even that became commodotized and devalued.
Solaris and HP-UX on F15Ks and Superdomes became Linux running on
PCs.  People had far lower expectations of reliability and
maintenance for these, which other people duly met.  Skilled
sys-admins still, of course, had jobs, but they became grossly
outnumbered by "the HOWTO generation". These people built and ran
their machines from recipies. They got things to work, but
frequently didn't entirely understand *why* it worked, why it worked
poorly, or how (or even *that*) it could work better. Bad practice
proliferated around the world, made lore by cargo-cult
administration. Alta Vista replaced the `man` page, Google in turn
replaced that, and sys-admin became increasingly about pasting an
error into a browser, then pasting a command from a forum back into
the shell. Companies who sold operating systems saw them as a *fait
accompli*, and started selling layers of abstraction on top of them,
giving us GUIs we didn't want, and tools for everything. Real
understanding of the platform you managed seemed to become less
valued every day.

Change control, most necessary of evils, reached out across the
industry, then ITIL and friends sucked out whatever fun was left in
the job. On-call became more prevelant, with the Ops team expected
to fix whatever went wrong, even though it was almost never the
operating system. Which, as I've said, was pretty much all we still
had control of.

Being a sysadmin in the late 2000s got pretty dry. It wasn't the job
I'd got into, and it wasn't much fun.

It was around this time that I started hearing mutterings about
"DevOps". At first, it sounded unnecessary, then it sounded
exciting, now I can't say it without wincing.

This is why I hate DevOps.

## 1. I Don't Know What it Is

"DevOps", when I first heard about it, was about removing the
mythical wall between the people who write the code and the people
who run the system. Fine. I've always tried to work closely with the
devs: it makes sense for everyone. This made little difference to my
way of working, but it was nice to hope the approach would spread.

Then, it seemed to become about Ops people writing more code. Again,
fine. I've always written lots of code, just like any other
non-terrible sys-admin. Up to this point, I felt I had a new job
title (and a better day-rate), nothing more.

Next, "DevOps" seemed to mean Ops people starting to work like devs.
Some of this is good: writing better code; using languages which
are not shell; infrastructure as code; and version control are all
great. (If not necessarily new: I worked at sites in the 90s which
keps all host configuration files in CSV.) Things like scrums, story
points, Jenkins, and unit tests make a lot less sense in an ops
context, but it seemed we had to take the rough with the smooth.

After that, "DevOps" began to become closely tied to particular
tools and technologies. First it was the ubiquitous "Puppet/Chef"
('cos they're exactly the same, right?); later something as vague as
"Ruby", and at the time of writing it's the panacea of Docker and
the incoherent swarm of half-baked tooling around it.

## 2. Cargo Cult and Dogma

Now, the '90s HOWTOs have turned into blogs. Oh, so many blogs,
powered by oh, so many engines and opinionated-micro-frameworks.
Some, of course are useful and informative, but they're tiny oases
in a desert of clueless boastfulness, aint-it-cool copypasta and
semi-technical "what I did on my holidays". (This site, I am sure,
covers all those bases.)

In the world of the DevOps blogger, everything is "awesome".
Geniuses automate all of the things in minutes, with tools fresh
from Github, written in languages with a major version number of
zero. Everything works first time. There are no repercussions. Set
it, forget it, automate more of the things, freeing up more time to
get craft beer froth in your moustache at the [next
meetup](http://meetup.sysdef.xyz).

The DevOps blogger never talks about failure, and hard lessons
learnt. He (and it, depressingly, almost always is a he) never talks
about how, actually, that snippet of JSON took two weeks to work
out, or how it inexplicably fails one time out of ten.  No one talks
about how they have to restart their edifice of crap on a `cron` job
because it can't stay up for more than a day. Because everyone needs
to look like a rockstar, or ninja, or jedi, or whatever is this
week's bullshit title of choice.

Pied pipers call a tune, be it Chef, Docker, OpenStack, whatever,
and everyone dances. No matter if the tool of the day fits your
problem; give it a go anyway. By the time you realize you can't do
what you need to do with the half-finished junk you chose, the blogs
will be telling you to replace it with something else anyway.

In DevOps, one size fits all. Are you a selling a single product via
a small, mostly static website? Then you should *definitely* be
doing whatever Uber do.  Got six employees? If you aren't deploying
with the same tech as Google, you'll be eaten alive.  (The choice of
technology behind the deployment tooling is always made out to be
more important to the success of the comapany than the product being
sold, or how it is marketed. This is because all true IT ninjas draw
their strength from the knowledge that everyone else in the company
is an idiot whose job they could do in their sleep, were it not
beneath them.)

Mantras proliferate. You should never make any change to a server,
you should completely rebuild it. Production logs are meaningless.
Automate all the things.  Disable SSH everywhere. Fail often. Don't
waste time trying to fix things, spin up some more. Some good ideas,
some not, but all started off as grain of common sense, then
snowballed into written-in-stone commandments to be applied whether
it suits your use-case or not. If it looks like everyone is doing
it, do it. And once you've done it, don't forget to blog about it.
Or, better still, do a [meetup talk](http://meetup.rdfisher.co.uk)
about it.

## 3. Reinvented Wheels. But More Complicated.

Back in 1998, I left permanent employment and got my first
contract. My task was to create a system, with a GUI, for
self-service deployment of infrastructure. A user clicked a button,
and got a whole bunch of machines, fully configured as databases,
cluster nodes, web servers, application servers, whatever. It took
me three months to do this, on my own. I used Solaris and Jumpstart
and, because I understood those technologies, it was simple to make
them perform in the way I required. I wrote a thin layer of PHP (I
never claimed to be perfect) for the GUI, and a bit of C to do some
crypto stuff, and we had a clean, simple system anyone could
maintain, extend, or fix. It was tiny, and it worked, in
production, for years.

Now, in 2015, I see teams of CS-qualified Full-Stack Jedis layering
gem upon gem, or npm inside npm, building huge sprawling systems
which fail to accomplish the simple task of deploying and
configuring some vanilla VMs.  Someone said long ago that "those who
fail to understand Unix are condemned to reinvent it, poorly" (see
Linux) and I seem now to spend the majority of my working life
dealing with, or trying to fix, these poor reinventions.

I am constantly amazed at the complexity of some people's solutions
to simple problems. We fight to call ourselves 'engineers', but I
see precious little engineering. Rather, I see shit thrown at walls,
and when it doesn't stick, more thrown until something does. I don't
care how many stars you have on your Github, or how many languages
you can do FizzBuzz in: if you don't fundamentally understand how
the OS works, you shouldn't be writing system software.

## 4. Linux

For all of the industry's readiness to discard or adopt languages in
a heartbeat, to import a Puppet module without looking at the code,
or to `curl | sudo bash` anything from anyone with a bootstrapped
dot-io website, there are a few immutable, fixed points in
technology, where, whatever their failings, no one ever considers
there might be an alternative.  Principal among these, most sacred
of cows, is Linux. Or GNU/Linux, if you're one of those miserable
license-pedants, who love to point out that "Linux is just the
kernel".

Over the last twenty-or-so years I've worked with pretty much all of
the major Unix variants, and I am utterly baffled as to how the
worst one won. Baffled as to how it base become so entrenched and
revered. Baffled as to why no one ever looks beyond it.

We all read *The Cathedral and the Bazaar*. We all bought into the
thesis that openness and collaboration would produce quality and
innovation which insular, marketing-lead corporations never could.
Open source has given us many gifts, but the "all chipping in"
approach precludes the kind of deep, planned, system engineering
that is required to progress something as big and complex as an
operating system.  How else to explain why, as it nears its
quarter-century, the best filesystem on the open source's mighty
flagship is still one developed 22 years ago by a commercial Unix
vendor?

The DevOps tool space, whatever the hell that is, is full of
half-baked crap sitting mostly *on top* of Linux, trying to trick
the user into thinking it's doing things it's not. We're building
the world on hacks like `cgroups` and network namespaces instead of
properly re-engineering the system to meet our new requirements. Or,
better still, moving to an OS which has already solved these
problems, by means of focussed re-engineering that only a
forward-thinking, single minded enterprise could undertake.

Sun produced just one solution to each of the problems of
virtualization (not considering logical and physical domaining);
tracing; and file storage.  They finished, polished, debugged and
documented each one, and zones, DTrace and ZFS now have well over a
decade of proven production use.  Linux, on the other hand, has LXC,
lxd, KVM, XEN, OpenVZ, SystemTap, Sysdig, `perf`, ktap, `ftrace`,
eBPF, a couple of DTraces, and more filesystems than you could shake
a stick at, all "not quite there yet", and, in most cases, never
likely to be.

If we'd taken our lead from OpenSolaris, or even from FreeBSD, we'd
be ten years further on now. Everyone who can work out how to open
Sublime is piling up the PRs, contributing to the baffling,
overwhelming array of tooling around containers, or naively
rebuilding the world with those same, ever-shifting, tools. And no
one seems to care that Linux containers aren't anywhere near
finished. Username collisions! The gross hacks that make networking
"work".  Packaging all of Ubuntu to support your 120 lines of Node.

At least using containers gets us away from using VMs, with their
memory requirements, and their floppy disk emulation. Except they
don't. We run containers on VMs!

I've been told that the nett result of some conference somewhere was
that there are two things on which the industry universally agrees.
Linux, on VMs. There's no wonder we're in a mess.

## 5. AWS

Let's stretch Chef's tired kitchen analogy even further. It's not a
huge push to liken an old-skool ops guy to a chef. You have the
basic ingredients of the OS, applications, networks; your implements
are your programming languages; experience cultivates your "palate"
-- a sense of whether something is right or wrong, and if it's the
latter, what it will take to get it to the former. Like a chef, you
are constantly given new ingredients, and exposed to new techniques,
and your customers have changing tastes, and different (dietary)
requirements.

So, take one happy chef, cooking from scratch, creating "just right"
dishes, and stick her in the AWS kitchen. She's now got a never
ending stream of ready-meals coming in, and a wall full of
microwaves. That's it. She might initially like the convenience, and
she probably won't miss sharpening knifes or cleaning the grease
traps, but hell, it soon gets boring. Oh, and the microwaves can
only be operated with huge swathes of JSON.

Someone once said, prophetically, "the network is the computer". It
turned out that, actually, *Amazon's* network would be our computer,
and it's the biggest, most boring computer I've ever had to operate.
Sure, Cloudformation and IAM are extremely powerful and empowering,
but as Voltaire knew, with great power comes great amounts of
seemingly-arbitrary JSON.

In a sense, we're back to piping data between programs, but now the
pipe goes over some unknown software-defined network, and to make
the things at each end talk safely to one another, you must have
digested the subtle concepts buried in 400 pages of IAM documentation,
and done some language-of-your-choice voodoo with a
machine-generated API the size of Wales. Or the CLI. Jesus, the CLI.

And all of this stuff will change. You'll get new versions and new
features out of the blue. You'll get a service that does, with one
click in the console (and a shitload of $$$, but don't worry about
that -- no one does) exactly what the thing it took you a month to
build does, right out of nowhere. And everything you learn is
completely, utterly, non-transferrable. Your entire career becomes
wrestling with freshly smoked-up APIs and DSLs based on hastily made
decisions and provision of an MVP. You'll drown under announcements
and NDA roadmaps and paranoia that the way you're doing everything
isn't the best way, or that if it is, it won't be for long.  It's
crushing-lack-of-job-satisfaction as a service, and, like all AWS's
services, it works.

I've never been an idealistic computer user. I never really hated
Microsoft all that much in the '90s. But I remember why other people
did. They made software which "embraced and extended" standards to
covertly encourage vendor lock-in. They took from the community
without giving anything back. They were very expensive, and once
they got their claws into you, they'd bombard you with agents and
emissaries who would try to get you to convert more of your products
to depend on theirs. The main difference between '90s Microsoft and
'10s Amazon, so far as I can tell, is that Microsoft wanted to put
all other IT companies out of business, whatever it took, whereas
Amazon want to put *all* other companies out of business, regardless
of market sector. If you're going to hate a company in 2015, Amazon
seems like a pretty good one to choose.


## 6. It isn't Tooling, it's Culture

There is a stereotypical idea of the "ops guy", BOFH, or whatever
you wish to call him, and, like all stereotypes, he exists. Ours is
an industry which seems to attract the loud, blaring know-it-all
know-nothing. He used to be confined to the basement, sneering at
people who get "wallpaper" mixed up with "screen saver", but now
he's out there, younger, skinnier, more fashionably bearded, in his
dot-io vendor tee, doing meetups, blogging, reshaping his world. If
he's a real, grade-A ten-ex-mega-bullshitter, he's probably started
his own body-shop, subbing out contractors with six-months'
experience at £950/day to the client.

At the start of this essay, I grumbled about change control, ITIL,
specialists, and procedures. DevOps throws those away, supposedly
because they "slow velocity" or some-such bullshit but, *really*, I
suspect, because they are **boring**.

We're in fashion now. Everyone wants us, even though no one,
including ourselves, actually understands what we are, or what we
do, or why we're suddenly so important. No one dares question us in
case they look stupid or, worse, old. We're in charge, and we don't
want to do those things. Because they are **BORING**. But we aren't
simply going to not do them, we're going to make up some kind of
"manifesto" full of flimsy excuses as to *why we would be fools* to
do them, and, perhaps more importantly, why *you would be a fool to
ask us*.  And we expect you to praise us for it.  Much of DevOps,
and by extension, the Agile culture from which it grew, seems to me
to be about validating weakness and avoiding responsibility.

One of the favourite mantras right now is "fail fast" or "fail
often" or both.  Why do DevOps fail so fast and so often? Becuase,
by and large, they don't know, or particuarly care, what they're
doing. They're more interested in shoehorning in the new tool, or
speaking at the next meetup, or having the CV to get the higher
rate, or finding an excuse to try the new language, than in
understanding the problem and solving it elegantly. Because
understanding the problem is **HARD** and using existing, perhaps
even *finished*, tools is **BORING**. DevOps, largely, is children
playing with toys.

Of course,there *are* new problems, which do require new approaches
and new tools. But the chances are yours is not one of them. You are
probably not Google.

We have things like the Spotify Engineering blog telling us how
special we all are, while we sit around "storytelling" on bean bags
in our "experiment friendly culture", patting ourselves on the back
at how often we can balls up something simple, how we *killed*
getting that `.deb` onto that vanilla Ubuntu install, or how quickly
we got that brittle, barely working pile of shit into production, or
that we got Docker Swarm working at all.

I hear mutterings that there's no such thing as root cause, and if
you look for one, you're a fool. So there's another hard thing
struck off the list, freeing up more time to go to conferences. MVP
is where it's at now, and the increasingly accepted definition of
"viable"  appears to be 'ˈvʌɪəb(ə)l/ *adj*: has, at some point, run
on my MacBook'.

Anyone who genuinely believes "we'll do a quick hack now then fix it
later" clearly hasn't spent much time in the real world. I've got a
great big wedge of cardboard under the corner of my desk which I did
in a moment, fully intending to fix it later. It's been there two
years and counting. I see it every day. I can see it now. It would
take me five minutes to get a spirit level and a spanner and adjust
all the feet to make it perfect, but I haven't got round to doing
it. If I can't do that, do you really, truthfully, believe the
engineers now jerry-rigging their next get-it-out-the-door,
needs-must shitfest will drop everything and revisit that great
steaming dogs-egg they laid in production last week, bit-by-bit
turning it into a Swiss watch with zero downtime? You do? Really?
Gosh.  Enjoy your devops.

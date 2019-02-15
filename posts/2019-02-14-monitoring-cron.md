---
title: "Monitoring cron with DTrace"
date: "2019-02-14"
tags: [Solaris, DTrace, Wavefront]
layout: post
category: DTrace
---

`cron` is a pain. It's not that it doesn't work -- it's worked great
for thirty-odd years.
The problem is *knowing* that it's worked. Or not worked. Once upon
a time I wrote a truly horrible thing called the Cron Reporting and
Auditing Portal (named for its acronym) which tried to put together
a view of cron jobs across a decent sized estate. That was a pain to
make. `cron`'s logs are difficult read, and more difficult to parse.
It's designed to do nothing on success, and to send an email on
failure.

Alas, no one these days will pay me to work on Solaris or SmartOS,
but I still run both at home. They do all kinds of things, using
many cron jobs in many zones. For ages, I've meant to put something
in place to monitor them.

The "correct" way to do this, I suppose, would be to monitor the
*outcome*, by having the jobs themselves emit telemetry. For some
things, I already do this. I don't want to know my backup job *ran*,
I want to know that it *worked*. But most of my cron
jobs are small scripts and one liners, and the tasks they perform
often don't lend themselves to proper telemetry.

In the dozen or so years I've been building zoned systems, I've
learnt that the way to monitor zones is from the global. The global
can see everything, and no one inside a zone can interfere with
what's happening there. Bearing in mind that a modern system can
easily run many hundreds of zones, you're better off, I think, with
one smart job running globally than a dumb job in every zone.
There's much less overhead, and much less to go wrong.

Sometimes your monitoring has to go into the zones, but running
`zlogin`, or peeking in `/zones` should be a last resort. Better to
observe the global view, and there's nothing better at doing that
than DTrace. So, I decided to write a DTrace script which looked for
`cron` jobs, reporting whatever it sees to Wavefront.

I thought the best place to start would be a simple notification
that `cron` had started a job.

To shorten my iterative cycle I set up three test cron jobs,
covering three cases of execution. One works (exits `0`); one fails
(exits `1`); one doesn't run because the command does not exist.
I set all of them to fire every minute, ("5-star cron job. Will run
again.") Doing this reminded me of one of the worst design decisions
in Unix: `crontab -r`. Maybe whoever decided that one used a
keyboard where the `r`, *wasn't* right next to the `e`.

[The
source](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cron/cron.c#L2557)
told me tasks are launched via `execl()`, so I wrote

```dtrace
syscall::exece:entry
/execname == "cron"/
{
  printf("RUN pid=%d cmd='%s' zone=%s user=%d\n",
          pid, copyinstr(arg0), zonename, uid);
}
```

and saw

```
RUN pid=473 cmd='/bin/false' zone=cube-media user=264
RUN pid=468 cmd='/usr/bin/true' zone=cube-ws user=264
RUN pid=469 cmd='/bin/does-not-exist' zone=cube-ws user=264
```

Right. Fine.

This data is going to end up in Wavefront, so we need something to
plot against wallclock time. Execution time seemed a sensible
metric, so I recorded the start time of each job in a thread-local
variable. Next I needed a block to fire at the end of the job. This
needs to calculate the elapsed time and write information about the
job.


```dtrace
syscall::exece:entry
/execname == "cron"/
{
  printf("RUN pid=%d cmd='%s' zone=%s user=%d\n",
          pid, copyinstr(arg0), zonename, uid);
  self->t_start = timestamp;
}

proc:::exit
/self->t_start/
{
  printf("END pid=%d prog=%s zone=%s user=%d duration=%d\n",
          pid, execname, zonename, uid, timestamp - self->t_start);

}
```

Now I see:

```
RUN pid=4021 cmd='/usr/bin/true' zone=cube-ws user=264
END pid=4021 prog=true zone=cube-ws user=264 duration=1688168
RUN pid=4020 cmd='/bin/false' zone=cube-media user=264
END pid=4020 prog=false zone=cube-media user=264 duration=1585124
RUN pid=4022 cmd='/bin/does-not-exist' zone=cube-ws user=264
END pid=4022 prog=cron zone=cube-ws user=264 duration=28568
```

Good, good. But the point of the exercise is to know whether or not
a job has succeeded. I assumed this would be as easy as showing the
`arg0` of `exit`, and changed my `proc` block to

```dtrace
printf("END exit=%d pid=%d prog=%s zone=%s user=%d duration=%d\n",
       arg0, pid, execname, zonename, uid, timestamp - self->t_start);
```

which gave me

```
RUN pid=4538 cmd='/bin/does-not-exist' zone=cube-ws user=264
END exit=1 pid=4538 prog=cron zone=cube-ws user=264 duration=30673
RUN pid=4536 cmd='/bin/false' zone=cube-media user=264
END exit=1 pid=4536 prog=false zone=cube-media user=264 duration=1554937
RUN pid=4537 cmd='/usr/bin/true' zone=cube-ws user=264
END exit=1 pid=4537 prog=true zone=cube-ws user=264 duration=1702499
```

Everything exits `1`? Even `true`? Of course not. [The DTrace
guide](http://dtrace.org/guide/chp-proc.html#tbl-proc) clearly
states `exit` is a

> Probe that fires when the current process is exiting. The reason for
> exit, which is expressed as one of the SIGCHLD siginfo.h(3HEAD) codes,
> is contained in args[0]

So that's no good. I had no joy with `proc::exec-failure` either,
which I now assume means that the `exec()` itself failed, not the
thing that was `exec()`ed.

I started hunting through `dtrace -l`, and landed on
`fbt::proc_exit:entry`.  I'm a bit scared of the `fbt` probe. I
remember back in the day it was a bit "here be dragons", and I never
properly learnt it. But I thought it might be what I need here.
(Speaking of "back in the day", I'm not sure I've ever felt quite so
old as when I saw the right hand column [of this
page](https://github.com/illumos/illumos-gate/tree/4e0c5eff9af325c80994e9527b7cb8b3a1ffd1d4/usr/src/cmd/dtrace).)

I couldn't find much on `proc_exit()` in [the Illumos
code](https://github.com/illumos/illumos-gate/search?p=2&q=proc_exit&unscoped_q=proc_exit),
but I did learn

```c
extern int proc_exit(int, int);
```

So I asked DTrace to look at both args for me. The first was always
`1`. Whether that's the same thing I was seeing from the `proc`
provider, I don't know, but looking at `arg1` was more illuminating.
I changed my `proc:::exit` block to

```dtrace
fbt::proc_exit:entry
/self->t_start/
{
printf("END exit=%d pid=%d prog=%s zone=%s user=%d duration=%d\n",
       arg1, pid, self->job_name, zonename, uid, timestamp - self->t_start);
}
```

and got

```
RUN pid=16435 cmd='/bin/false' zone=cube-media user=264
END exit=255 pid=16435 prog=/bin/false zone=cube-media user=264 duration=1565076
RUN pid=16436 cmd='/usr/bin/true' zone=cube-ws user=264
END exit=0 pid=16436 prog=/usr/bin/true zone=cube-ws user=264 duration=1569024
RUN pid=16437 cmd='/bin/does-not-exist' zone=cube-ws user=264
END exit=127 pid=16437 prog=/bin/does-not-exist zone=cube-ws user=264 duration=32172
```

`127` for the thing that can't be run at all; `255` for the thing
which ran with an error, and a big fat `0` for the thing that
worked. I reckon that's all I need to know. Just to be certain I
checked with `/var/cron/log` in the various zones, and found
matching exit codes for all my jobs.

On the home straight now, I just needed to change the output to
something Wavefront understands. Normally I'd [pipe this into the
Wavefront CLI](https://sysdef.xyz/post/2018-04-08-wavefront-writer),
but that's written in Ruby, and my SmartOS global zones don't have
Ruby. But they do have `nc(1)`, so I just had to construct a
[Wavefront wire
format](https://docs.wavefront.com/wavefront_data_format.html)
string.

That is:

```
<metricName> <metricValue> [<timestamp>] source=<source> [pointTags]
```

I dropped the `printf()` call from my `syscall::exece:` block, and
put this one in my `fbt:`.

```dtrace
printf("cron.job %d %d source=cube cmd=\"%s\" zone=\"%s\" uid=%d exit_code=%d\n",
       walltimestamp - self->t_start,
       self->t_start / 1000000000,
       self->job_name,
       zonename,
       uid,
       arg1);
```

Because we need a real timestamp now, I changed the declaration of
`self->t_start` from `timestamp` to `walltimestamp`. Running the
script, and piping it into `nc wavefront 2878` I had data. Here are
the times of cron jobs running in my global zone.

<script src="https://metrics.wavefront.com/embedded/lCpxntHK8B/js"
id="wavefront-embedded-lCpxntHK8B" width="700"
height="300"></script>

If you hover over the points, you'll see that the top one is
`zfs_snapshot`.  But the other two just say `/usr/bin/sh`

When you have something simple as your cron task, like
`/bin/zfs_snapshot`, that gets executed. But anything "shell
scripty" gets run through `/usr/bin/sh`. (Which on Solaris is ksh93,
not that `bash` rubbish.) Looking at the times those jobs fired, and
the zones they ran on, I see they are things like this. (Line breaks
for formatting.)

```
0,10,20,30,40,50 * * * * cd /home/rob/work/record-collector/tools && \
                         bundle exec value_to_wavefront \
                         >/var/log/cron_jobs/value_to_wavefront.log 2>&1
```

Everything the kernel knows about a process is available in DTrace
via the `curpsinfo` structure. That has to be examined in the
`fbt::` block, because the active process in the `exece:` block is
`cron` itself.

`curpsinfo->pr_fname` didn't offer me anything of value. In the case
of a short job, it's the `basename()` of what I already have in
`self->job_name`; in the case of the longer "shell scripty" things,
it's `sh`. So forget that.  `curpsinfo->pr_psargs` is a little more
variable.  For short things, it's the program basename again; for
"shell scripty" things, it's the whole command. For jobs which
completely fail to run, it's `/usr/sbin/cron`.

I decided my `cmd` tag only needed to hold enough information to
identify a cron job. It doesn't have to be perfect.  Clearly I had
to apply some basic logic to the two strings in `self->job_name` and
`curpsinfo->pr_psargs` to make something sensible and consistent.
The problem is, logic isn't DTrace's forte. In short, it has no
`if`. (It also has no loops.) This, you may immediately think, is
stupid. What kind of programming language doesn't do conditional
branching? Well, D isn't *really* a programming language; at least
not a Turing-complete, general-purpose one.  It's very
domain-specific, and its top priority is not affecting the system on
which it runs. If it gave you the ability to write branching
code it would not be able to comprehensively check what you wanted
to do and could guarantee the safety of the script and therefore the
system.  So it doesn't.

But, DTrace *does* have a ternary operator, and using that I found a
way to use a couple of clause-local variables (very fast, memory
automatically freed) to pick out
sufficiently specific information. I also made the source name
dynamic by wrapping the whole thing in shell and passing it in as a
macro (argument) variable. The final script is:

```dtrace
#!/bin/ksh

dtrace -qn '
syscall::exece:entry
/execname == "cron"/
{
  self->t_start = walltimestamp;
  self->job_name = copyinstr(arg0);
}

fbt::proc_exit:entry
/self->t_start/
{
  this->ocmd = self->job_name;
  this->cmd = (this->ocmd == "/usr/bin/sh") ? (string)curpsinfo->pr_psargs : this->ocmd;

  printf("cron.job %d %d source=%s cmd=\"%s\" zone=\"%s\" uid=%d exit_code=%d\n",
         walltimestamp - self->t_start,
         self->t_start / 1000000000,
         $$1,
         this->cmd,
         zonename,
         uid,
         arg1);
  self->t_start = 0;
}' $(uname -n)
```

Which gives me this.

<script src="https://metrics.wavefront.com/embedded/qlg31jQcpT/js"
id="wavefront-embedded-qlg31jQcpT" width="700"
height="300"></script>

I wrapped everything up in an SMF manifest, running as a normal user
but granting DTrace privileges.

```xml
<method_context>
  <method_credential
    group='daemon'
    privileges='basic,dtrace_kernel,dtrace_proc,dtrace_user,!file_link_any'
    user='cronmon'/>
</method_context>
```

Finally, I Wrote a quick Puppet module for deployment, pushed it
out, and it's been running happily ever since, on Solaris and
SmartOS.

I fixed all the broken cron jobs, improved a couple that seemed very
slow, and now Wavefront tells me if anything fails or takes
inordinately long. It's good.

Imperfections? Most obviously, the user is only displayed by UID. It
would be nicer if it could be done by username, but I'm not aware of
any way I could get that out of DTrace, at least not trivially. The
command names aren't perfect, but they're good enough.

The connection between `nc` and Wavefront is brittle, so  it would
be better to have `nc` write to a local Telegraf socket, and have
Telegraf pass everything on to Wavefront. Telegraf is smart enough
to buffer points if the endpoint temporarily disappears. I've got a
global zone Telegraf input about half written, and once that's done,
this will talk to it.

Back when I got paid to work on Solaris, I did all kinds of cute
sysadmin type things like this with DTrace. I'm not a Real
Programmer, so I don't often trace my own code, but I've always
loved the in-depth introspection dynamic tracing gives to the ops
engineer, particularly combined with the zones model.

I spend my days now in the world of IAM and containers and Lambdas,
and everything-as-a-service. `cron` seems a quaint relic as, I
suppose, does Solaris. But I do feel there is still a place for "the
old way" of doing things.  Simple tools, well understood, their
edges worn smooth from years of careful use.

I'd love to get paid to work on this kind of "real Unix" stuff
again, instead of the the glorified plumbing of AWS. But at least I
have a fun hobby.

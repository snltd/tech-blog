---
title: "cron - invalid account"
tags: [Solaris]
date: 2010-10-28
layout: post
category: Solaris
---

I was setting up a cron job running under a newly created account, and
when I edited the crontab with

```cmd
# crontab -e pch
```

I was told

```
Warning - Invalid account: 'pch' not allowed to execute cronjobs
```

The first thing I did was create `/etc/cron.d/cron.allow` and put the
username in there. Didn't work. (I should have known that `cron.allow`
only applies if it exists - that is to say that if it doesn't exist, any
user not in `/etc/cron.d/cron.deny` can run jobs.)

It took me a while to work out what was wrong, which is why I've written
it down here. The user's password entry in `/etc/shadow` was `*LK*`,
which means the account is locked. Locked accounts can't run cron jobs.
So I changed that to `NP`, which means &quot;no valid password&quot; and
all was well.

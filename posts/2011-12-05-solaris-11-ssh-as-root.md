---
title: "SSH as root on Solaris 11"
tags: [Solaris, Solaris 11, ssh]
date: 2011-12-05
category: Solaris
---

I needed to quickly enable SSH as root to `rsync` a load of data. Yes, I
know there are far better ways to do it, and I know that enabling SSH
for root is a bad idea, and lazy, and normally I'd agree, but I needed
to do it. Anyway, it's on a private lab network.

So, I opened `/etc/ssh/sshd_config` and changed `PermitRootLogin` to
`yes`.  I refreshed the SSH service, and tried to run a remote command
as root, and it wouldn't let me.

The `sshd_config` man page told me I had to comment the `CONSOLE` line
out of `/etc/default/login`, just like you had to do for `telnet` in
the old days. So I did that, and still no dice.

I cranked up the `sshd` logging, and saw that:

```
Dec  6 17:24:40 hp-bk-01 sshd[1260]: [ID 800047 local0.debug] debug1: PAM
conv function returns PAM_SUCCESS
Dec  6 17:24:40 hp-bk-01 sshd[1260]: [ID 800047 local0.info]
Keyboard-interactive (PAM) userauth failed[7] while authorizing:
Permission denied
Dec  6 17:24:40 hp-bk-01 sshd[1260]: [ID 800047 local0.info] Failed
keyboard-interactive for root from 192.168.1.21 port 43885 ssh2
Dec  6 17:24:40 hp-bk-01 sshd[1260]: [ID 800047 local0.debug] debug1:
userauth-request for user root service ssh-connection method
keyboard-interactive
Dec  6 17:24:40 hp-bk-01 sshd[1260]: [ID 800047 local0.debug] debug1:
attempt 2 initial attempt 1 failures 1 initial failures 1
```

Ah, PAM. Right. This is where it starts to get murky for me. Remember
that for some time now Sun have been trying to turn us all off root,
making it a role and all that crap. You need to tell PAM that root is
still a user by sticking the following in `/etc/pam.conf`.

 sshd-kbdint   account   required   pam_unix_account.so.1

UPDATE: I had a devil of a job with one box only accepting interactive
logins. It looks like things have changed in Solaris 11.1, so to use
`authorized_keys` and whatnot, you'll also have to have

```
sshd-pubkey   account   required   pam_unix_account.so.1
```

in `/etc/pam.conf` too.

Then, in combination with the other stuff, you can run SSH commands as root.
So now you know how to do it, don't do it.

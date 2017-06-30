---
title: "Caddy on SmartOS"
tags: [SmartOS, Caddy, Go]
date: "2017-02-11"
layout: post
category: SmartOS
---

It's depressing. Way back in the day, anything any good came
prebuilt for Solaris. Now, I'm astonished if any open source project
claims to run on it. The SmartOS situation is even worse.

Look at [Caddy](https://caddyserver.com). A small, snazzy HTTP2
server with lots of good modern features and integrated [Let's
Encrypt](https://letsencrypt.org/) support.
The [download page](https://caddyserver.com/download) gives you,
among the obvious, FreeBSD on ARM, and 32-bit OpenBSD. That's where
we are now, SunOS people. We're below 32-bit OpenBSD.

BUT! Caddy is written in Go, and Go works on Solaris and SmartOS. It
probably won't work though... will it?

First, you need Go 1.7. At the time of writing, SmartOS is
shipping 1.6.3, but the newer version builds cleanly if you follow
[the simple instructions](https://golang.org/doc/install/source).

I'll wait while you do that, and make sure the new Go is in your
`PATH`. Then, build, my pretties.

```cmd
$ go version
go version go1.7.5 solaris/amd64
$ go get github.com/mholt/caddy/caddy
$ which caddy
/home/rob/work/go/bin/caddy
```


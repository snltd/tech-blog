---
title: "rbenv on Solaris 11"
date: "2019-02-01"
tags: [Ruby, Solaris]
layout: post
category: Solaris
---

I love a bit of Ruby. I also love
[rbenv](https://github.com/rbenv/rbenv), and Solaris.

Getting things running on Solaris seems to get more difficult every
week. Today I had problems getting Ruby 2.6.0 to install on a clean
Solaris 11.4 build.

A little bit of log-reading showed two problems. First, `rbenv` (or,
more likely, the build plugin), appears to assume a GNU tool chain.
This is not new. 90% of the world thinks only Linux exists, 99%
thinks there's only Linux and Mac.

Once you've fixed that, you'll find that Solaris has (not
unreasonably) deprecated a whole bunch of OpenSSL stuff. This breaks
the build.

Assuming you have a machine with a decent build environment (GCC and
friends) your workaround is:

```cmd
$ PATH=/usr/gnu/bin:$PATH RUBY_CFLAGS="-DOPENSSL_NO_MD5" rbenv install 2.6.0
```

If you need the `mysql2` gem, like I did, you'll have to point it to
the right place.

```cmd
$ gem install mysql2 -- --with-mysql-config=/usr/mysql/5.7/bin/mysql_config
```

I haven't had installation difficulties with any other native
extension gems so far, even `ffi`.

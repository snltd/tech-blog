---
title: "rbenv on Solaris 11"
date: "2019-02-01"
tags: [Ruby, Solaris]
layout: post
category: Solaris
---

If you use Ruby you ought, in my opinion, to be using
[rbenv](https://github.com/rbenv/rbenv). And if you use computers
you ought, in my opinion, to be using something SunOS based.

Out of the box I couldn't get Ruby 2.6.0 (or anything else for that
matter) to install on a clean Solaris 11.4 build. It's simple enough
though.

The problems are: `rbenv`, like the rest of the world, pretty much
assumes a GNU tool chain; and Solaris has (rightly) deprecated a
whole bunch of OpenSSL stuff. So, assuming you have a machine with a
decent build environment (GCC and friends) your workaround is:

```cmd
$ PATH=/usr/gnu/bin:$PATH RUBY_CFLAGS="-DOPENSSL_NO_MD5" rbenv install 2.6.0
```

If you need the `mysql2` gem, like I did, you'll have to point it to
the right place.

```cmd
$ gem install mysql2 -- --with-mysql-config=/usr/mysql/5.7/bin/mysql_config
```

I haven't problems with any native extension gems so far, even
`ffi`.

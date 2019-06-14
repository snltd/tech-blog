---
title: "Building Ruby 2.3 for Solaris 11.3"
tags: [Solaris, Ruby]
date: 2016-01-26
category: Solaris
layout: post
---

A while ago [I did a little write-up on building a nice, dependency
free, modern Ruby](/post/2015-10-04-ruby-on-smartos) on SmartOS. I
even ended up writing [a
script](https://github.com/snltd/smartos-gubbins/blob/master/misc_scripts/build_ruby.sh)
to do it automatically.

I use Puppet to manage my Solaris zones, and I thought it was high
time to get upgraded to Ruby 2.x and Puppet 4, which is what I use
on SmartOS. So, I tried to build Ruby 2.2.3 in exactly the same was
as I build it on SmartOS. Well, almost the same way. I am so old
fashioned that I still try to build stuff with Sun CC. I've lost
some of the appetite to fight things, but old habits die hard.

```cmd
$ CC=cc CFLAGS=-fast ./configure --prefix=/opt/ruby --disable-install-doc --enable-dtrace
...
$ gmake -j4
...
gmake[2]: Entering directory `/tmp/ruby-2.3.0/ext/openssl'
compiling ossl_ssl.c
ossl_ssl.c:107:27: error: 'SSLv2_method' undeclared here (not in a function)
     OSSL_SSL_METHOD_ENTRY(SSLv2),
                           ^
ossl_ssl.c:89:69: note: in definition of macro 'OSSL_SSL_METHOD_ENTRY'
 #define OSSL_SSL_METHOD_ENTRY(name) { #name, (SSL_METHOD *(*)(void))name##_method }
                                                                     ^
ossl_ssl.c:108:27: error: 'SSLv2_server_method' undeclared here (not in a function)
     OSSL_SSL_METHOD_ENTRY(SSLv2_server),
                           ^
ossl_ssl.c:89:69: note: in definition of macro 'OSSL_SSL_METHOD_ENTRY'
 #define OSSL_SSL_METHOD_ENTRY(name) { #name, (SSL_METHOD *(*)(void))name##_method }
                                                                     ^
ossl_ssl.c:109:27: error: 'SSLv2_client_method' undeclared here (not in a function)
     OSSL_SSL_METHOD_ENTRY(SSLv2_client),
                           ^
ossl_ssl.c:89:69: note: in definition of macro 'OSSL_SSL_METHOD_ENTRY'
 #define OSSL_SSL_METHOD_ENTRY(name) { #name, (SSL_METHOD *(*)(void))name##_method }
```

Well. That kinda sucks. SSLv2? That's gone the way of Solaris`^W`
the dinosaurs hasn't it?

```cmd
$ ggrep -r SSLv2_method /usr/include
/usr/include/openssl/ssl.h:DEPRECATED const SSL_METHOD *SSLv2_method(void); /* SSLv2 */
```

interesting. Let's see what SmartOS thinks:

```cmd
$ ggrep -r SSLv2_method /opt/local/include
/opt/local/include/openssl/ssl.h:const SSL_METHOD *SSLv2_method(void); /* SSLv2 */
```

So, it looks like SmartOS is happy to give me crappy SSLv2
functionality that I shouldn't be trusted with, but Solaris 11.3 is
not. Wow. Mark one up for Oracle.

But, I'm still in a fix. I can't build Ruby, even with potentially
iffy SSL support. Looking at the code, the `#ifdef` wrapping the
offending line suggests an easy, legitimate, fix.

```c
#if defined(HAVE_SSLV2_METHOD) && defined(HAVE_SSLV2_SERVER_METHOD) && \
        defined(HAVE_SSLV2_CLIENT_METHOD)
    OSSL_SSL_METHOD_ENTRY(SSLv2),
    OSSL_SSL_METHOD_ENTRY(SSLv2_server),
    OSSL_SSL_METHOD_ENTRY(SSLv2_client),
#endif
```

It looks to me as if, rather than simply `DEPRECATE`-ing the `SSLv2`
methods, we should pretend we don't have them at all. There's stuff
further down for `SSLv3`, which we do have. So, let's drop

```c
#undef HAVE_SSLV2_METHOD
```

in at the top of the file and give it another go.

```cmd
$ gsed -i '13i#undef HAVE_SSLV2_METHOD' ext/openssl/ossl_ssl.c
$ gmake -j4
...
linking ruby
gmake[2]: Leaving directory `/tmp/ruby-2.3.0'
gmake[1]: Leaving directory `/tmp/ruby-2.3.0'
$ gmake test
...
PASS all 1010 tests
...
```

All looks good. Let's try it out.

```cmd
# gmake install
$ /opt/ruby/bin/irb
irb(main):001:0> require 'openssl'
=> true
```
Looks good so far.  I know `gem` uses SSL stuff. So:

```cmd
# /opt/ruby/bin/gem install puppet ruby-shadow
```

Note that I didn't bother with `--no-rdoc` etc. (And I don't want
any docs: this is purely for an Omnibus style Puppet package.)
because:

```cmd
$ cat ~/.gemrc
install: --no-rdoc --no-ri
update:  --no-rdoc --no-ri
```

I distribute this to all my zones by `lofs` mounting `/opt/ruby`
read-only everywhere. Then, when I want to push a new version, I can
do it from the global in one shot.

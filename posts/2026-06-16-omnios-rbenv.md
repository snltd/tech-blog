---
title: "rbenv on OmniOS"
date: 2026-06-16
tags: [Ruby, OmniOS]
category: OmniOS
---

OmniOS has Ruby packages, but I like to use
[rbenv](https://github.com/rbenv/rbenv) with the
[ruby-build](https://github.com/rbenv/ruby-build) plugin.

Ruby will build without patches, but you have to nudge it towards `libyaml`, and
give it a `tar` capable of unpacking some long filenames.

```cmd
$ CONFIGURE_OPTS="--disable-install-doc" \
  LDFLAGS="-L/opt/ooce/lib/amd64 -R/opt/ooce/lib/amd64" \
  CFLAGS="-I/opt/ooce/include" \
  PATH=/usr/gnu/bin:$PATH \
  rbenv install 4.0.5
```

Assuming you've got Rust installed, you'll get the new YJIT, and some lovely
DTrace probes.

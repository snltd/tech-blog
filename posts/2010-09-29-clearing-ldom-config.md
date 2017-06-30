---
title: "clearing LDOM config"
tags: [Solaris, LDOMs]
date: "2010-09-29"
layout: post
category: Solaris
---

I needed to reuse a box which had a couple of LDOMs, and I forgot to clear
them out before I did the fresh Jumpstart. Of course, when the newly
installed machine came up, it had hardly any share of the host's resources.
It turns out that the quickest and best way to clear out all LDOM
configuration is to go into the machine's SC, power it off, then do

```cmd
> bootmode config="factory-default"
```

Power on, and after a full POST, the machine will come back in a pristine
state, with all resources back in the primary domain.

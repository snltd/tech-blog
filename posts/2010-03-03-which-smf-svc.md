---
title: PIDs and SMF services
tags: [Solaris, SMF]
date: 2010-03-02
---

I logged into an SXCE box, and saw a Java process running. As with all Java
processes, it wasn't immediately obvious what it was doing, so I thought I'd
ask the SMF what it was.

```cmd
$ pgrep java
4888
$ ps -o ctid -p 4888
 CTID
   88
$ svcs -v | grep -w 88
online         -             Feb_18       88 svc:/system/webconsole:console
```

There we go. There's probably a better way to do it, but I haven't found it
yet. Contrariwise, if you want to see which processes an SMF service is
controlling, you want something along the lines of

```
$ svcs -p svc:/system/webconsole:console
STATE          STIME    FMRI
online         Feb_18   svc:/system/webconsole:console
               Feb_18       4888 java
```

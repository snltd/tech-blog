---
title: "Fixing mpxio Multipathing"
tags: [Solaris, mpxio, SAN]
date: 2012-06-07
category: Solaris
---

When presenting LUNs from a new EMC VNX array to Solaris 10 hosts, we found
that `mpxio` wasn't successfully multipathing everything. We're using two
arrays, with four paths to each. We should be seeing two multipahted LUNs,
but for one set, we see eight single paths.

```cmd
# inq | grep VRAID
/dev/rdsk/c2t5006016146E07350d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c2t5006016146E07785d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c2t5006016846E07350d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c2t5006016846E07785d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c3t5006016046E07350d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c3t5006016046E07785d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c3t5006016946E07350d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c3t5006016946E07785d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c4t600601600DC02D00FA03 :DGC :VRAID :0531 :604FAA85 : 152417280
/dev/rdsk/c4t600601600DC02D00FC03 :DGC :VRAID :0531 :614FAA85 : 419430400
/dev/rdsk/c4t6006016062502E000EA7 :DGC :VRAID :0531 :604FAA71 : 152417280
/dev/rdsk/c4t6006016062502E0010A7 :DGC :VRAID :0531 :614FAA71 : 419430400
```

These are live systems, so a reboot is out of the question. But, you can
give `mpxio` another shot at realizing what it should do by  using `cfgadm`
to `unconfigure`, then `configure` the problematic LUNs.

I'll use `/dev/rdsk/c2t5006016146E07785d0s2` as an example.

```cmd
# cfgadm -al -o show_SCSI_LUN | grep -i  5006016146E07785
c2::5006016146e07785,0       disk       connected    configured   unknown
c2::5006016146e07785,1       disk       connected    configured   unknown
c2::5006016146e07785,2       disk       connected    configured   unknown
# cfgadm -c unconfigure c2::5006016146e07785
```

Once they're all `unconfigure`d, `configure` them

```cmd
# cfgadm -al | grep "disk.*uncon" | while read a b
> do
> print $a
> cfgadm -c configure $a
> done
```

And everything should be multipathed.

```cmd
# inq | grep VRAID
/dev/rdsk/c4t600601600DC02D004244214555A3E111d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c4t600601600DC02D00FA039A1CE799E111d0s2 :DGC :VRAID :0531 :604FAA85 : 152417280
/dev/rdsk/c4t600601600DC02D00FC039A1CE799E111d0s2 :DGC :VRAID :0531 :614FAA85 : 419430400
/dev/rdsk/c4t6006016062502E00AAE7E01F55A3E111d0s2 :DGC :VRAID :0531 :C44FBA57 : 372244480
/dev/rdsk/c4t6006016062502E000EA78F00DB99E111d0s2 :DGC :VRAID :0531 :604FAA71 : 152417280
/dev/rdsk/c4t6006016062502E0010A78F00DB99E111d0s2 :DGC :VRAID :0531 :614FAA71 : 419430400
```

Now if someone could give me a way to stop it happening in the first
place...

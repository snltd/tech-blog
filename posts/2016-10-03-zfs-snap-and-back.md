---
title: "ZFS Snapshot Fun"
date: 2016-10-03
tags: [Solaris, ZFS]
category: ZFS
---

At home I have a Solaris box which, among other things, stores my
digital music library.

```cmd
$ zfs list space/export/flac space/export/mp3
NAME               USED  AVAIL  REFER  MOUNTPOINT
space/export/flac  543G   980G   540G  /export/flac
space/export/mp3   125G   980G   122G  /export/mp3
```

The FLACs are mostly ripped from CDs, so technically, I don't need
to back them up because I still have the original media. But, said
media is packed away and hard to get to, and ripping it just the
once was plenty. I don't want to do it again. I'd rather have it all
backed up in S3, where recovery would be a long, but hands-free
process. There's also a bunch of stuff from other sources, which I
can't easily get again.

Everything in the `flac` dataset exists, transcoded, in `mp3`, so I
can cram more stuff onto my phone, car USB stick or whatever. I have
a script which ensures consistency between the two.  So, I'm wasting
my money backing up the MP3s that I've generated from FLACs.

I have a simple script which syncs the `flac` and `mp3` ZFS datasets
with S3 buckets. (Including, of course, lots of safety checks to
make sure we don't accidentally sync an empty directory because a
mount failed somewhere!)

I don't want to write something that checks the bucket copies
conditionally: Amazon have done that for me with `aws sync`. It
would be far simpler for me to sync an `mp3` dataset which only
contains the stuff that can't be re-generated from the original
FLACs.

I'm going to time the operations so you can see how quick ZFS does
these things. I habitually (and dogmatically) use `timex`, which
displays all its times in seconds.

```cmd
# timex zfs snapshot space/export/mp3@for_aws
real           0.13
user           0.00
sys            0.00
# timex zfs clone -o mountpoint=/export/mp3_sync space/export/mp3@for_aws \
  space/export/mp3_sync
real           0.50
user           0.00
sys            0.01
```

Now I have an exact copy of my original `mp3` dataset, mounted at
`/export/mp3_sync`. Although they are clearly linked to one another,
changes made in either dataset will not be reflected in the other.

The `flac` and `mp3` filesystems follow the same hierarchy, so I
can:

```cmd
$ timex find /export/flac -type d | sed 's|/flac/|/mp3_sync/|' | while read d
> do
>    test -d $d && [[ -n $(print $d | cut -d/ -f6) ]] && rm -fr $d
> done
real           6.63
user           0.01
sys            0.11
$ du -sh /export/mp3*
 122G   /export/mp3
  58G   /export/mp3_sync
```

Well, it's not much, but it's still 64Gb/month I don't need to pay for.

(The `cut` test is necessary because I only want to remove
directories which are albums: they're all at a cetain depth.)

When the sync is done, it's quick and easy to clean up:

```cmd
$ zfs destroy space/export/mp3_sync
real           2.17
user           0.00
sys            0.12
$ zfs destroy space/export/mp3@for_aws
real           0.18
user           0.00
sys            0.00
```

This is a quick and fairly trivial project, which took all of five
seconds to roll into my AWS backup script, but I think it's
interesting because it shows a more creative use of ZFS features
than simply rolling back to yesterday's code, or stamping out zones
from a cloned dataset.

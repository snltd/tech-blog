---
title: "Nice fonts on Solaris"
tags: [Solaris, X, fonts, desktop, kde]
date: 2009-10-27
category: Solaris
---

I'm finnicky. I've spent so long messing about with Fontconfig, trying to
get something I like. Here's my `/etc/fonts/local.conf`

I'm on Solaris Nevada build 124, using the fontconfig-2.7.1 packages
supplied with the O/S. I use the NVIDIA driver, and have a 21&quot; Samsung
LCD screen.

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>

  <dir>/storage/fonts</dir>

  <cachedir>/var/fontconfig/cache</cachedir>

  <cachedir>~/.fontconfig</cachedir>

  <!-- Use the FreeType auto-hinter -->

  <match target="font">
  <edit name="autohint" mode="assign">
    <bool>true</bool>
  </edit>
  </match>

  <!--  Use Slight Hinting -->
  <match target="font">
  <edit name="hintstyle" mode="assign">
    <const>hintslight</const>
  </edit>
  </match>

  <!--  Enable sub-pixel rendering -->

  <match target="font">
  <edit name="rgba" mode="assign">
    <const>rgb</const>
  </edit>
  </match>

  <!-- disable bitmapped fonts -->

  <selectfont>
    <rejectfont>
      <pattern>
        <patelt name="scalable">
          <bool>false</bool>
        </patelt>
      </pattern>
    </rejectfont>
  </selectfont>

  <!-- disable autohinter for bold fonts -->

  <match target="font">
    <test name="weight" compare="more">
      <const>medium</const>
    </test>
    <edit name="autohint" mode="assign">
      <bool>false</bool>
    </edit>
  </match>

</fontconfig>
```

Maybe it'll work for you, maybe not. It's largely down to personal
preference, but it seems the value of sub-pixel rendering changes from
screen to screen.

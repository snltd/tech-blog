---
title: Printing a diameter symbol with TexLive
tags: [TeX]
date: 2012-05-13
category: TeX
---

Sometimes the old ways of doing things are the best. Take
[TeX](http://tug.org/). God knows how many years on and there's still
nothing that produces comparable documents.  I love it, even when it
frustrates and baffles me (which it frequently does) because nothing
that it does is for no reason. It's deeply logical and consistent, and
if something isn't working right, you know it's your fault. There's not
a lot of software like that.

I use TeX for all kinds of things. What little paper correspondance I do
now is always in TeX, and I even typeset my wedding invitations with it.
I use it [in my artwork](http://rdfisher.co.uk/piece/series/1-116/101) too,
which I was doing today. I needed to print a diameter symbol, and all my
documentation told me that

```latex
\diameter
```

was all I needed, but I kept getting the dreaded

```
! Undefined control sequence.
<recently read> \diameter

l.15 $\diameter
               7.24 -0/+0.09mm$
```

error. What that means is, "I don't know what `\diameter` is". I'm sure
I've used `\diameter` in the past, but I've recently moved to TexLive from
teTex, and I haven't quite got used to it yet. After a bit of digging I
found a fix, which involved using the `MnSymbol` package. It's a part of
TeXLive, so all you have to do is put

```latex
\usepackage{MnSymbol}
```

in your preamble and you've got `\diameter`. (And probably a whole load of
other stuff too.)

I couldn't be bothered to properly typeset TeX, but [someone else has
put a lot of effort into doing
so](http://edward.oconnor.cx/2007/08/tex-poshlet). Check it out.

In case you're wondering, 7.24 -0/+0.09mm is the diameter and tolerence
for the hole in the middle of a record according to the [BS1928-1965
standard](http://www7a.biglobe.ne.jp/~yosh/standards_table.htm).

---
title: "The World's Worst Interview Question"
date: 2017-09-28
tags: [Interviews]
category: Rants
---

Everywhere I work, whenever we interview new people, I end up telling this
story. So I might as well write it down.

About fifteen years ago, I was being interviewed for some sys-admin job or
other. There were two people, my prospective manager, and a techie. I remember
nothing of the manager's questions, so they must have been pretty standard. Then
over to the techie, who asked me, with some gravitas, the single most stupid
question I've ever been asked at interview.

> Three letters of the alphabet are not valid options in GNU `ls`. What are
> they?

The story breaks down a little here, because it's so long ago, I can't remember
the details. But I'm pretty sure "`man ls` will tell you" was not the answer he
was looking for. He knew what they were, and he expected me to.

I don't remember if I was offered the job or not.

```ruby
ruby -e "p ('a'..'z').to_a - (%x(ls --help).downcase.scan(/^ +-(\w)/).flatten)"
```

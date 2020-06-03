---
title: "Miserable Old Duffer's Guide to Working With Clojure"
date: 2020-04-08
tags: [Clojure]
layout: post
category: programming
---

I'm not going to talk about the language, or its philosophy, or its pitfalls
or best practices, or any of that. I'm going to talk about the most
significant, but least expected, barrier to learning Clojure: workflow.

It took me a while to work out how to work with Clojure.

## REPL

Everyone bangs on about the REPL. I guess if you come from a compiled language
background, it's pretty exciting, but my gateway drug to Clojure was Ruby, and
I've clocked up a lot of hours in `irb`.

I immediately felt comfortable in the standard Clojure REPL just like IRB, and
it's fine for that, but I found [Rebel
Readline](https://github.com/bhauman/rebel-readline), with its ability to
highlight, automatically pop up function arguments, and balance parentheses,
made the experience much better.

## REPL Integration and Editing

The REPL was great for getting started, and it's quite feasible to put
together complete programs in there, but when I learn a language I'm more
comfortable writing something, running it, and iterating like that. This is
where I hit a snag, because the JVM start up time makes it impractical to work
like that.

A good Clojure work flow requires integration of REPL and editor. That is, an
IDE. I've tried various IDEs: I want to like them, I want to get it, but I
never get on with them. I want to use `vi`, and proper `vi`, not sketchy
bindings in something built not to use them. I use a Xerox Alto style portrait
mode screen with a pretty low resolution, and pretty big text (I'm old, okay?)
and modern IDEs are absolutely incompatible with that layout.

As I was picking up the language syntax, and writing 20-line programs, I quite
liked [Nightcode](https://sekao.net/nightcode/), but I couldn't use it for
anything non-trivial. I tried Atom, Lighttable, even Emacs, but whatever the
long-term benefits, twenty-five years of `hjkl` habits are not easily
overcome. And learning Clojure was enough on its own, without having to learn
an IDE at the same time.

Eventually I bit the bullet and installed
[vim-fireplace](https://github.com/tpope/vim-fireplace). This gives me a close
enough integration with the REPL, and all I had to learn was [a few new
bindings](https://gist.github.com/nblumoe/5450099).

I also have [vim-paredit](https://github.com/vim-scripts/paredit.vim), which
takes care of bracket and quote balancing, and
[rainbow-parentheses](https://github.com/kien/rainbow_parentheses.vim) makes
the reading a little easier, particularly if you have a light-on-dark
colourscheme. (Which I [generally
don't](https://ethanschoonover.com/solarized/).) It's true what Lisp people
say though: after a little while you don't notice the parentheses.

To work on a Clojure project, I `cd` to the directory and run

```cmd
$ lein repl
```

then once it's up, open a new terminal tab and `vi` the file. I can evaluate
the expression under the cursor with `cpp`, or run the whole program with
`:%Eval`. Output appears at the bottom of the screen. I've seen people do
fancier things with IDE REPL integration, but I'm happy with what I have.

## Testing

I had the same problem with tests as with execution. When running `lein test`
takes at least half a minute, the appeal of unit tests lessens dramatically.

Now I use [lein-test-refresh](https://github.com/jakemcc/lein-test-refresh),
a Leiningen plugin that re-runs tests whenever anything under `test/` changes.
When I open the REPL tab I mentioned earlier, I also open a test tab, and run

```cmd
$ lein test-refresh
```

Then I can ctrl-arrow between my full-screen editor window and the full-screen
test output whenever I make a change. It's a super-fast cycle. If I had more
screen real-estate I would probably tile two windows together, but then I'd
have to move my eyes, and I can't be bothered with that.

I have looked at a couple of the other testing frameworks, but so far I like
`clojure.test` just fine, and I feel that if I have easy access to mocks and
stubs and spies, I'll use them, rather than putting in the effort to write
more purely functional code which doesn't need such things.

## Linting and Static Analysis

I'm a big fan of static analysis, because it can teach you a lot about
idiomatic use of the language. I very much like
[kibit](https://github.com/jonase/kibit), which [integrates with
`vim`](https://github.com/humorless/vim-kibit), and offers some excellent
advice. The same author also provides the linter
[Eastwood](https://github.com/jonase/eastwood) and there's [a
vim plugin](https://github.com/venantius/vim-eastwood) for that too.

## Deployment

Despite -- or possibly because of -- having worked in operations for twenty
years, deploying every kind of artefact on every kind of platform, I'm a big
fan of
[Heroku](https://devcenter.heroku.com/articles/getting-started-with-clojure).
It supports Clojure with virtually no effort, and works just great. Merge to a
`release` branch, and boom, it's live. Lovely.

I've also deployed Clojure code into Amazon ECS using Docker. For minimum
resistance,
[the images on Docker Hub](https://hub.docker.com/_/clojure/) work just fine
(I favour the Alpine flavour), but it's easy to start from a bare OS image and
chuck in a JRE and Leiningen.

## Done

That's my workflow. It's simple and a bit old fashioned, which is probably why
it suits me.

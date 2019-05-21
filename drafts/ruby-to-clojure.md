## Types

Clojure, like Ruby, is dynamically typed. And it has very few types,
most of which are familiar from Ruby.

The staple type in Clojure, it being a Lisp, are lists. I don't
think you'd say there was a strict analogy to these in Ruby. They
look like this.

```clj
(1 2 3 4)
(dog cat mouse)
```

When you add things to a list, they go on the front.

```clj
user=> (def mylist (list 1 2 3 4))
user=> (conj mylist 5)
(5 1 2 3 4)
```

In Ruby we use a lot of arrays. Their closest analogy in Clojure
would be *vectors*. They are indexed, and can look like Ruby
arrays. When you append things, they go on the end, like in Ruby.

```clj
user=> (def myvector [1 2 3 4])
user=> (conj myvector 5)
[1 2 3 4 5]
```

(In fact, Clojure vectors can look *exactly* like Ruby arrays.
Because commas are whitespace in Clojure, `[1 2 3.4]` can also be
written as `[1, 2, 3, 4]`.)

Like Ruby, Clojure has sets:

```clj
user=> (def myset #{1 2 3})
#'user/myset
user=> (conj myset 4)
#{1 4 3 2}
user=> (conj myset 4)
#{1 4 3 2}
```

And what Ruby calls hashes exist as *maps*.

```
```


## Gems

The common way to do Clojure is Leiningen.

```cmd
$ lein new app meetup-generator
```

The equivalent of the `Gemfile` is the `dependencies` block of
`project.clj`. You speficy a ***WHAT?*** and a version.



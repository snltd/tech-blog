---
title: "SQLite, Node, and foreign keys"
tags: [Node, SQLite]
date: 2012-07-20
category: Node
layout: post
---

I've been experimenting with writing a new interface to
[s-audit](https://github.com/snltd/s-audit) in
[Node](http://nodejs.org), storing host data in a a
[SQLite](http://www.sqlite.org) database. It was all going well,
creating audit groups, adding new clients and new audit types, but when
I started to delete them, I hit problems. I'd used foreign keys with the
`CASCADE` keyword to cascade `DELETE`s down through the tables, and they
didn't work. A bit of digging through [the SQlite
documentation](http://www.sqlite.org/docs.html) (which is generally very
good, and one of many reasons to like the software) and I found that
with recent SQLite versions, foreign keys are turned off by default. I
could turn them on manually with the SQLite client using

```conf
PRAGMA FOREIGN KEY=on;
```

but the docs said my client may not even have foreign key support
compiled in. How to find out? This bit of Node showed me what I needed
to know:

```javascript
db.get('PRAGMA foreign_keys', function(err, res) {
    console.log('pragma res is ' + res.foreign_keys);
});
```

It gave me a big fat `0`. If I didn't have foreign key support in my
library, then I think it would have been `undefined`. So, how to pass
the pragma? It seems horribly inefficient to tag it in front of every
query, so I tried putting an anonymous callback into my function which
creates the SQLite session used throughout the code:

```javascript
var db = new sqlite3.Database(config.DB, function() {
    db.run('PRAGMA foreign_keys=on');
    }
);
```

When node hit the `db.get` code above, it gave me the beautiful `1` I
was looking for, and my foreign keys worked a charm.

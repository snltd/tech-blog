---
title: "Properly Mocking Chefspec Search Results"
tags: [Chef, Chefspec]
date: 2014-02-24
category: Chef
---

I
like [Chefspec](https://github.com/sethvargo/chefspec), and on the
whole find it very helpful when I'm writing cookbooks. At times though,
it can be rather frustrating. A frustration I hit today was in mocking a
search
result. My recipe pulled a node name out of a the data returned
by `search`, and fed it into a template. (It was configuring a Redis
slave, and the search looked up the relevant master.)

This was done by

```ruby
redis_slaveof = results.first.name
```

Don't worry, there was logic around this, and it only got executed if
the search returned exactly one result. But, when I ran the test, it
failed with:

```
Failure/Error: ChefSpec::Runner.new do |node|
NoMethodError:
  undefined method `name' for "10745740492":String
```

My mock was of the form that you find in the Chefspec docs. Something like:

```ruby
stub_search('node', "chef_environment:#{c_env} AND redis.type:master " +
"AND redis.service:#{test_service}").and_return([{ name: "#{test_master}" }])
```

So, it's clear why the `NoMethodError` got thrown: name's a property,
not a method. What you need to return is an object which has a name
method, which returns the string you want in your mocked search. What
you need is a
[mash](http://www.ruby-doc.org/gems/docs/z/zerobearing-hashie-0.1.9/Hashie/Mash.html).

Require the Gem (assuming you've installed it of course), and create a
mash with a single fake method, `name`, which returns the value of the
variable `test_master`, as we tried to do in the `stub_search` above:

```ruby
require 'mash'
search_stub = Mash.new(name: test_master)
```

Then, adapt `stub_search` to return it:


```ruby
stub_search('node', "chef_environment:#{c_env} AND redis_type:master " +
"AND redis_service:#{test_service}").and_return([search_stub])
```

Then, calling the `name` method of the stubbed search works just fine.
Obviously, you can put as many "methods" into your mash as your tests
require.

If you're wondering why I'm using a `+` to concatenate two strings it's
because I'm anal about 80 character lines. Rubocop might not like it,
but it will have to lump it, because using a backslash doesn't work in
this case.

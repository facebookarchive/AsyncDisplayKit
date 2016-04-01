---
title: Pass in Immutable Objects
layout: docs
permalink: /docs/pass-in-immutable-objects.html
---

Objects passed into components should be immutable.

`+new` is called on a background thread. It can even be called on multiple threads simultaneously for the same parameters.

If you pass in mutable objects with `nonatomic` properties, you will introduce thread safety crashes.

Even if you pass in mutable objects that have only `atomic` properties, you are introducing a logic race condition. Rendering the exact same object twice could result in different outputs, which doesn't make any sense!

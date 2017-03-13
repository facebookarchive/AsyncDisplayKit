---
title: ASEnvironment
layout: docs
permalink: /docs/asenvironment.html
prevPage: asvisibility.html
nextPage: asrunloopqueue.html
---

`ASEnvironment` is a performant and scalable way to enable upward and downward propagation of information throughout the node hierarchy. It stores a variety of critical “environmental” metadata, like the trait collection, interface state, hierarchy state, and more. 

Any object that conforms to the `<ASEnvironment>` protocol can propagate specific states defined in an `ASEnvironmentState` up and/or down the ASEnvironment tree. To define how merges of States should happen, specific merge functions can be provided.

Compared to UIKit, this system is very efficient and one of the reasons why nodes are much lighter weight than UIViews. This is achieved by using simple structures to store data rather than creating objects. For example, `UITraitCollection` is an object, but `ASEnvironmentTraitCollection` is just a struct. 

This means that whenever a node needs to query something about its environment, for example to check its [interface state](http://asyncdisplaykit.org/docs/intelligent-preloading.html#interface-state-ranges), instead of climbing the entire tree or checking all of its children, it can go to one spot and read the value that was propogated to it. 

A key operating principle of ASEnvironment is to update values when new subnodes are added or removed. 

ASEnvironment powers many of the most valuable features of AsyncDisplayKit. **There is no public API available at this time.**

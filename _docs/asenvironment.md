---
title: ASEnvironment
layout: docs
permalink: /docs/asenvironment.html
prevPage: debug-tool-ASRangeController.html
nextPage: asrunloopqueue.html
---

`ASEnvironment` is an optimized state propagation system that allows the framework to distrubute a variety of important "evironmental" information up and down the node hierarchy. 

Any object that conforms to the `<ASEnvironment>` protocol can propagate specific states defined in an `ASEnvironmentState` up and/or down the ASEnvironment tree. To define how merges of States should happen, specific merge functions can be provided.

Compared to UIKit, this system is very efficient and one of the reasons why nodes are much lighter weight than UIViews. This is achieved by using simple structures to store data rather than creating objects. For example, `UITraitCollection` is an object, but `ASEnvironmentTraitCollection` is just a struct. 

This means that whenever a node needs to query something about its environment, for example to check its [interface state](http://asyncdisplaykit.org/docs/intelligent-preloading.html#interface-state-ranges), instead of climbing the entire tree or checking all of its children, it can go to one spot and read the value that was propogated to it. 

A key operating principle of ASEnvironment is to update values when new subnodes are added or removed. 

**ASEnvironment is currently used internally in the framework. There is no public API available at this time.**

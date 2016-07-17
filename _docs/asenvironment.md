---
title: ASEnvironment
layout: docs
permalink: /docs/asenvironment.html
prevPage: debug-tool-ASRangeController.html
nextPage: asrunloopqueue.html
---

`ASEnvironment` allows objects that conform to the `<ASEnvironment>` protocol to be able to propagate specific states defined in an ASEnvironmentState up and/or down the ASEnvironment tree. To define how merges of States should happen, specific merge functions can be provided.

One of AsyncDisplayKit's built in propogation states is the `ASEnvironmentTraitCollection`. This allows nodes to propagate information about the UIDevice down the ASEnvironment tree, to their subnodes. This performance optimization means that we only have to check our UIDevice settings once.  

### Addding your own ASEnvironmentState

Coming Soon...

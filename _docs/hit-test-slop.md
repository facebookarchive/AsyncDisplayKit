---
title: Hit Test Slop
layout: docs
permalink: /docs/hit-test-slop.html
next: batch-fetching-api.html
---

`ASDisplayNode` has a `hitTestSlop` property of type `UIEdgeInsets` that when set to a non-zero inset, increase the bounds for hit testing to make it easier to tap or perform gestures on this node. 

ASDisplayNode is the base class for all nodes, so this property is available on any of AsyncDisplayKit's nodes. 

Note:
- The default is UIEdgeInsetsZero
- This affects the default implementation of `-hitTest` and `-pointInside`, so subclasses should call super if you override it and want hitTestSlop applied.

**A node's ability to capture touch events is restricted by its parent's bounds + parent hitTestSlop UIEdgeInsets.** Should you want to extend the hitTestSlop of a child outside its parent's bounds, simply extend the parent node's hitTestSlop to include the child's hitTestSlop needs.

Check out this cool <a href="debug-tool-hit-test-visualization.html">debug tool</a> that visualizes the hitTestSlop of the nodes in your app. 

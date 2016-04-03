---
title: ASDisplayNode
layout: docs
permalink: /docs/display-node.html
---

ASDisplayNode is the main view abstraction over UIView and CALayer.  It initializes and owns a UIView in the same way UIViews create and own their own backing CALayers.  

Usually a node’s properties will be set on a background thread, and its backing view/layer will be lazily constructed with the cached properties collected by the node.  

In some cases, it is desirable to initialize a node and provide a view to be used as the backing view.  These views are provided via a block that will return a view so that the actual construction of the view can be saved until later.  These nodes’ display step happens synchronously.  This is because a node can only be asynchronously displayed when it wraps an _ASDisplayView, not when it wraps a plain UIView.

The view being lazily loaded means that all setup can happen on a background thread up until the point that the view property of the node is actually accessed.  At this point, the cached values of the node will be applied to the newly created view.  From this point forward, the node’s properties should be accessed on the main thread.  Usually these concerns are taken care of by the container class managing the node.

The properties of the ASDisplayNode mirror the properties of UIViews and CALayers as closely as possible.  When there is an overlap, nodes will favor the naming of UIViews (except for position instead of center). 


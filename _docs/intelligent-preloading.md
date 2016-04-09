---
title: Intelligent Preloading 
layout: docs
permalink: /docs/intelligent-preloading.html
next: subclassing.html
---

While a node's ability to be rendered and measured asynchronously makes it quite powerful, another crucially important layer to ASDK is the idea of intelligent preloading.

As was pointed out in <a href = "getting-started.html">getting started</a>, it is rarely advantageous to use a node outside of the context of one of the node containers.  This is due to the fact that all nodes have a notion of their current interface state.  

This `interfaceState` property is constantly updated by an `ASRangeController` which all containers create and maintain internally.

A node used outside of a container won't have its state updated by any range controller. This sometimes results in a flash as nodes are rendered after realizing they're already onscreen without any warning.

## Interface State Ranges

When nodes are added to a scrolling or paging interface they are typically in one of the following ranges.  This means that as the scrolling view is scrolled, their interface states will be updated as they move through them.

A node will be in one of following ranges: 

<ul>
	<li><strong>Fetch Data Range:</strong> The furthest range out from being visible. This is where content is gathered from an external source, whether that’s some API or a local disk.</li>
	<li><strong>Display Range:</strong> Here, display tasks such as text rasterization and image decoding take place.</li>
	<li><strong>Visible Range:</strong> The node is onscreen by at least one pixel.</li>
</ul>

## ASRangeTuningParameters

The size of each of these ranges is measured in "screenfuls".  While the default sizes will work well for many use cases, they can be tweaked quite easily by setting the tuning parameters for range type on your scrolling node.

<img src="/static/intelligent-preloading.png">

As you can see from the above visualization of a scroll view scrolling through the ranges, the leading and trailing sizes of each range will dynamically change direction based on the direction the user is scrolling.  This allows you to worry about leading and trailing sizes alone without having to worry about reacting to changing scroll directions of your user.  

## Interface State Callbacks

As a user scrolls, nodes move through the ranges and react appropriately by loading data, rendering, etc.  Your own node subclasses can easily tap into this mechanism by implementing the corresponding callback methods.

### Visible Range 
`- (void)visibilityDidChange:(BOOL)isVisible;`

### Display Range
`- (void)displayWillStart`<br/>
`- (void)displayDidFinish`<br/>

### Fetch Data Range
`- (void)fetchData`<br/>
`- (void)clearFetchedData`<br/>

Just remember to call super ok? 😉

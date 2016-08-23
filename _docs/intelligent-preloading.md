---
title: Intelligent Preloading 
layout: docs
permalink: /docs/intelligent-preloading.html
prevPage: upgrading.html
nextPage: containers-overview.html
---

While a node's ability to be rendered and measured asynchronously and concurrently makes it quite powerful, another crucially important layer to ASDK is the idea of intelligent preloading.

As was pointed out in <a href = "getting-started.html">getting started</a>, it is rarely advantageous to use a node outside of the context of one of the node containers.  This is due to the fact that all nodes have a notion of their current interface state.  

This `interfaceState` property is constantly updated by an `ASRangeController` which all containers create and maintain internally.

A node used outside of a container won't have its state updated by any range controller. This sometimes results in a flash as nodes are rendered after realizing they're already onscreen without any warning.

## Interface State Ranges

When nodes are added to a scrolling or paging interface they are typically in one of the following ranges.  This means that as the scrolling view is scrolled, their interface states will be updated as they move through them.

<img src="/static/images/intelligent-preloading-ranges-with-names.png" width="35%">

A node will be in one of following ranges: 

<table style="width:100%" class = "paddingBetweenCols">
  <tr>
    <th>Interface State</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b>Fetch Data</b></td>
    <td>The furthest range out from being visible. This is where content is gathered from an external source, whether that’s some API or a local disk.</td>
  </tr>
  <tr>
    <td><b>Display</b></td>
    <td>Here, display tasks such as text rasterization and image decoding take place.</td>
  </tr>
  <tr>
    <td><b>Visible</b></td>
    <td>The node is onscreen by at least one pixel.</td>
  </tr>
</table>

## ASRangeTuningParameters

The size of each of these ranges is measured in "screenfuls".  While the default sizes will work well for many use cases, they can be tweaked quite easily by setting the tuning parameters for range type on your scrolling node.

<img src="/static/images/intelligent-preloading-ranges-screenfuls.png" width="45%">

In the above visualization of a scrolling collection, the user is scrolling down.  As you can see, the sizes of the ranges in the leading direction are quite a bit larger than the content the user is moving away from (the trailing direction).  If the user were to change directions, the leading and trailing sides would dynamically swap in order to keep memory usage optimal.  This allows you to worry about defining the leading and trailing sizes without having to worry about reacting to the changing scroll directions of your user. 

Intelligent preloading also works in multiple dimensions. 

## Interface State Callbacks

As a user scrolls, nodes move through the ranges and react appropriately by loading data, rendering, etc.  Your own <a href = "subclassing.html">node subclasses</a> can easily tap into this mechanism by implementing the corresponding callback methods.

### Visible Range 
`- (void)visibilityDidChange:(BOOL)isVisible;`

### Display Range
`- (void)displayStateDidChange:(BOOL)inDisplayState;`

### Fetch Data Range
`- (void)loadStateDidChange:(BOOL)inLoadState;`

Just remember to call super ok? 😉

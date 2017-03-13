---
title: Hit Test Slop
layout: docs
permalink: /docs/hit-test-slop.html
prevPage: layout-transition-api.html
nextPage: batch-fetching-api.html
---

`ASDisplayNode` has a `hitTestSlop` property of type `UIEdgeInsets` that when set to a non-zero inset, increase the bounds for hit testing to make it easier to tap or perform gestures on this node. 

ASDisplayNode is the base class for all nodes, so this property is available on any of AsyncDisplayKit's nodes. 

<div class = "note">
<strong>Note:</strong> This affects the default implementation of <code>-hitTest</code> and <code>-pointInside</code>, so subclasses should call super if you override it and want hitTestSlop applied.
</div>

A node's ability to capture touch events is restricted by its parent's bounds + parent hitTestSlop UIEdgeInsets. Should you want to extend the hitTestSlop of a child outside its parent's bounds, simply extend the parent node's hitTestSlop to include the child's hitTestSlop needs.

### Usage

A common need for hit test slop, is when you have a text node (aka label) you'd like to use as a button.  Often, the text node's height won't meet the 44 point minimum recommended for tappable areas.  In that case, you can calculate the difference, and apply a negative inset to your label to increase the tappable area.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
ASTextNode *textNode = [[ASTextNode alloc] init];

CGFloat padding = (44.0 - button.bounds.size.height)/2.0;
textNode.hitTestSlop = UIEdgeInsetsMake(-padding, 0, -padding, 0);
</pre>
<pre lang="swift" class = "swiftCode hidden">
let textNode = ASTextNode()

let padding = (44.0 - button.bounds.size.height)/2.0
textNode.hitTestSlop = UIEdgeInsetsMake(-padding, 0, -padding, 0)
</pre>
</div>
</div>

<div class = "note">
To visualize <code>hitTestSlop</code>, check out the <a href="debug-tool-hit-test-visualization">debug tool</a>.
</div>

---
title: ASDisplayNode
layout: docs
permalink: /docs/display-node.html
prevPage: containers-aspagernode.html
nextPage: cell-node.html
---

### Node Basics

`ASDisplayNode` is the main view abstraction over `UIView` and `CALayer`.  It initializes and owns a `UIView` in the same way `UIViews` create and own their own backing `CALayers`.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
	<pre lang="objc" class="objcCode">
ASDisplayNode *node = [[ASDisplayNode alloc] init];
node.backgroundColor = [UIColor orangeColor];
node.bounds = CGRectMake(0, 0, 100, 100);

NSLog(@"Underlying view: %@", node.view);
	</pre>

	<pre lang="swift" class = "swiftCode hidden">
let node = ASDisplayNode()
node.backgroundColor = UIColor.orangeColor()
node.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)

print("Underlying view: \(node.view)")
	</pre>
</div>
</div>

A node has all the same properties as a `UIView`, so using them should feel very familiar to anyone familiar with UIKit.

Properties of both views and layers are forwarded to nodes and can be easily accessed.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
	<pre lang="objc" class="objcCode">
ASDisplayNode *node = [[ASDisplayNode alloc] init];
node.clipsToBounds = YES;				  // not .masksToBounds
node.borderColor = [UIColor blueColor];  //layer name when there is no UIView equivalent

NSLog(@"Backing layer: %@", node.layer);
	</pre>

	<pre lang="swift" class = "swiftCode hidden">
let node = ASDisplayNode()
node.clipsToBounds = true			     // not .masksToBounds
node.borderColor = UIColor.blueColor()  //layer name when there is no UIView equivalent

print("Backing layer: \(node.layer)")
	</pre>
</div>
</div>

As you can see, naming defaults to the `UIView` conventions<a href = "/docs/display-node.html#addendum">***</a> unless there is no `UIView` equivalent.  You also have access to your underlying `CALayer` just as you would when dealing with a plain `UIView`.

When used with one of the <a href = "/docs/getting-started.html#node-containers">node containers</a>, a node’s properties will be set on a background thread, and its backing view/layer will be lazily constructed with the cached properties collected by the node.  You rarely need to worry about jumping to a background thread as this will be taken care of by the framework, but it's important to know that this is happening under the hood.

### View Wrapping

In some cases, it is desirable to initialize a node and provide a view to be used as the backing view.  These views are provided via a block that will return a view so that the actual construction of the view can be saved until later.  These nodes’ display step happens synchronously.  This is because a node can only be asynchronously displayed when it wraps an `_ASDisplayView` (the internal view subclass), not when it wraps a plain `UIView`.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
	<pre lang="objc" class="objcCode">
ASDisplayNode *node = [ASDisplayNode alloc] initWithViewBlock:^{
	SomeView *view  = [[SomeView alloc] init];
	return view;
}];
	</pre>

	<pre lang="swift" class = "swiftCode hidden">
let node = ASDisplayNode(viewBlock: { () -> UIView! in
    let view = SomeView();
    return view
})
	</pre>
</div>
</div>

Doing this allows you to wrap existing views if that is preferable to converting the `UIView` subclass to an `ASDisplayNode` subclass.

<div class = "note" id = "addendum">
	<a href = "/docs/display-node.html#addendum">***</a> The only exception is that nodes use `position` instead of `center` for reasons beyond this intro.
</div>

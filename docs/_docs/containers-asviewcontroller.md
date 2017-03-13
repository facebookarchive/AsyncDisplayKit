---
title: ASViewController
layout: docs
permalink: /docs/containers-asviewcontroller.html
prevPage: faq.html
nextPage: containers-asnodecontroller.html
---

`ASViewController` is a subclass of `UIViewController` that adds several useful features for hosting `ASDisplayNode` hierarchies.

An `ASViewController` can be used in place of any `UIViewController` - including within a `UINavigationController`, `UITabBarController` and `UISplitViewController` or as a modal view controller. 

Benefits of using an `ASViewController`:
<ol>
<li><b>Save Memory</b>. An <code>ASViewController</code> that goes off screen will automatically reduce the size of the <a href="intelligent-preloading.html">fetch data</a> and <a href="intelligent-preloading.html">display ranges</a> of any of its children. This is key for memory management in large applications. </li>
<li><b><a href="asvisibility.html"><code>ASVisibility</code></a> Feature</b>. When used in an <code>ASNavigationController</code> or <code>ASTabBarController</code>, these classes know the exact number of user taps it would take to make the view controller visible.</li>
</ol>

More features will be added over time, so it is a good idea to base your view controllers off of this class. 

## Usage

A `UIViewController` provides a view of its own. An `ASViewController` is assigned a node to manage in its designated initializer `-initWithNode:`. 

Consider the following `ASViewController` subclass, `PhotoFeedNodeController`, from the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram example project</a> that would like to use a table node as its managed node. 

This table node is assigned to the `ASViewController` in its `-initWithNode:` designated initializer method.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    _tableNode.dataSource = self;
    _tableNode.delegate = self;
  }
  
  return self;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
func initWithModel(models: Array&lt;Model&gt;) {
	let tableNode = ASTableNode(style:.Plain)

    super.initWithNode(tableNode)

    self.models = models
    
    self.tableNode = tableNode
    self.tableNode.delegate = self
    self.tableNode.dataSource = self
    
    return self
}
</pre>
</div>
</div>

<br>
<div class = "note">
<b>Conversion Tip</b>: If your app already has a complex view controller hierarchy, it is perfectly fine to have all of them subclass <code>ASViewController</code>. That is to say, even if you don't use <code>ASViewController</code>'s designated initializer <code>-initiWithNode:</code>, and only use the <code>ASViewController</code> in the manner of a traditional <code>UIViewController</code>, this will give you the additional node support if you choose to adopt it in different areas your application. 
</div>


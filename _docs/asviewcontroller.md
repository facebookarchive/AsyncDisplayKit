---
title: ASViewController
layout: docs
permalink: /docs/asviewcontroller.html
prevPage: 
nextPage: aspagernode.html
---

ASViewController is a direct subclass of UIViewController.  For the most part, it can be used in place of any UIViewController relatively easily.  

The main difference is that you construct and return the node you'd like managed as opposed to the way UIViewController provides a view of its own.

Consider the following ASViewController subclass that would like to use a custom table node as its managed node.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (instancetype)initWithModel:(NSArray *)models
{
    ASTableNode *tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

    if (!(self = [super initWithNode:tableNode])) { return nil; }

    self.models = models;
    
    self.tableNode = tableNode;
    self.tableNode.dataSource = self;
    
    return self;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
func initWithModel(models: Array<Model>) {
	let tableNode = ASTableNode(style:.Plain)

    super.initWithNode(tableNode)

    self.models = models
    
    self.tableNode = tableNode
    self.tableNode.dataSource = self
    
    return self
}
</pre>
</div>
</div>

The most important line is:

<code>if (!(self = [super initWithNode:tableNode])) { return nil; }</code>

As you can see, ASViewController's are initialized with a node of your choosing.   
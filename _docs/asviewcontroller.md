---
title: ASViewController
layout: docs
permalink: /docs/asviewcontroller.html
next: aspagernode.html
---

ASViewController is a direct subclass of UIViewController.  For the most part, it can be used in place of any UIViewController relatively easily.  

The main difference is that you construct and return the node you'd like managed as opposed to the way UIViewController provides a view of its own.

Consider the following ASViewController subclass that would like to use a custom table node as its managed node.

```
- (instancetype)initWithModel:(NSArray *)models
{
    ASTableNode *tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

    if (!(self = [super initWithNode:tableNode])) { return nil; }

    self.models = models;
    
    self.tableNode = tableNode;
    self.tableNode.dataSource = self;
    
    return self;
}
```

The most important line is:

<code>if (!(self = [super initWithNode:tableNode])) { return nil; }</code>

As you can see, ASViewController's are initialized with a node of your choosing.   
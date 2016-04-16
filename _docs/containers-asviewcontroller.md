---
title: ASViewController
layout: docs
permalink: /docs/containers-asviewcontroller.html
next: containers-astablenode.html
---

`ASViewController` is a subclass of `UIViewController` and adds the following features.
- handles the measurement stuff
- handles rotation 
- additional memory management to help deep nativation stacks manage memory

An `ASViewController` can be used in place of any `UIViewController` - including within a `UINavigationController`, `UITabBarController` and `UISpitViewController` or as a modal view controller.

###Example Code###
A `UIViewController` provides a view of its own. An `ASViewController` is assigned a node to manage in its designated initializer `initWithNode:`. 

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

###Example Apps###





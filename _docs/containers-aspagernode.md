---
title: ASPagerNode
layout: docs
permalink: /docs/containers-aspagernode.html
next: display-node.html
---

ASPagerNode is a specialized subclass of ASCollectionNode.  Using it allows you to produce a page style UI similar to what you'd create with a UIPageViewController with UIKit.  Luckily, the API is quite a bit simpler than UIPageViewController's.

The main dataSource methods are:

<code>- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode</code>

and 

<code>- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index</code>

or

<code>- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index</code>


These two methods, just as with ASCollectionNode and ASTableNode need to return either an ASCellNode or an block it can use to return one later.  

One especially useful pattern is to return an ASCellNode that is initialized with an existing UIViewController or ASViewController.

```
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
    CGSize pagerNodeSize = pagerNode.bounds.size;
    NSArray *animals = self.animals[index];
    
    ASCellNode *node = [[ASCellNode alloc] initWithViewControllerBlock:^{
        return [[AnimalTableNodeController alloc] initWithAnimals:animals];;
    } didLoadBlock:nil];
    
    node.preferredFrameSize = pagerNodeSize;
    
    return node;
}
```

In this example, you can see that the node is constructed using the `-initWithViewControllerBlock:` method.  It is usually necessary to provide a cell created this way with a preferredFrameSize so that it can be laid out correctly.




---
title: ASPagerNode
layout: docs
permalink: /docs/containers-aspagernode.html
next: display-node.html
---

ASPagerNode is a subclass of ASCollectionNode. Using it allows you to produce a page style UI similar to what you'd create with UIKit's UIPageViewController. Luckily, the API is quite a bit simpler than UIPageViewController's. 

The main dataSource methods are:

`- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode`

and 

`- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index`

or

`- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index` **(recommended)**

These two methods, just as with `ASCollectionNode` and `ASTableNode` need to return either an `ASCellNode` or a block it can use to return one later.  

Note that `pagerNode:nodeAtIndex:` will be called on the main thread and should not implement reuse (it will be called once per row).  Unlike UICollectionView's version, this method is not called when the row is about to display. 

`pagerNode:nodeBlockAtIndex:` returns a block that creates the node for display at this index. This the reccommended option because it is more performant. It concurrently allocates cell nodes, meaning that all of the `init:` methods for all of your subnodes are run in the background. It is very important to note that blocks **must be thread-safe** as they can be called on the main thread or a background queue. They should also not implement reuse (it will be called once per row). 

##NodeBlock Thread Safety Warning##

It is imperative that the data model be accessed outside of the `nodeNlock`. E.g. if you need to use the `indexPath` to get a photo out of a model, you should use the indexPath to get it out of the data model before creating the node block. This means that it is highly unlikely that you should need to use the `indexPath` inside of the block. 

##NodeBlock Example##

One especially useful pattern is to return an ASCellNode that is initialized with an existing UIViewController or ASViewController.
```objective-c
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

Check out the following sample apps to see an ASPagerNode implemented within an app:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/PagerNode">PagerNode</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/VerticalWithinHorizontalScrolling">VerticalWithinHorizontalScrolling</a></li>
</ul>


---
title: ASPagerNode
layout: docs
permalink: /docs/containers-aspagernode.html
next: display-node.html
---

`ASPagerNode` is a subclass of `ASCollectionNode`. 

Using it allows you to produce a page style UI similar to what you'd create with UIKit's `UIPageViewController`. ASPager node currently supports staying on the correct page during rotation. It does _not_ currently support circular scrolling.

The main dataSource methods are:

`- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode`

and 

`- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index`

or

`- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index` **_(recommended)_**

These two methods, just as with `ASCollectionNode` and `ASTableNode` need to return either an `ASCellNode` or an `ASCellNodeBlock` - a block that creates a `ASCellNode` which can be run on a background thread. 

Note that both of these methods should not implement reuse (they will be called once per row). Unlike UIKit, these methods are not called when the row is just about to display. 

While `pagerNode:nodeAtIndex:` will be called on the main thread, `pagerNode:nodeBlockAtIndex:` is preferred because it concurrently allocates cell nodes, meaning that all of the `init:` methods for all of your subnodes are run in the background. **It is very important that node blocks be thread-safe** as they can be called on the main thread or a background queue.

##Node Block Thread Safety Warning##

It is imperative that the data model be accessed outside of the node block. This means that it is highly unlikely that you should need to use the index inside of the block. 

In the example below, you can see how the index is used to access the photo model before creating the node block.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
  PhotoModel *photoModel = _photoFeed[index];
  
  // this part can be executed on a background thread - it is important to make sure it is thread safe!
  ASCellNode *(^cellNodeBlock)() = ^ASCellNode *() {
    PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhoto:photoModel];
    return cellNode;
  };
  
  return cellNodeBlock;
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
func pagerNode(pagerNode: ASPagerNode!, nodeBlockAtIndex index: Int) -> ASCellNodeBlock! {
    guard photoFeed.count > index else { return nil }
    
    let photoModel = photoFeed[index]
    let cellNodeBlock = { () -> ASCellNode in
        let cellNode = PhotoCellNode(photo: photoModel)
        return cellNode
    }
    return cellNodeBlock
}
</pre>
</div>
</div>

##Use ASViewControllers For Optimal Performance##

One especially useful pattern is to return an ASCellNode that is initialized with an existing UIViewController or ASViewController. For optimal performance, use an ASViewController.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
    NSArray *animals = self.animals[index];
    
    ASCellNode *node = [[ASCellNode alloc] initWithViewControllerBlock:^{
        return [[AnimalTableNodeController alloc] initWithAnimals:animals];;
    } didLoadBlock:nil];
    
    node.preferredFrameSize = pagerNode.bounds.size;
    
    return node;
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
func pagerNode(pagerNode: ASPagerNode!, nodeAtIndex index: Int) -> ASCellNode! {
    guard animals.count > index else { return nil }

    let animal = animals[index]
    let node = ASCellNode(viewControllerBlock: { () -> UIViewController in
      return AnimalTableNodeController(animals: animals)
    }, didLoadBlock: nil)

    node.preferredFrameSize = pagerNode.bounds.size

    return node
}
</pre>
</div>
</div>

In this example, you can see that the node is constructed using the `-initWithViewControllerBlock:` method.  It is usually necessary to provide a cell created this way with a preferredFrameSize so that it can be laid out correctly.

##Sample Apps##

Check out the following sample apps to see an ASPagerNode implemented within an app:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/PagerNode">PagerNode</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/VerticalWithinHorizontalScrolling">VerticalWithinHorizontalScrolling</a></li>
</ul>

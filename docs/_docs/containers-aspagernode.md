---
title: ASPagerNode
layout: docs
permalink: /docs/containers-aspagernode.html
prevPage: containers-ascollectionnode.html
nextPage: display-node.html
---

`ASPagerNode` is a subclass of `ASCollectionNode` with a specific `UICollectionViewLayout` used under the hood. 

Using it allows you to produce a page style UI similar to what you'd create with UIKit's `UIPageViewController`. `ASPagerNode` currently supports staying on the correct page during rotation. It does _not_ currently support circular scrolling.

The main dataSource methods are:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
</pre>

<pre lang="swift" class = "swiftCode hidden">
func numberOfPagesInPagerNode(pagerNode: ASPagerNode!) -> Int 
</pre>
</div>
</div>

and 

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
</pre>

<pre lang="swift" class = "swiftCode hidden">
func pagerNode(pagerNode: ASPagerNode!, nodeAtIndex index: Int) -> ASCellNode!
</pre>
</div>
</div>

or

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index`
</pre>

<pre lang="swift" class = "swiftCode hidden">
func pagerNode(pagerNode: ASPagerNode!, nodeBlockAtIndex index: Int) -> ASCellNodeBlock!
</pre>
</div>
</div>

These two methods, just as with `ASCollectionNode` and `ASTableNode` need to return either an `ASCellNode` or an `ASCellNodeBlock` - a block that creates an `ASCellNode` and can be run on a background thread. 

Note that neither methods should rely on cell reuse (they will be called once per row). Also, unlike UIKit, these methods are not called when the row is just about to display. 

While `-pagerNode:nodeAtIndex:` will be called on the main thread, `-pagerNode:nodeBlockAtIndex:` is preferred because it concurrently allocates cell nodes, meaning that the `-init:` method of each  of your subnodes will be run in the background. **It is very important that node blocks be thread-safe** as they can be called on the main thread or a background queue.

### Node Block Thread Safety Warning

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

### Using an ASViewController For Optimal Performance

One especially useful pattern is to return an `ASCellNode` that is initialized with an existing `UIViewController` or `ASViewController`. For optimal performance, use an `ASViewController`.

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
    
    node.style.preferredSize = pagerNode.bounds.size;
    
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

    node.style.preferredSize = pagerNode.bounds.size

    return node
}
</pre>
</div>
</div>

In this example, you can see that the node is constructed using the `-initWithViewControllerBlock:` method.  It is usually necessary to provide a cell created this way with a `style.preferredSize` so that it can be laid out correctly.

### Use ASPagerNode as root node of an ASViewController

#### Log message while popping back in the view controller hierarchy
If you use an `ASPagerNode` embedded in an `ASViewController` in full screen. If you pop back from the view controller hierarchy you will see some error message in the console.

To resolve the error message set `self.automaticallyAdjustsScrollViewInsets = NO;` in `viewDidLoad` in your `ASViewController` subclass.

#### `navigationBar.translucent` is set to YES
If you have an `ASPagerNode` embedded in an `ASViewController` in full screen and set the `navigationBar.translucent` to `YES`, you will see an error message while pushing the view controller on the view controller stack.

To resolve the error message add `[self.pagerNode waitUntilAllUpdatesAreCommitted];`  within `- (void)viewWillAppear:(BOOL)animated`  in your `ASViewController` subclass.
Unfortunately the disadvantage of this is that the first measurement pass will block the main thread until it finishes.

#### Some more details about the error messages above
The reason for this error message is that due to the asynchronous nature of AsyncDisplayKit, measurement of nodes will happen on a background thread as UIKit will resize the view of the `ASViewController`  on  on the main thread. The new layout pass has to wait until the old layout pass finishes with an old layout constrained size. Unfortunately while the measurement pass with the old constrained size is still in progress the `ASPagerFlowLayout` that is backing a `ASPagerNode` will print some errors in the console as it expects sizes for nodes already measured with the new constrained size.

### Sample Apps

Check out the following sample apps to see an `ASPagerNode` in action:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/PagerNode">PagerNode</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/VerticalWithinHorizontalScrolling">VerticalWithinHorizontalScrolling</a></li>
</ul>

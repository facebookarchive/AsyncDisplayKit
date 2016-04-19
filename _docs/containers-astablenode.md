---
title: ASTableNode
layout: docs
permalink: /docs/containers-astablenode.html
next: containers-ascollectionnode.html
---

`ASTableNode` is equivalent to UIKit's `UITableView` and can be used in place of any UITableView. 

ASTableNode replaces both of UITableView's required methods

`- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath` 

and

`- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath`

with **_one_** of the following methods (your choice)

`- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath` 

or

`- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath` **_(recommended)_**

These two methods, need to return either an <a href = "cell-node.html">`ASCellNode`</a>. or an `ASCellNodeBlock` - a block that creates a `ASCellNode` which can be run on a background thread. 

Note that both of these methods should not implement reuse (they will be called once per row). Unlike `UITableView`, these methods are not called when the row is just about to display. 

While `tableView:nodeForRowAtIndexPath:` will be called on the main thread, `tableView:nodeBlockForRowAtIndexPath:` is preferred because it concurrently allocates cell nodes, meaning that all of the `init:` methods for all of your subnodes are run in the background. **It is very important that node blocks be thread-safe** as they can be called on the main thread or a background queue (see example below).

Don't forget to set the `.dataSource` and `.deletage` methods on the table node. 

##Node Block Thread Safety Warning##

It is imperative that the data model be accessed outside of the node block. This means that it is highly unlikely that you should need to use the index inside of the block. 

Consider the following `tableView:nodeBlockForRowAtIndexPath:` method from the `PhotoFeedNodeController.m` file in the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a>.

In the example below, you can see how the index is used to access the photo model before creating the node block.

```objective-c
- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PhotoModel *photoModel = [_photoFeed objectAtIndex:indexPath.row];
  
  // this may be executed on a background thread - it is important to make sure it is thread safe
  ASCellNode *(^ASCellNodeBlock)() = ^ASCellNode *() {
    PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhotoObject:photoModel];
    cellNode.delegate = self;
    return cellNode;
  };
  
  return ASCellNodeBlock;
}
```

##Accessing the ASTableView##

<div class = "note">
If you've used previous versions of ASDK, you'll notice that `ASTableView` has been removed in favor of `ASTableNode`.<br><br>

`ASTableView` (an actual UITableView subclass) is still used as an internal property of `ASTableNode`. While it should not be created directly, it can still be used directly by accessing the .view property of an `ASTableNode`.
</div>

For example, you may want to set a table's `.separatorStyle` property. This can be done by accessing the table node's view as seen in the example below. 

**_Don't forget that anything that accesses a view using AsyncDisplayKit's node containers or nodes should be done in viewDidLoad or didLoad, respectively._**

```objective-c
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _tableNode.view.allowsSelection = NO;
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableNode.view.leadingScreensForBatching = AUTO_TAIL_LOADING_NUM_SCREENFULS;  // overriding default of 2.0
}
```

##Table Row Height##

An important thing to notice is that `ASTableNode` does not provide an equivalent to `UITableView`'s

`- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath`

This is because in AsyncDisplayKit, nodes are responsible for determining their height themselves which means you no longer have to write code to determine this detail at the view controller level. 

A node defines its height by way of its layoutSpec returned in the `- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize` method. All nodes given a constrained size are able to calculate their desired size. **Note that nodes that don't have an inherent size, such as an image or map) must set their `.preferredFrameSize` property.** 

**By default, the size range provided to the cell is the width of the table and zero height (min) and maximum is width of table and infinite height (max).**

This is the magic of the `ASTableView`. From the level of the ASCellNode, the cell can very easily control it’s height and the tableNode will automatically adjust accordingly. For an example of this in action, see how the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> inserts comments below comments at a later time, increasing the height magically!

If you call `-setNeedsLayout` on an `ASCellNode`, it will automatically be perform its layout measurement again and if its overall desired size has changed, the table or collection will be informed and update. This is different from UIKit where normally you would have to call reload row / item. This saves tons of code, check out the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> to see side by side implementations of an UITableView and ASTableNode implemented social media feed. 

##Sample Apps##

Check out the following sample apps to see an ASTableNode implemented within an app:
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a></li>
</ul>

---
title: ASTableNode
layout: docs
permalink: /docs/containers-astablenode.html
next: containers-ascollectionnode.html
---

`ASTableNode` is equivalent to UIKit's `UITableView` and can be used in place of any UITableView. 

ASTableNode replaces UITableView's required method

`tableView:cellForRowAtIndexPath:` 

with your choice of **_one_** of the following methods

`- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath` 

or

`- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath` **_(recommended)_**

These two methods, need to return either an <a href = "cell-node.html">`ASCellNode`</a> or an `ASCellNodeBlock`. An ASCellNodeBlock is a block that creates a ASCellNode which can be run on a background thread. Note that ASCellNodes are used by ASTableNode, ASCollectionNod and ASPagerNode. 

Note that both of these methods should not implement reuse (they will be called once per row). However, unlike UITableView, these methods are not called when the row is just about to display. 

####Node Blocks are Best####

While `tableView:nodeForRowAtIndexPath:` will be called on the main thread, `tableView:nodeBlockForRowAtIndexPath:` is preferred because it concurrently allocates cell nodes. This means that all of the init: methods for all of your subnodes are run in the background.

##Replace UITableViewController with ASViewController##

AsyncDisplayKit does not offer an equivalent to UITableViewController. Instead, use an ASViewController initialized with an ASTableNode. 

Consider, again, the ASViewController subclass - PhotoFeedNodeController - from the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> that uses a table node as its managed node.

An `ASTableNode` is assigned to be managed by an `ASViewController` in its `initWithNode:` designated initializer method. 

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

##Node Block Thread Safety Warning##

It is very important that node blocks be thread-safe. One aspect of that is ensuring that the data model is accessed _outside_ of the node block. Therefore, it is unlikely that you should need to use the index inside of the block. 

Consider the following `tableView:nodeBlockForRowAtIndexPath:` method from the `PhotoFeedNodeController.m` file in the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a>.

In the example below, you can see how the index is used to access the photo model before creating the node block.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PhotoModel *photoModel = [_photoFeed objectAtIndex:indexPath.row];
    
    // this may be executed on a background thread - it is important to make sure it is thread safe
    ASCellNode *(^ASCellNodeBlock)() = ^ASCellNode *() {
        PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhoto:photoModel];
        cellNode.delegate = self;
        return cellNode;
    };
    
    return ASCellNodeBlock;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
func tableView(tableView: UITableView!, nodeBlockForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock! {
    guard photoFeed.count > indexPath.row else { return nil }

    let photoModel = photoFeed[indexPath.row]

    // this may be executed on a background thread - it is important to make sure it is thread safe
    let cellNodeBlock = { () -> ASCellNode in
        let cellNode = PhotoCellNode(photo: photoModel)
        cellNode.delegate = self;
        return ASCellNode()
    }

    return cellNodeBlock
}
</pre>
</div>
</div>


##Accessing the ASTableView##
If you've used previous versions of ASDK, you'll notice that `ASTableView` has been removed in favor of `ASTableNode`.

<div class = "note">
`ASTableView` (an actual UITableView subclass) is still used as an internal property of `ASTableNode`. While it should not be created directly, it can still be used directly by accessing the .view property of an `ASTableNode`.
</div>

**Do not forget that anything that accesses a view using AsyncDisplayKit's node containers or nodes should be done in viewDidLoad or didLoad, respectively.**

For example, you may want to set a table's separator style property. This can be done by accessing the table node's view in the `viewDidLoad:` method as seen in the example below. 

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _tableNode.view.allowsSelection = NO;
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableNode.view.leadingScreensForBatching = 3.0;  // overriding default of 2.0
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func viewDidLoad() {
  super.viewDidLoad()

  tableNode.view.allowsSelection = false
  tableNode.view.separatorStyle = .None
  tableNode.view.leadingScreensForBatching = 3.0  // overriding default of 2.0
}
</pre>
</div>
</div>

##Table Row Height##

An important thing to notice is that `ASTableNode` does not provide an equivalent to `UITableView`'s

`tableView:heightForRowAtIndexPath:`

This is because in AsyncDisplayKit, nodes are responsible for determining their height themselves which means you no longer have to write code to determine this detail at the view controller level. 

A node defines its height by way of its layoutSpec returned in the `- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize` method. All nodes given a constrained size are able to calculate their desired size. **Note that nodes that don't have an inherent size, such as an image or map) must set their `.preferredFrameSize` property.** 

**By default, the size range provided to the cell is the width of the table and zero height (min) and maximum is width of table and infinite height (max).**

This is the magic of the `ASTableView`. From the level of the ASCellNode, the cell can very easily control it’s height and the tableNode will automatically adjust accordingly. For an example of this in action, see how the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> inserts comments below comments at a later time, increasing the height magically!

If you call `-setNeedsLayout` on an `ASCellNode`, it will automatically be perform its layout measurement again and if its overall desired size has changed, the table or collection will be informed and update. This is different from UIKit where normally you would have to call reload row / item. This saves tons of code, check out the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> to see side by side implementations of an UITableView and ASTableNode implemented social media feed. 

##Sample Apps with ASTableNodes##
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a></li>
</ul>

---
title: ASTableNode
layout: docs
permalink: /docs/containers-astablenode.html
prevPage: containers-asnodecontroller.html
nextPage: containers-ascollectionnode.html
---

`ASTableNode` is equivalent to UIKit's `UITableView` and can be used in place of any `UITableView`. 

`ASTableNode` replaces `UITableView`'s required method

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
  </pre>
</div>
</div>

with your choice of **_one_** of the following methods

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
override func tableNode(tableNode: ASTableNode, nodeForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNode
  </pre>
</div>
</div>

or

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
override func tableNode(tableNode: ASTableNode, nodeBlockForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock
  </pre>
</div>
</div>

<br>
<div class = "note">
It is recommended that you use the node block version of these methods so that your collection node will be able to prepare and display all of its cells concurrently. This means that all subnode initialization methods can be run in the background.  Make sure to keep 'em thread safe.
</div>

These two methods, need to return either an <a href = "cell-node.html">`ASCellNode`</a> or an `ASCellNodeBlock`. An `ASCellNodeBlock` is a block that creates a `ASCellNode` which can be run on a background thread. Note that `ASCellNodes` are used by `ASTableNode`, `ASCollectionNode` and `ASPagerNode`. 

Note that neither of these methods require a reuse mechanism.

### Replacing UITableViewController with ASViewController

AsyncDisplayKit does not offer an equivalent to `UITableViewController`. Instead, use an `ASViewController` initialized with an `ASTableNode`. 

Consider, again, the `ASViewController` subclass - PhotoFeedNodeController - from the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">`ASDKgram sample app`</a> that uses a table node as its managed node.

An `ASTableNode` is assigned to be managed by an `ASViewController` in its `-initWithNode:` designated initializer method. 

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
    self.tableNode.dataSource = self
    
    return self
}
</pre>
</div>
</div>

### Node Block Thread Safety Warning

It is very important that node blocks be thread-safe. One aspect of that is ensuring that the data model is accessed _outside_ of the node block. Therefore, it is unlikely that you should need to use the index inside of the block. 

Consider the following `-tableNode:nodeBlockForRowAtIndexPath:` method from the `PhotoFeedNodeController.m` file in the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a>.

In the example below, you can see how the index is used to access the photo model before creating the node block.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PhotoModel *photoModel = [_photoFeed objectAtIndex:indexPath.row];
    
    // this may be executed on a background thread - it is important to make sure it is thread safe
    ASCellNode *(^cellNodeBlock)() = ^ASCellNode *() {
        PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhoto:photoModel];
        cellNode.delegate = self;
        return cellNode;
    };
    
    return cellNodeBlock;
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
func tableNode(tableNode: UITableNode!, nodeBlockForRowAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock! {
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


### Accessing the ASTableView

If you've used previous versions of ASDK, you'll notice that `ASTableView` has been removed in favor of `ASTableNode`.

<div class = "note">
<code>ASTableView</code>, an actual <code>UITableView</code> subclass, is still used internally by <code>ASTableNode</code>. While it should not be created directly, it can still be used directly by accessing the <code>.view</code> property of an <code>ASTableNode</code>.

Don't forget that a node's <code>view</code> or <code>layer</code> property should only be accessed after <code>-viewDidLoad</code> or <code>-didLoad</code>, respectively, have been called.
</div>

For example, you may want to set a table's separator style property. This can be done by accessing the table node's view in the `-viewDidLoad:` method as seen in the example below. 

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _tableNode.view.allowsSelection = NO;
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableNode.view.leadingScreensForBatching = 3.0;  // default is 2.0
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func viewDidLoad() {
  super.viewDidLoad()

  tableNode.view.allowsSelection = false
  tableNode.view.separatorStyle = .None
  tableNode.view.leadingScreensForBatching = 3.0  // default is 2.0
}
</pre>
</div>
</div>

### Table Row Height

An important thing to notice is that `ASTableNode` does not provide an equivalent to `UITableView`'s `-tableView:heightForRowAtIndexPath:`.

This is because nodes are responsible for determining their own height based on the provided constraints.  This means you no longer have to write code to determine this detail at the view controller level. 

A node defines its height by way of the layoutSpec returned in the `-layoutSpecThatFits:` method. All nodes given a constrained size are able to calculate their desired size.

<div class = "note">
By default, a <code>ASTableNode</code> provides its cells with a size range constraint where the minimum width is the tableNode's width and a minimum height is <code>0</code>.  The maximum width is also the <code>tableNode</code>'s width but the maximum height is <code>FLT_MAX</code>.
<br><br>
This is all to say, a `tableNode`'s cells will always fill the full width of the `tableNode`, but their height is flexible making self-sizing cells something that happens automatically. 
</div>

If you call `-setNeedsLayout` on an `ASCellNode`, it will automatically perform another layout pass and if its overall desired size has changed, the table will be informed and will update itself. 

This is different from `UIKit` where normally you would have to call reload row / item. This saves tons of code, check out the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> to see side by side implementations of an `UITableView` and `ASTableNode` implemented social media feed. 

### Sample Apps using ASTableNode
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/HorizontalWithinVerticalScrolling">HorizontalWithinVerticalScrolling</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/VerticalWithinHorizontalScrolling">VerticalWithinHorizontalScrolling</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/SocialAppLayout">SocialAppLayout</a></li>
</ul>

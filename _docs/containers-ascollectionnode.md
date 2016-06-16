---
title: ASCollectionNode
layout: docs
permalink: /docs/containers-ascollectionnode.html
prevPage: containers-astablenode.html
nextPage: containers-aspagernode.html
---

ASCollectionNode is equivalent to UIKit's UICollectionView and can be used in place of any UICollectionView. 

ASCollectionNode replaces UICollectionView's required method

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
  </pre>
</div>
</div>

with your choice of **_one_** of the following methods

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
</pre>
  <pre lang="swift" class = "swiftCode hidden">
override func collectionView(collectionView: ASCollectionView, nodeForItemAtIndexPath indexPath: NSIndexPath) -> ASCellNode
  </pre>
</div>
</div>

<p>
or
</p>

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
</pre>
  <pre lang="swift" class = "swiftCode hidden">
override func collectionView(collectionView: ASCollectionView, nodeBlockForItemAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock
  </pre>
</div>
</div>

It is recommended that you use the node block version of the method so that your collection node will be able to prepare and display all of its cells concurrently.

As noted in the previous section:

<ul>
  <li>ASCollectionNodes do not utilize cell resuse.</li>
  <li>Using the "nodeBlock" method is preferred.</li>
  <li>It is very important that the returned node blocks are thread-safe.</li>
  <li>ASCellNodes can be used by ASTableNode, ASCollectionNode and ASPagerNode.</li>
</ul>

### Replacing a UICollectionViewController with an ASViewController

AsyncDisplayKit does not offer an equivalent to UICollectionViewController. Instead, you can use the flexibility of ASViewController to recreate any type of UI<em>...</em>ViewController. 

Consider, the following ASViewController subclass.

An ASCollectionNode is assigned to be managed by an `ASViewController` in its `-initWithNode:` designated initializer method, thus making it a sort of ASCollectionNodeController.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (instancetype)init
{
  _flowLayout     = [[UICollectionViewFlowLayout alloc] init];
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:_flowLayout];
  
  self = [super initWithNode:_collectionNode];
  if (self) {
    _flowLayout.minimumInteritemSpacing  = 1;
    _flowLayout.minimumLineSpacing       = 1;
  }
  
  return self;
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
init() {
  flowLayout     = UICollectionViewFlowLayout()
  collectionNode = ASCollectionNode(collectionViewLayout: flowLayout)

  super.init(node: collectionNode)

  flowLayout.minimumInteritemSpacing  = 1
  flowLayout.minimumLineSpacing       = 1
}
</pre>
</div>
</div>

This works just as well with any node including as an ASTableNode, ASPagerNode, etc.

### Accessing the ASCollectionView
If you've used previous versions of ASDK, you'll notice that `ASCollectionView` has been removed in favor of `ASCollectionNode`.

<div class = "note">
ASCollectionView, an actual UICollectionView subclass, is still used internally by ASCollectionNode. While it should not be created directly, it can still be used directly by accessing the .view property of an ASCollectionNode.

Don't forget that a node's <code>view</code> or <code>layer</code> property should only be accessed after viewDidLoad or didLoad, respectively, have been called.
</div>

The LocationCollectionNodeController above accesses the ASCollectionView directly in viewDidLoad

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _collectionNode.view.asyncDelegate   = self;
  _collectionNode.view.asyncDataSource = self;
  _collectionNode.view.allowsSelection = NO;
  _collectionNode.view.backgroundColor = [UIColor whiteColor];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func viewDidLoad() {
  super.viewDidLoad()

  collectionNode.view.asyncDelegate   = self
  collectionNode.view.asyncDataSource = self
  collectionNode.view.allowsSelection = false
  collectionNode.view.backgroundColor = UIColor.whiteColor()
}
</pre>
</div>
</div>

### Cell Sizing and Layout

As discussed in the <a href = "containers-astablenode.html">previous section</a>, ASCollectionNodes and ASTableNodes do not need to keep track of the height of their ASCellNodes.

Right now, cells will grow to fit their constrained size and will be laid out by whatever UICollectionViewLayout you provide.

Soon, there will be a method such as ASTableNode's `-constrainedSizeForRow:` but at the moment, if you'd like to constrain the size of a cell used in a collection node, you need to wrap your layoutSpec object in an `ASStaticLayoutSpec` and provide it with a 

### Examples

The most detailed example of laying out the cells of an ASCollectionNode is the <a href = "https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CustomCollectionView">CustomCollectionView</a> app.  It includes a Pinterest style cell layout using an ASCollectionNode and a custom `UICollectionViewLayout`.

#### More Sample Apps with ASCollectionNodes

<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CatDealsCollectionView">CatDealsCollectionView</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASCollectionView">ASCollectionView</a></li>
</ul>

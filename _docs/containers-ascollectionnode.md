---
title: ASCollectionNode
layout: docs
permalink: /docs/containers-ascollectionnode.html
next: containers-aspagernode.html
---

`ASCollectionNode` is equivalent to UIKit's `UICollectionView` and can be used in place of any UICollectionView. 

ASCollectionNode replaces UICollectionView's required method

`collectionView:cellForItemAtIndexPath:` 

with your choice of **_one_** of the following methods

`- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath` 

or

`- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath` **_(recommended)_**

<div class = "note">
Note that these are the same methods as the `ASTableNode`! Please read the previous <a href = "containers-astablenode.html">`ASTableNode`</a> section as most of the details here are identical and so we will gloss over them quickly. 
</div>

As noted in the previous section
<ul>
  <li>both of these ASCollectionView methods should not implement reuse (they will be called once per row)</li>
  <li>`collectionView:nodeBlockForRowAtIndexPath:` is preferred to `collectionView:nodeForItemAtIndexPath:` for its concurrent processing</li>
  <li>it is very important that node blocks be thread-safe</li>
  <li>ASCellNodes are used by ASTableNode, ASCollectionNod and ASPagerNode</li>
</ul>

##Replace UICollectionViewController with ASViewController##

AsyncDisplayKit does not offer an equivalent to UICollectionViewController. Instead, use an ASViewController initialized with an ASCollectionNode. 

Consider, the ASViewController subclass - LocationCollectionNodeController - from the <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram sample app</a> that uses a collection node as its managed node.

An `ASCollectionNode` is assigned to be managed by an `ASViewController` in its `initWithNode:` designated initializer method. 

```objective-c
- (instancetype)initWithCoordinates:(CLLocationCoordinate2D)coordinates
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
```

##Accessing the ASCollectionView##
If you've used previous versions of ASDK, you'll notice that `ASCollectionView` has been removed in favor of `ASCollectionNode`.

<div class = "note">
`ASCollectionView` (an actual UICollectionView subclass) is still used as an internal property of `ASCollectionNode`. While it should not be created directly, it can still be used directly by accessing the .view property of an `ASCollectionNode`.
</div>

**Do not forget that anything that accesses a view using AsyncDisplayKit's node containers or nodes should be done in viewDidLoad or didLoad, respectively.**

The LocationCollectionNodeController above accesses the ASCollectionView directly in viewDidLoad

```objective-c
- (void)loadView
{
  [super loadView];
  
  _collectionNode.view.asyncDelegate   = self;
  _collectionNode.view.asyncDataSource = self;
  _collectionNode.view.allowsSelection = NO;
  _collectionNode.view.backgroundColor = [UIColor whiteColor];
}
```

##Table Row Height##

As discussed in the previous <a href = "containers-astablenode.html">`ASTableNode`</a> section, ASCollectionNodes and ASTableNodes do not need to keep track of the height of their ASCellNodes. 

***constrainedSizeForNode (also in table, but more important for collection)
    - check that (0,0) min and (infinity, infinity) max
- example sample photo grid
    - popover, rotated -> how to get size constraint (USE constrainedSizeForNode to do simple divide by 3 width thing)
- document itemSize (check what happens in ASDKgram)

##Sample Apps with ASCollectionNodes##
<ul>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASDKgram">ASDKgram</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CatDealsCollectionView">CatDealsCollectionView</a></li>
  <li><a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/ASCollectionView">ASCollectionView</a></li>
</ul>

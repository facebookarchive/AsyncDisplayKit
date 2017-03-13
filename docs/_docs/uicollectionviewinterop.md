---
title: UICollectionViewCell Interoperability
layout: docs
permalink: /docs/uicollectionviewinterop.html
prevPage: placeholder-fade-duration.html
nextPage: accessibility.html
---

AsyncDisplayKit's `ASCollectionNode` offers compatibility with synchronous, standard `UICollectionViewCell` objects alongside native `ASCellNodes`. 

Note that these UIKit cells will **not** have the performance benefits of `ASCellNodes` (like preloading, async layout, and async drawing), even when mixed within the same `ASCollectionNode`. 

However, this interoperability allows developers the flexibility to test out the framework without needing to convert all of their cells at once. 

## Implementing Interoperability

In order to use this feature, you must:

<ol>
<li>Conform to <code>ASCollectionDataSourceInterop</code> and, optionally, <code>ASCollectionDelegateInterop</code>.</li>
<li>Call <code>registerCellClass:</code> on the <code>collectionNode.view</code> (in <code>viewDidLoad</code>, or register an <code>onDidLoad:</code> block).</li>
<li>Return nil from the <code>nodeBlockForItem...:</code> or <code>nodeForItem...:</code> method. <b>Note:</b> it is an error to return nil from within a <code>nodeBlock</code>, if you have returned a <code>nodeBlock</code> object.</li>
<li>Lastly, you must implement a method to provide the size for the cell. There are two ways this is done:</li>
<ol>
<li><code>UICollectionViewFlowLayout</code> (incl. <code>ASPagerNode</code>). Implement
 <code>collectionNode:constrainedSizeForItemAtIndexPath:</code>.</li>
<li>Custom collection layouts. Set <code>.view.layoutInspector</code> and have it implement
 <code>collectionView:constrainedSizeForNodeAtIndexPath:</code>.</li>
</ol>
</ol>

By default, the interop data source will only be consulted in cases where no `ASCellNode` is provided to AsyncDisplayKit. However, if <code>.dequeuesCellsForNodeBackedItems</code> is enabled, then the interop data source will always be consulted to dequeue cells, and will be expected to return <code>_ASCollectionViewCells</code> in cases where a node was provided.

## CustomCollectionView Example App

The [CustomCollectionView](https://github.com/facebook/AsyncDisplayKit/tree/master/examples/CustomCollectionView) example project demonstrates how to use raw `UIKit` cells alongside native `ASCellNodes`.

Open the app and verify that `kShowUICollectionViewCells` is enabled in `Sample/ViewController.m`. 

For this example, the data source method `collectionNode:nodeBlockForItemAtIndexPath:` is setup to return nil for every third cell. When nil is returned, `ASCollectionNode` will automatically query the `cellForItemAtIndexPath:` data source method. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode 
      nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (kShowUICollectionViewCells && indexPath.item % 3 == 1) {
    // When enabled, return nil for every third cell and then 
    // cellForItemAtIndexPath: will be called.
    return nil;
  }
  
  UIImage *image = _sections[indexPath.section][indexPath.item];
  return ^{
    return [[ImageCellNode alloc] initWithImage:image];
  };
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView 
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_collectionNode.view dequeueReusableCellWithReuseIdentifier:kReuseIdentifier 
                                                         forIndexPath:indexPath];
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  // Click the "Edit on GitHub" button at the bottom of this 
  // page to contribute the swift code for this section. Thanks!
  </pre>
</div>
</div>

Run the app to see the orange `UICollectionViewCells` interspersed every 3rd cell among the `ASCellNodes` containing images.


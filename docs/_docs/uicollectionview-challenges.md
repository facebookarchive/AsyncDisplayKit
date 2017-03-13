---
title: UICollectionView Challenges
layout: docs
permalink: /docs/uicollectionview-challenges.html
---

`UICollectionView` is one of the most commonly used classes and many challenges with iOS development are related to its architecture.

## How `UICollectionView` Works 

There are two important methods that `UICollectionView` requires. 

<h4><b>Cell Measurement</b></h4>

For each item in the data source, the collection must know its size to understand which items should be visible at a given momement. This is provided by:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (CGSize)collectionView:(UICollectionView *)collectionView 
                  layout:(UICollectionViewLayout *)collectionViewLayout 
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional func collectionView(_ collectionView: UICollectionView, 
                      layout collectionViewLayout: UICollectionViewLayout, 
               sizeForItemAt indexPath: IndexPath) -> CGSize
</pre>
</div>
</div>

Although not formally named by Apple, we refer to this process as "measuring". Implementing this method is always difficult, because the view that implements the cell layout is never available at the time of this method call. 

This means that logic must be duplicated between the implementation of this method and the `-layoutSubviews` implementation of the cell subclass. This presents a tremendous maintainence burden, as the implementations must always match their behavior for any combination of content displayed. 

Additionally, once measurement is complete, there's no easy way to cache that information to use it during the layout process. As a result, expensive text measurements must be repeated.  

<h4><b>Cell Allocation</b></h4>

Once an item reaches the screen, a view representing it is requested:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;
</pre>
<pre lang="swift" class = "swiftCode hidden">
func cellForItem(at indexPath: IndexPath) -> UICollectionViewCell?
</pre>
</div>
</div>

In order to provide a cell, all subviews must be configured with the data that they are intended to display. Immediately afterwards, the layout of the cell is calculated, and finally the display (rendering) of the individual elements (text, images) contained within. 

<div class = "note">
For those who are curious, this extremely detailed <a href="/static/talks/UICollectionView.pdf">diagram</a> shows the full process of <code>UICollectionView</code> communicating with its data source and delegate to display itself.
</div>

<h4><b>Limitations in `UICollectionView`'s Architecture</b></h4>

There are several issues with the architecture outlined above:

<b>Lots of main thread work</b>, which may <a href="">degrade</a> the user's experience, including

<ul>
<li>cell measurement</li>
<li>cell creation + setup / reuse </li>
<li>layout</li>
<li>display (rendering)</li></ul>

<b>Duplicated layout logic</b>

You must have duplicate copies of your cell sizing logic for the cell measurement and cell layout stages. For example, if you want to add a price tag to your cell, both <code>-sizeForItemAtIndexPath</code> and the cell's own <code>-layoutSubviews</code> must be aware of how to size the tag.

<b>No automatic content loading</b>

There is no easy, universal way to handle loading content such as:
<ul>
<li>data pages - such as JSON fetching</li>
<li>other info - such as images or secondary JSON requests</li>
</ul>

## How `ASCollectionNode` works

<h4><b>Unified Cell Measurement & Allocation</b></h4>

AsyncDisplayKit takes both of the important collection methods explained above:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;

- (CGSize)collectionView:(UICollectionView *)collectionView 
                  layout:(UICollectionViewLayout *)collectionViewLayout 
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
</pre>
<pre lang="swift" class = "swiftCode hidden">
optional func collectionView(_ collectionView: UICollectionView, 
                      layout collectionViewLayout: UICollectionViewLayout, 
               sizeForItemAt indexPath: IndexPath) -> CGSize

func cellForItem(at indexPath: IndexPath) -> UICollectionViewCell?
</pre>
</div>
</div>

and replaces them with a single method*:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForItemAtIndexPath:(NSIndexPath *)indexPath;
</pre>
<pre lang="swift" class = "swiftCode hidden">
func collectionNode(collectionNode: ASCollectionNode, nodeForItemAtIndexPath indexPath: NSIndexPath) -> ASCellNode
</pre>
</div>
</div>

or with the asynchronous versions

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>
<div class = "code">
<pre lang="objc" class="objcCode">
- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;
</pre>
<pre lang="swift" class = "swiftCode hidden">
func collectionNode(collectionNode: ASCollectionNode, nodeBlockForItemAtIndexPath indexPath: NSIndexPath) -> ASCellNodeBlock
</pre>
</div>
</div>

*Note that there is an optional method to provide a constrained size for the cell, but it is not needed by most apps.

<a href="/docs/cell-node.html"><code>ASCellNode</code></a>, is AsyncDisplayKit's universal cell class. They are light-weight enough to be created an an earlier time in the program (concurrently in the background) and they understand how to calculate their own size. `ASCellNode` automatically caches its measurement so that it can be quickly applied during the layout pass. 

<div class = "note">
As a comparison to the diagram above, this detailed <a href="/static/talks/ASCollectionView.pdf">diagram</a> shows the full process of an <code>ASCollectionView</code> communicating with its data source and delegate to display itself.. Note that <code>ASCollectionView</code> is <code>ASCollectionNode</code>'s underlying <code>UICollectionView</code> subclass. 
</div> 

<h4><b>Benefits of AsyncDisplayKit's Architecture</b></h4>

<b>Elimination of all of the types of main thread work</b> described above (cell allocation, measurement, layout, display)! In addition, all of this work is preformed <b>concurrently</b> on multiple threads.

Because `ASCollectionNode` is aware of the position of all of its nodes, it can <b>automatically determine when content loading is needed</b>. The <a href="/docs/batch-fetching-api.html">Batch Fetching API</a> handles loading of data pages (like JSON) and <a href="/docs/intelligent-preloading.html">Intelligent Preloading</a> automatically manages the loading of images and text. Additionally, convenient callbacks allow implementing accurate visibility logging and secondary data model requests.  

Lastly, almost all of the concepts we've discussed here apply to `UITableView` / `ASTableNode` and `UIPageViewController` / `ASPagerNode`.

## iOS 10 Cell Pre-fetching
Inspired by ASDK, iOS 10 introduced a <a href="">cell pre-fetching</a>. This API increases the number of cells that the collection tracks at any given time, which helps, but isn't anywhere as performance centric as being aware of all cells in the data source. 

Additionally, iOS9 still constitutes a substantial precentage of most app's userbase and will not reduce in number anywhere close to as quickly as the sunset trajectory of iOS 7 and iOS 8 devices. Whereas iOS 9 is the last supported version for about a half-dozen devices, there were zero devices that were deprecated on iOS 8 and only one deivce deprecated on iOS 7. 

Unfortunately, these iOS 9 devices are the ones in which performance is most key!

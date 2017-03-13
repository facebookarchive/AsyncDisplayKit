---
title: Node Subclasses
layout: docs
permalink: /docs/node-overview.html
prevPage: containers-overview.html
nextPage: subclassing.html
---

AsyncDisplayKit offers the following nodes.  

A key advantage of using nodes over UIKit components is that **all nodes preform layout and display off of the main thread**, so that the main thread is available to immediately respond to user interaction events.  

<table style="width:100%" class = "paddingBetweenCols">
  <tr>
    <th>ASDK Node</th>
    <th>UIKit Equivalent</th> 
  </tr>
  <tr>
    <td><a href = "display-node.html"><code>ASDisplayNode</code></a></td>
    <td>in place of UIKit's <code>UIView</code><br> 
        <i>The root AsyncDisplayKit node, from which all other nodes inherit.</i></td> 
  </tr>
  <tr>
    <td><a href = "cell-node.html"><code>ASCellNode</code></a></td>
    <td>in place of UIKit's <code>UITableViewCell</code> & <code>UICollectionViewCell</code><br>
        <i><code>ASCellNode</code>s are used in <code>ASTableNode</code>, <code>ASCollectionNode</code> and <code>ASPagerNode</code>.</i></td> 
  </tr>
  <tr>
    <td><a href = "scroll-node.html"><code>ASScrollNode</code></a></td>
    <td>in place of UIKit's <code>UIScrollView</code>
        <p><i>This node is useful for creating a customized scrollable region that contains other nodes.</i></p></td> 
  </tr>
  <tr>
    <td><a href = "editable-text-node.html"><code>ASEditableTextNode</code></a><br>
        <a href = "text-node.html"><code>ASTextNode</code></a></td>
    <td>in place of UIKit's <code>UITextView</code><br>
        in place of UIKit's <code>UILabel</code></td> 
  </tr>
  <tr>
    <td><a href = "image-node.html"><code>ASImageNode</code></a><br>
        <a href = "network-image-node.html"><code>ASNetworkImageNode</code></a><br>
        <a href = "multiplex-image-node.html"><code>ASMultiplexImageNode</code></a></td>
    <td>in place of UIKit's <code>UIImage</code></td> 
  </tr>
  <tr>
    <td><a href = "video-node.html"><code>ASVideoNode</code></a><br>
        <code>ASVideoPlayerNode</code></td>
    <td>in place of UIKit's <code>AVPlayerLayer</code><br>
        in place of UIKit's <code>UIMoviePlayer</code></td> 
  </tr>
  <tr>
    <td><a href = "control-node.html"><code>ASControlNode</code></a></td>
    <td>in place of UIKit's <code>UIControl</code></td>
  </tr>
  <tr>
    <td><a href = "button-node.html"><code>ASButtonNode</code></a></td>
    <td>in place of UIKit's <code>UIButton</code></td>
  </tr>
  <tr>
    <td><a href = "map-node.html"><code>ASMapNode</code></a></td>
    <td>in place of UIKit's <code>MKMapView</code></td>
  </tr>
</table>

<br>
Despite having rough equivalencies to UIKit components, in general, AsyncDisplayKit nodes offer more advanced features and conveniences. For example, an `ASNetworkImageNode` does automatic loading and cache management, and even supports progressive jpeg and animated gifs. 

The <a href = "https://github.com/facebook/AsyncDisplayKit/tree/master/examples/AsyncDisplayKitOverview">`AsyncDisplayKitOverview`</a> example app gives basic implementations of each of the nodes listed above. 
 

# Node Inheritance Hierarchy 

All AsyncDisplayKit nodes inherit from `ASDisplayNode`. 

<img src="/static/images/node-hierarchy.png" alt="node inheritance flowchart">

The nodes highlighted in blue are synchronous wrappers of UIKit elements.  For example, `ASScrollNode` wraps a `UIScrollView`, and `ASCollectionNode` wraps a `UICollectionView`.  An `ASMapNode` in `liveMapMode` is a synchronous wrapper of `UIMapView`.


 
 

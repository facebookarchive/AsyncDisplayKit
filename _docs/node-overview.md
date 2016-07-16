---
title: Node Subclasses
layout: docs
permalink: /docs/node-overview.html
prevPage: containers-aspagernode.html
nextPage: display-node.html
---

AsyncDisplayKit offers the following nodes.  A key advantage of using nodes over UIKit components is that **all nodes preform layout and display off of the main thread**, so that the main thread is available to immediately respond to user interaction events.  

The most common nodes include:

- <a href = "display-node.html">`ASDisplayNode`</a> in place of UIKit's `UIView`.  ASDisplayNode is the root AsyncDisplayKit node, from which all other nodes inherit.

- <a href = "cell-node.html">`ASCellNode`</a> (and the lighter-weight <a href = "text-cell-node.html">`ASTextCellNode`</a>) in place of UIKit's `UITableViewCell` and `UICollectionViewCell`.  ASCellNodes are used in `ASTableNode`, `ASCollectionNode` and `ASPagerNode`.

- <a href = "">`ASScrollNode`</a> in place of UIKit's `UIScrollView`.  This node is useful for creating a customized scrollable region that contains other nodes.

- <a href = "editable-text-node.html">`ASEditableTextNode`</a> in place of UIKit's `UITextView`

- <a href = "control-node.html">`ASControlNode`</a> in place of UIKit's `UIControl`

- <a href = "text-node.html">`ASTextNode`</a> in place of UIKit's `UILabel`

- <a href = "map-node.html">`ASMapNode`</a> in place of UIKit's `MKMapView`

- <a href = "button-node.html">`ASButtonNode`</a> in place of UIKit's `UIButton`

- <a href = "image-node.html">`ASImageNode`</a> in place of UIKit's `UIImageView`

- <a href = "video-node.html">`ASVideoNode`</a> in place of UIKit's `AVPlayerLayer`

- <a href = "">`ASVideoNodePlayer`</a> in place of UIKit's `UIMoviePlayer`

- <a href = "network-image-node.html">`ASNetworkImageNode`</a> 

- <a href = "multiplex-image-node.html">`ASMultiplexImageNode`</a> 

Despite having rough equivalencies to UIKit components, in general, AsyncDisplayKit nodes offer more advanced features and conveniences. For example, an ASNetworkImageNode does automatic loading and cache management, and even supports progressive jpeg and animated gifs. 

The <a href = "https://github.com/facebook/AsyncDisplayKit/tree/master/examples/AsyncDisplayKitOverview">`AsyncDisplayKitOverview`</a> example app gives basic implementations of each of the nodes listed above. 
 

# Node Inheritance Hierarchy 

All AsyncDisplayKit nodes inherit from `ASDisplayNode`.

Updates to the framework (not reflected in the chart below): 
<ul>
  <li>`ASVideoNode` now inherits from `ASNetworkImageNode`.</li>
  <li>`ASScrollNode` is now available. It inherits from `ASDisplayNode`.</li>
  <li>`ASCellNode` used by `ASTableNode`, `ASCollectionNode` and `ASPagerNode` inherits from `ASDisplayNode`.
</ul>
<img src="/static/images/node-hierarchy.PNG" alt="node inheritance flowchart">

The blue and green colored nodes are synchronous wrappers of UIKit elements.  For example, ASScrollNode wraps a UIScrollView and ASCollectionNode wraps a UICollectionView.  An ASMapNode in liveMapMode is a synchronous wrapper of UIMapView.


 
 

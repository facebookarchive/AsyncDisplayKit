---
title: Node Containers
layout: docs
permalink: /docs/containers-overview.html
prevPage: layout-engine.html
nextPage: containers-asviewcontroller.html
---

### Use Nodes in Node Containers
It is highly recommended that you use AsyncDisplayKit's nodes within a node container. AsyncDisplayKit offers the following node containers

- `ASViewController` in place of UIKit's `UIViewController`
- `ASCollectionNode` in place of UIKit's `UICollectionView`
- `ASPagerNode` in place of UIKit's `UIPageViewController`
- `ASTableNode` in place of UIKit's `UITableView`
 
Example code and specific sample projects are highlighted in the documentation for each node container. 

For a detailed description on porting an existing UIKit app to AsyncDisplayKit, read the <a href = "porting-guide.html">porting guide</a>.

### What do I Gain by Using a Node Container?

A node container automatically manages the <a href = "intelligent-preloading.html">intelligent preloading</a> of its nodes. This means that all of the node's layout measurement, data fetching, decoding and rendering will be done asynchronously. Among other conveniences, this is why it is reccomended to use nodes within a container node.

Note that while it _is_ possible to use nodes directly (without an AsyncDisplayKit node container), unless you add additional calls, they will only start displaying once they come onscreen (as UIKit does). This can lead to performance degredation and flashing of content.

---
title: Node Containers
layout: docs
permalink: /docs/containers-overview.html
prevPage: intelligent-preloading.html
nextPage: node-overview.html
---

### Use Nodes in Node Containers
It is highly recommended that you use AsyncDisplayKit's nodes within a node container. AsyncDisplayKit offers the following node containers.

<table style="width:100%" class = "paddingBetweenCols">
  <tr>
    <th>ASDK Node Container</th>
    <th>UIKit Equivalent</th> 
  </tr>
  <tr>
    <td><a href = "containers-ascollectionnode.html"><code>ASCollectionNode</code></a></td>
    <td>in place of UIKit's <code>UICollectionView</code></td>
  </tr>
  <tr>
    <td><a href = "containers-aspagernode.html"><code>ASPagerNode</code></a></td>
    <td>in place of UIKit's <code>UIPageViewController</code></td>
  </tr>
  <tr>
    <td><a href = "containers-astablenode.html"><code>ASTableNode</code></a></td>
    <td>in place of UIKit's <code>UITableView</code></td>
  </tr>
  <tr>
    <td><a href = "containers-asviewcontroller.html"><code>ASViewController</code></a></td>
    <td>in place of UIKit's <code>UIViewController</code></td>
  </tr>
  <tr>
    <td><code>ASNavigationController</code></td>
    <td>in place of UIKit's <code>UINavigationController</code>. Implements the <a href = "asvisibility.html"><code>ASVisibility</code></a> protocol.</td>
  </tr>
  <tr>
    <td><code>ASTabBarController</code></td>
    <td>in place of UIKit's <code>UITabBarController</code>. Implements the <a href = "asvisibility.html"><code>ASVisibility</code></a> protocol.</td>
  </tr>
</table>

<br>
Example code and specific sample projects are highlighted in the documentation for each node container. 

<!-- For a detailed description on porting an existing UIKit app to AsyncDisplayKit, read the <a href = "porting-guide.html">porting guide</a>. -->

### What do I Gain by Using a Node Container?

A node container automatically manages the <a href = "intelligent-preloading.html">intelligent preloading</a> of its nodes. This means that all of the node's layout measurement, data fetching, decoding and rendering will be done asynchronously. Among other conveniences, this is why it is reccomended to use nodes within a container node.

Note that while it _is_ possible to use nodes directly (without an AsyncDisplayKit node container), unless you add additional calls, they will only start displaying once they come onscreen (as UIKit does). This can lead to performance degredation and flashing of content.

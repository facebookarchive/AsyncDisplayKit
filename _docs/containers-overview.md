---
title: Containers Overview
layout: docs
permalink: /docs/containers-overview.html
next: containers-asviewcontroller.html
---

##Use Nodes in Node Containers##
It is highly recommended that you use AsyncDisplayKit's nodes within a node container. AsyncDisplayKit offers the following node containers

- `ASViewController` in place of UIKit's `UIViewController`
- `ASCollectioNode` in place of UIKit's `UICollectionView`
- `ASPagerNode` in place of UIKit's `UIPagerView`
- `ASTableNode` in place of UIKit's `UITableView`
 
Example code and specific sample projects are highlighted in the documentation for each node container. 

For a detailed description on porting an existing UIKit app to AsyncDisplayKit, read the <a href = "intelligent-preloading.html">porting guide</a>.

####What do I Gain by Using a Node Container?####

To optimize the performance of an app, AsyncDisplayKit uses <a href = "intelligent-preloading.html">intelligent preloading</a> to determine when content is likely to become visible on-screen. A node container automatically manages its nodes and coordinates with them to trigger layout measurement, fetching data and display and visibility. Each of these operations is triggered independently at an appropriate time, depeneding on how close the content is to coming on-screen. Among other conveniences, this is why it is reccomended to use nodes within a container node. 

In contrast, classes like UIViewController, UITableView, and UICollectionView (which can be thought of as view mamagers) perform the layout measurement, display and visibility operations instaneously, at the moment that the first pixel of their next viewController or cell becomes visible on-screen. This triggers a very large burst of main thread activity that is the cause of most app performance problems.

Note that it is possible to use nodes directly, without an AsyncDisplayKit node container, but unless you add additional calls, they will only start displaying once they come onscreen (as UIKit does). This can lead to performance degredation and flashing of content.



 

---
title: Containers Overview
layout: docs
permalink: /docs/containers-overview.html
next: containers-asviewcontroller.html
---

##Use Nodes in Node Containers##
For optimal performance, use nodes within a node container. ASDK offers the following node containers



####For the More Curious Developer...####

To optimize performance of an app, ASDK uses intelligent preloading to determine when content will become visible to a user. The node containers above asynchronously trigger data downloading, decoding and rendering of images and text before they reach the device's onscren display area. The node containers above manage all of this automatically for their subnodes.  For reference, UIKit does not render images or text before content comes on screen. 

It is possible to use nodes directly, without an ASDK container, but unless you add additional calls, they will only start displaying once they come onscreen, which can lead to performance degredation and flashing of content. 

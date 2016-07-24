---
title: Getting Started
layout: docs
permalink: /docs/getting-started.html
nextPage: resources.html
---

AsyncDisplayKit's basic unit is the `node`.  ASDisplayNode is an abstraction
over `UIView`, which in turn is an abstraction over `CALayer`.  Unlike views, which
can only be used on the main thread, nodes are thread-safe:  you can
instantiate and configure entire hierarchies of them in parallel on background
threads.

To keep its user interface smooth and responsive, your app should render at 60
frames per second &mdash; the gold standard on iOS.  This means the main thread
has one-sixtieth of a second to push each frame.  That's 16 milliseconds to
execute all layout and drawing code!  And because of system overhead, your code
usually has less than ten milliseconds to run before it causes a frame drop.

AsyncDisplayKit lets you move image decoding, text sizing and rendering, and
other expensive UI operations off the main thread, to keep the main thread available to 
respond to user interaction.  AsyncDisplayKit has other tricks up its
sleeve too... but we'll get to that later.

<h2><a href = "node-overview.html">Nodes</a></h2>

If you're used to working with views, you already know how to use nodes.  Most methods have a node equivalent and most `UIView` and `CALayer` properties are available as well.  In any case where there is a naming discrepancy (such as .clipsToBounds vs .masksToBounds), nodes will default to the UIView name.  The only exception is that nodes use position instead of center.

Of course, you can always access the underlying view or layer directly via <code>node.view</code> or <code>node.layer</code>, just make sure to do it on the main thread!

AsyncDisplayKit offers a <a href = "node-overview.html">variety of nodes</a> to replace the majority of the UIKit components that you are used to. Large scale apps have been able to completely write their UI using just AsyncDisplayKit nodes. 

<h2><a href = "containers-overview.html">Node Containers</a></h2>

When converting an app to use AsyncDisplayKit, a common mistake is to add nodes directly to an existing view hierarchy.  Doing this will virtually guarantee that your nodes will flash as they are rendered.  

Instead, you should add nodes as subnodes of one of the many <a href = "containers-overview.html">node container classes</a>.  These containeres are in charge of telling contained nodes what state they're currently in so that data can be loaded and nodes can be rendered as efficiently as possible.  You should think of these classes as the integration point between UIKit and ASDK.

<h2><a href = "/docs/layout-engine.html">Layout Engine</a></h2>

AsyncDisplayKit's layout engine is both one of its most powerful and one of its most unique features.  Based on the CSS FlexBox model, it provides a declarative way of specifying a custom node's size and layout of its subnodes.  While all nodes are concurrently rendered by default, asynchronous measurement and layout are performed by providing an ASLayoutSpec for each node.

<h2><a href = "/docs/layout-engine.html">Advanced Developer Features</a></h2>

AsyncDisplayKit offers a variety of advanced developer features that cannot be found in UIKit or Foundation.  Our developers have found that AsyncDisplyKit allows simplifications in their architecture and improves developer velocity. 

(Full list coming soon!)

<h2><a href = "/docs/layout-engine.html">Adding AsyncDisplayKit to your App</a></h2>

If you are new to AsyncDisplayKit, we reccomend that you check out our ASDKgram example app. We've created a handy guide (coming soon!) with step-by-step directions and a follow along example on how to add AsyncDisplayKit to an app. 

If you run into any problems along the way, reach out to us GitHub or the AsyncDisplayKit <a href = "/docs/resources.html#slack">Slack community</a> for help.

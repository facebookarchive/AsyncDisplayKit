---
title: Getting Started
layout: docs
permalink: /docs/getting-started.html
next: intelligent-preloading.html
---

AsyncDisplayKit's basic unit is the `node`.  ASDisplayNode is an abstraction
over UIView, which in turn is an abstraction over CALayer.  Unlike views, which
can only be used on the main thread, nodes are thread-safe:  you can
instantiate and configure entire hierarchies of them in parallel on background
threads.

To keep its user interface smooth and responsive, your app should render at 60
frames per second &mdash; the gold standard on iOS.  This means the main thread
has one-sixtieth of a second to push each frame.  That's 16 milliseconds to
execute all layout and drawing code!  And because of system overhead, your code
usually has less than ten milliseconds to run before it causes a frame drop.

AsyncDisplayKit lets you move image decoding, text sizing and rendering, and
other expensive UI operations off the main thread.  It has other tricks up its
sleeve too... but we'll get to that later.  :]

<h2><a href = "/docs/display-node.html">Nodes</a></h2>

If you're used to working with views, you already know how to use nodes.  Most methods have a node equivalent and most UIView and CALayer properties are available as well.  In any case where there is a naming discrepancy (such as .clipsToBounds vs .masksToBounds), nodes will default to the UIView name.  The only exception is that nodes use position instead of center.

Of course, you can always access the underlying view or layer directly via <code>node.view</code> or <code>node.layer</code>.

Some of AsyncDisplayKit's core nodes include:

<ul>
<li> <strong>ASDisplayNode</strong>.  Counterpart to UIView &mdash; subclass to make custom nodes.</li>
<li> <strong>ASCellNode</strong>.  Counterpart to UICollectionViewCell or UITableViewCell &mdash; subclass to make custom cells or initialize with a view controller.</li>
<li> <strong>ASControlNode</strong>.  Analogous to UIControl &mdash; subclass to make buttons.</li>
<li> <strong>ASImageNode</strong>.  Like UIImageView &mdash; decodes images asynchronously.</li>
<li> <strong>ASTextNode</strong>.  Like UITextView &mdash; built on TextKit with full-featured
rich text support.</li>
</ul>

<h2><a href = "/docs/asviewcontroller.html">Node Containers</a></h2>

When converting an app to use AsyncDisplayKit, a common mistake is to add nodes directly to an existing view hierarchy.  Doing this will virtually guarantee that your nodes will flash as they are rendered.  

Instead, you should add nodes as subnodes of one of the container classes.  These classes are in charge of telling contained nodes what state they're currently in so that data can be loaded and nodes can be rendered as efficiently as possible.  You should think of these classes as the integration point between UIKit and ASDK.

The four node containers are:

<ul>
<li> <strong>ASViewController</strong>.  A UIViewController subclass that allows you to provide the managed node.</li>
<li> <strong>ASCollectionNode</strong>.  Analogous to UICollectionView &mdash; manages a collection of ASCellNodes.</li>
<li> <strong>ASTableNode</strong>.  Analagous to UITableView &mdash; also uses ASCellNode but has with a fixed width.</li>
<li> <strong>ASPagerNode</strong>.  A specialized ASCollectionNode which can be used in the same way as a UIPageViewController.</li>
</ul>

<h2><a href = "/docs/layout-engine.html">Layout Engine</a></h2>

AsyncDisplayKit's layout engine is both one of its most powerful and one of its most unique features.  Based on the CSS FlexBox model, it provides a declarative way of specifying a custom node's size and layout of its subnodes.  While all nodes are concurrently rendered by default, asynchronous measurement and layout are performed by providing an ASLayoutSpec for each node.

The layout engine is based on the idea of ASLayouts which contain a position and size and ASLayoutSpecs which define various layouts conceptually and are used to output a calculated ASLayout.  Layout specs can be composed of both child nodes as well as other layout specs which 

A few layout specs:

<ul>
<li> <strong>ASLayoutSpec</strong>. Produces sizes and positions for its related node.</li>
<li> <strong>ASStackLayoutSpec</strong>.  Allows you to lay out nodes in a very similar way to UIStackView.</li>
<li> <strong>ASBackgroundLayoutSpec</strong>.  Set a background for a node.</li>
<li> <strong>ASStaticLayoutSpec</strong>.  Useful when you want to manually define a static size in which to contain a set of nodes.</li>
</ul>



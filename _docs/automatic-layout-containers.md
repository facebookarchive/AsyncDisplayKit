---
title: LayoutSpecs
layout: docs
permalink: /docs/automatic-layout-containers.html
prevPage: scroll-node.html
nextPage: layout-api-debugging.html 
---

AsyncDisplayKit includes a library of `layoutSpec` components that can be composed to declaratively specify a layout. 

The **child(ren) of a layoutSpec may be a node, a layoutSpec or a combination of the two types.**  In the below image, an ASStackLayoutSpec (vertical) containing a text node and an image node, is wrapped in another ASStackLayoutSpec (horizontal) with another text node. 

<img src="/static/images/layoutable-types.png">

Both nodes and layoutSpecs conform to the `<ASLayoutable>` protocol.  Any `ASLayoutable` object may be the child of a layoutSpec. <a href = "automatic-layout-containers.html#aslayoutable-properties">ASLayoutable properties</a> may be applied to ASLayoutable objects to create complex UI designs. 


### Single Child layoutSpecs

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>LayoutSpec</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b><code>ASInsetLayoutSpec</code></b></td>
    <td><p>Applies an inset margin around a component.</p> <p><i>The object that is being inset must have an intrinsic size.</i></p></td> 
  </tr>
    <tr>
    <td><b><code>ASOverlayLayoutSpec</code></b></td>
    <td><p>Lays out a component, stretching another component on top of it as an overlay.</p> <p><i>The underlay object must have an intrinsic size. Additionally, the order in which subnodes are added matters for this layoutSpec; the overlay object must be added as a subnode to the parent node after the underlay object.</i></p></td> 
  </tr>
  <tr>
    <td><b><code>ASBackgroundLayoutSpec</code></b></td>
    <td><p>Lays out a component, stretching another component behind it as a backdrop.</p> <p><i>The foreground object must have an intrinsic size. The order in which subnodes are added matters for this layoutSpec; the background object must be added as a subnode to the parent node before the foreground object.</i></p></td> 
  </tr>
  <tr>
    <td><b><code>ASCenterLayoutSpec</code></b></td>
    <td><p>Centers a component in the available space.</p> <p><i>The ASCenterLayoutSpec must have an intrinisic size.</i></p></td> 
  </tr>
  <tr>
    <td><b><code>ASRatioLayoutSpec</code></b></td>
    <td><p>Lays out a component at a fixed aspect ratio (which can be scaled).</p> <p><i>This spec is great for objects that do not have an intrinisic size, such as ASNetworkImageNodes and ASVideoNodes.</p> </td> 
  </tr>
  <tr>
    <td><b><code>ASRelativeLayoutSpec</code></b></td>
    <td><p>Lays out a component and positions it within the layout bounds according to vertical and horizontal positional specifiers. Similar to the “9-part” image areas, a child can be positioned at any of the 4 corners, or the middle of any of the 4 edges, as well as the center.</p> </td> 
  </tr>
  <tr>
    <td><b><code>ASLayoutSpec</code></b></td>
    <td><p>Can be used as a spacer in a stack spec with other children, when .flexGrow and/or .flexShrink is applied.</p> <p><i>This class can also be subclassed to create custom layout specs - advanced ASDK only!</i></p></td> 
  </tr>
</table> 

### Multiple Child(ren) layoutSpecs

The following layoutSpecs may contain one or more children. 

<table style="width:100%" class = "paddingBetweenCols">
  <tr>
    <th>LayoutSpec</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b><code>ASStackLayoutSpec</code></b></td>
    <td><p>Allows you to stack components vertically or horizontally and specify how they should be flexed and aligned to fit in the available space.</p> <p><b><i>This is the most common layoutSpec</i></b>.</p></td> 
  </tr>
  <tr>
    <td><b><code>ASStaticLayoutSpec</code></b></td>
    <td>Allows positioning children at fixed offsets using the <code>.sizeRange</code> and <code>.layoutPosition</code> ASLayoutable properties. </td> 
  </tr>
</table>

# ASLayoutable Properties

The following properties can be applied to both nodes _and_ layoutSpecs; both conform to the <ASLayoutable> protocol. 

### ASStackLayoutable Properties

The following properties may be set on any node or layoutSpecs, but will only apply to those who are a **child of a stack** layoutSpec.

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>Property</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b><code>CGFloat .spacingBefore</code></b></td>
    <td>Additional space to place before this object in the stacking direction.</td> 
  </tr>
  <tr>
    <td><b><code>CGFloat .spacingAfter</code></b></td>
    <td>Additional space to place after this object in the stacking direction.</td> 
  </tr>
  <tr>
    <td><b><code>BOOL .flexGrow</code></b></td>
    <td>If the sum of childrens' stack dimensions is less than the minimum size, should this object grow? Used when attached to a stack layout.</td> 
  </tr>
  <tr>
    <td><b><code>BOOL .flexShrink</code></b></td>
    <td>If the sum of childrens' stack dimensions is greater than the maximum size, should this object shrink? Used when attached to a stack layout.</td> 
  </tr>
  <tr>
    <td><b><code>ASRelativeDimension .flexBasis</code></b></td>
    <td>Specifies the initial size for this object, in the stack dimension (horizontal or vertical), before the flexGrow or flexShrink properties are applied and the remaining space is distributed.</td> 
  </tr>
  <tr>
    <td><b><code>ASStackLayoutAlignSelf alignSelf</code></b></td>
    <td>Orientation of the object along cross axis, overriding alignItems. Used when attached to a stack layout.</td> 
  </tr>
  <tr>
    <td><b><code>CGFloat .ascender</code></b></td>
    <td>Used for baseline alignment. The distance from the top of the object to its baseline./td> 
  </tr>
  <tr>
    <td><b><code>CGFloat .descender</code></b></td>
    <td>Used for baseline alignment. The distance from the baseline of the object to its bottom.</td> 
  </tr>
</table> 

### ASStaticLayoutable Properties

The following properties may be set on any node or layoutSpecs, but will only apply to those who are a **child of a static** layoutSpec.

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>Property</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b><code>.sizeRange</code></b></td>
    <td>If specified, the child's size is restricted according to this `ASRelativeSizeRange`. Percentages are resolved relative to the static layout spec.</td> 
  </tr>
  <tr>
    <td><b><code>.layoutPosition</code></b></td>
    <td>The `CGPoint` position of this object within its parent spec.</td> 
  </tr>
</table>

### Providing Intrinsic Sizes for Leaf Nodes

AsyncDisplayKit's layout is recursive, starting at the layoutSpec returned from `layoutSpecThatFits:` and proceeding down until it reaches the leaf nodes included in any nested layoutSpecs. 

Some leaf nodes provide their own intrinsic size, such as ASTextNode or ASImageNode. An attributed string or an image have their own sizes. Other leaf nodes require an intrinsic size to be set.

**Nodes that require the developer to provide an intrinsic size:**
<ul>
  <li>`ASDisplayNode` custom subclasses may provide their intrinisc size by implementing `calculateSizeThatFits:`.</li>
  <li>`ASNetworkImageNode` or `ASMultiplexImageNode` have no intrinsic size until the image is downloaded.</li>
  <li>`ASVideoNode` or `ASVideoNodePlayer` have no intrinsic size until the video is downloaded.</li>
</ul>

To provide an intrinisc size for these nodes, you can set one of the following:
<ol>
  <li>implement `calculateSizeThatFits:` for **custom ASDisplayNode subclasses** only.</li>
  <li>set `.preferredFrameSize`</li>
  <li>set `.sizeRange` for children of **static** nodes only.</li>
</ol>

Note that `.preferredFrameSize` is not considered by `ASTextNodes`. Also, setting .sizeRange on a node will override the node's intrinisic size provided by `calculateSizeThatFits:`. 

### Common Confusions

There are two main confusions that developers have when using layoutSpecs
<ol>
  <li>Certain ASLayoutable properties only apply to children of stack nodes, while other properties only apply to children of static nodes. All ASLayoutable properties can be applied to any node or layoutSpec, however certain properties will only take effect depending on the type of the parent layoutSpec they are wrapped in. These differences are highlighted above in the ASStackLayoutable Properties and ASStaticLayoutable Properties sections. </li>
  <li>Have I set an intrinsic size for all of my leaf nodes?</li>
</ol>

#### I set `.flexGrow` on my node, but it doesn't grow?

Upward propogation of ASLayoutable properties is currently disabled. Thus, in certain situations, the `.flexGrow` property must be manually applied to the containers. Two common examples of this that we see include:

<ul>
  <li>a node (with flexGrow enabled) is wrapped in a static layoutSpec, wrapped in a stack layoutSpec. <b>solution</b>: enable flexGrow on the static layotuSpec as well.</li>
  <li>a node (with flexGrow enabled) is wrapped in an inset spec. <b>solution</b>: enable flexGrow on the inset spec as well.</li>
</ul>

#### I want to provide a size for my image, but I don't want to hard code the size.

#### Why won't my stack spec span the full width? 

#### Difference between `ASInsetLayoutSpec` and `ASOverlayLayoutSpec`

An overlay spec requires the underlay object (object to which the overlay item will be applied) to have an intrinsic size. It will center the overlay object in the middle of this area. 

An inset spec requires its object to have an intrinsic size. It adds the inset padding to this size to calculate the final size of the inset spec. 

<img src="/static/images/overlay-vs-inset-spec.png">

### Best Practices
<ul>
  <li>AsyncDisplayKit layout is called on a background thread. Do not access the device screen bounds, or any other UIKit methods in `layoutSpecThatFits:`.</li>
  <li>don't wrap everything in a staticLayoutSpec?</li>
  <li>avoid using preferred frame size for everything - won't respond nicely to device rotation or device sizing differences?</li>
</ul>


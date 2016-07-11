---
title: LayoutSpecs
layout: docs
permalink: /docs/automatic-layout-containers.html
prevPage: automatic-layout-basics.html
nextPage: automatic-layout-examples.html 
---

AsyncDisplayKit includes a library of `layoutSpec` components that can be composed to declaratively specify a layout. The **child(ren) of a layoutSpec may be a node, a layoutSpec or a combination of the two types.**  

Both nodes and layoutSpecs conform to the `<ASLayoutable>` protocol.  Any `ASLayoutable` object may be the child of a layoutSpec. <a href = "automatic-layout-containers.html#layoutable-properties">ASLayoutable properties</a> may be applied to ASLayoutable objects to create complex UIs. 


### Single Child layoutSpecs

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>LayoutSpec</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b><code>ASInsetLayoutSpec</code></b></td>
    <td>applies an inset margin around a component. </td> 
  </tr>
  <tr>
    <td><b><code>ASRatioLayoutSpec</code></b></td>
    <td>lays out a component at a fixed aspect ratio (which can be scaled). Great for images, gifs and videos. </td> 
  </tr>
  <tr>
    <td><b><code>ASOverlayLayoutSpec</code></b></td>
    <td>lays out a component, stretching another component on top of it as an overlay. <b>The order in which subnodes are added matter for this layoutSpec</b>.</td> 
  </tr>
  <tr>
    <td><b><code>ASBackgroundLayoutSpec</code></b></td>
    <td>lays out a component, stretching another component behind it as a backdrop. <b>The order in which subnodes are added matter for this layoutSpec</b>.</td> 
  </tr>
  <tr>
    <td><b><code>ASCenterLayoutSpec</code></b></td>
    <td>centers a component in the available space. </td> 
  </tr>
  <tr>
    <td><b><code>ASRelativeLayoutSpec</code></b></td>
    <td>lays out a component and positions it within the layout bounds according to vertical and horizontal positional specifiers. Similar to the “9-part” image areas, a child can be positioned at any of the 4 corners, or the middle of any of the 4 edges, as well as the center. </td> 
  </tr>
  <tr>
    <td><b><code>ASLayoutSpec</code></b></td>
    <td>can be used as a spacer if it contains no child.</td> 
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
    <td>is based on a simplified version of CSS flexbox. It allows you to stack components vertically or horizontally and specify how they should be flexed and aligned to fit in the available space.</td> 
  </tr>
  <tr>
    <td><b><code>ASStackLayoutSpec</code></b></td>
    <td>is based on a simplified version of CSS flexbox. It allows you to stack components vertically or horizontally and specify how they should be flexed and aligned to fit in the available space. </td> 
  </tr>
  <tr>
    <td><b><code>ASStaticLayoutSpec</code></b></td>
    <td>allows positioning children at fixed offsets. </td> 
  </tr>
</table>

# ASLayoutable Properties

The following properties can be applied to both nodes _and_ layoutSpecs; both conform to the <ASLayoutable> protocol. 

### ASStackLayoutable Properties

The following properties will only apply to a child wrapped in an **stack** layoutSpec.

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

The following properties will only apply to a child wrapped in an **static** layoutSpec.

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

### Best Practices

<ul>
  <li>don't wrap everything in a staticLayoutSpec</li>
  <li>avoid using preferred frame size for everything - won't respond nicely to device rotation or device sizing differences</li>
</ul>


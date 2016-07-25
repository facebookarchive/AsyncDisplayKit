---
title: Layout Debugging
layout: docs
permalink: /docs/layout-api-debugging.html
prevPage: automatic-layout-containers.html
nextPage: layout-api-sizing.html
---

Here are some helpful questions to ask yourself when you encounter any issues composing layoutSpecs. 
 
## Am I the child of a Stack spec or a Static spec?
<br>
Certain `ASLayoutable` properties will _only_ apply when the layoutable is a child of a _stack_ node (also known as ASStackLayoutable), while other properties _only_ apply when the layoutable is a child of a _static_ node (also known as ASStaticLayoutable). 

- table of `ASStackLayoutables` [properties](http://asyncdisplaykit.org/docs/automatic-layout-containers.html#asstacklayoutable-properties)
- table of `ASStaticLayoutable` [properties](http://asyncdisplaykit.org/docs/automatic-layout-containers.html#asstaticlayoutable-properties)


All ASLayoutable properties can be applied to _any_ layoutable (e.g. any node or layout spec), however certain properties will only take effect depending on the type of the parent layout spec they are wrapped in.

## Have I provided sizes for any node that lacks an intrinsic size?
<br>
AsyncDisplayKit's layout pass is recursive, starting at the layoutSpec returned from -layoutSpecThatFits: and proceeding down until it reaches the leaf nodes included in any nested layoutSpecs.

Some leaf nodes have a concept of their own intrinsic size, such as ASTextNode or ASImageNode. A text node knows the length of its formatted string and an ASImageNode knows the size of its static image. Other leaf nodes require an intrinsic size to be set.

Nodes that require the developer to provide an intrinsic size:

- `ASNetworkImageNode` or `ASMultiplexImageNode` have no intrinsic size until the image is downloaded. **A size must be provided for either node.**
- `ASVideoNode` or `ASVideoNodePlayer` have no intrinsic size until the video is downloaded. **A size must be provided for either node.**
- `ASDisplayNode` custom subclasses may provide their intrinisc size by implementing `-calculateSizeThatFits:`.

To provide an intrinisc size for these nodes that lack intrinsic sizes (even if only momentarily), you can set one of the following:

- set `.preferredFrameSize` for children of stack or static specs.
- set `.sizeRange` for children of **static** specs only.
- implement `-calculateSizeThatFits:` for **custom ASDisplayNode subclasses only**.

*_Note that .preferredFrameSize is not considered by ASTextNodes. Also, setting .sizeRange on a node will override the node's intrinisic size provided by -calculateSizeThatFits:_

## Have I propogated selected `ASLayoutable` properties from an `ASLayoutable` object to its parent?
<br>
Upward and downward propogation of `ASLayoutable` properties between a child and its parent layoutSpec is currently disabled. This can be confusing, espcially for nodes in a single child layoutSpec. Depending on the desired UI, in certain cases, `ASLayoutable` properties must be manually set on the layout spec rather than its child.  

Make sure this is the layout effect that you actually desire. For layout specs with multiple children, such as a stack, setting flexShrink on the layout spec itself of course has a very different meaning than on one of the children.

Two common examples of this that we see include:

- A node with `.flexGrow` enabled is wrapped in an inset spec. "It" will not flexGrow. **Solution:** enable .flexGrow on the parent inset spec as well.
- A node with `.flexGrow` enabled is wrapped in a static layoutSpec, wrapped in a stack layoutSpec. **Solution:** enable .flexGrow on the static layoutSpec as well.

## When do I use `.preferredFrameSize` vs `.sizeRange`?
<br>
Set `.preferredFrameSize` to set a size for the child of any layout spec. Note that setting .preferredFrameSize on an `ASTextNode` will silently fail. We are working on fixing this, but in the meantime, you can wrap the ASTextNode in a static spec and provide it a .sizeRange.

If your `ASLayoutable` object (any node or layout spec) is the child of a *static* spec, then you may provide it a `.sizeRange`, consisting of a minimum and maximum constrained size. These sizes can be a specific point value or a relative value, like 70%. 

For details on the `.sizeRange` property's custom value type, check out our [Layout API Sizing guide](http://asyncdisplaykit.org/docs/layout-api-sizing.html). 

## `ASRelativeDimension` vs `ASRelativeSize` vs `ASRelativeSizeRange` vs `ASSizeRange`
<br>
AsyncDisplayKit's Layout API supports configuring node and layout spec sizes with specific point values as well as relative values. Read the [Layout API Sizing guide](http://asyncdisplaykit.org/docs/layout-api-sizing.html) for a helpful chart and documentation on our custom layout value types. 

## Debugging layout specs with ASCII art
<br>
Calling `-asciiArtString` on any `ASDisplayNode` or `ASLayoutSpec` returns an ascii-art representation of the object and its children. An example of a simple layoutSpec ascii-art console output can be seen below.

```
-----------------------ASStackLayoutSpec----------------------
|  -----ASStackLayoutSpec-----  -----ASStackLayoutSpec-----  |
|  |       ASImageNode       |  |       ASImageNode       |  |
|  |       ASImageNode       |  |       ASImageNode       |  |
|  ---------------------------  ---------------------------  |
--------------------------------------------------------------
 ```

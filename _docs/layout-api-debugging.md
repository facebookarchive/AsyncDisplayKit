---
title: Layout Debugging
layout: docs
permalink: /docs/layout-api-debugging.html
prevPage: automatic-layout-containers.html
nextPage: layout-api-sizing.html
---

Here are some helpful questions to ask yourself when you encounter any issues composing layoutSpecs. 
 
## Am I the child of an `ASStackLayoutSpec` or an `ASStaticLayoutSpec`?
<br>
Certain `ASLayoutable` properties will _only_ apply when the layoutable is a child of a _stack_ spec (the child is called an ASStackLayoutable), while other properties _only_ apply when the layoutable is a child of a _static_ spec (the child is called an ASStaticLayoutable). 

- table of [`ASStackLayoutables` properties](http://asyncdisplaykit.org/docs/automatic-layout-containers.html#asstacklayoutable-properties)
- table of [`ASStaticLayoutable` properties](http://asyncdisplaykit.org/docs/automatic-layout-containers.html#asstaticlayoutable-properties)

All ASLayoutable properties can be applied to _any_ layoutable (e.g. any node or layout spec), however certain properties will only take effect depending on the type of the parent layout spec they are wrapped in.

## Have I considered where to set `ASLayoutable` properties?
<br>
Let's say you have a node (`n1`) and you wrap it in a layout spec (`s1`). If you want to wrap the layout spec (`s1`) in a stack or static spec (`s2`), you will need to set all of the properties on the spec (`s1`) and not the node (`n1`).

A common examples of this confusion involves flex grow and flex shrink. E.g. a node with `.flexGrow` enabled is wrapped in an inset spec. The inset spec will not grow as we expect. **Solution:** enable `.flexGrow` on the inset spec as well.

## Have I provided sizes for any node that lacks an intrinsic size?
<br>
AsyncDisplayKit's layout pass is recursive, starting at the layout spec returned from `-layoutSpecThatFits:` and proceeding down until it reaches the leaf nodes included in any nested layout specs.

Some leaf nodes have a concept of their own intrinsic size, such as ASTextNode or ASImageNode. A text node knows the length of its formatted string and an ASImageNode knows the size of its static image. Other leaf nodes require an intrinsic size to be set.

Nodes that require the developer to provide an intrinsic size:

- `ASNetworkImageNode` or `ASMultiplexImageNode` have no intrinsic size until the image is downloaded. **A size must be provided for either node.**
- `ASVideoNode` or `ASVideoNodePlayer` have no intrinsic size until the video is downloaded. **A size must be provided for either node.**
- `ASDisplayNode` custom subclasses may provide their intrinisc size by implementing `-calculateSizeThatFits:`.

To provide an intrinisc size for these nodes that lack intrinsic sizes (even if only momentarily), you can set one of the following:

- set `.preferredFrameSize` on any node.
- set `.sizeRange` for children of **static** specs only.
- implement `-calculateSizeThatFits:` for **custom ASDisplayNode subclasses only**.

*_Note that .preferredFrameSize is not considered by ASTextNodes. Also, setting .sizeRange on a node will override the node's intrinisic size provided by -calculateSizeThatFits:_

## When do I use `.preferredFrameSize` vs `.sizeRange`?
<br>
Set `.preferredFrameSize` to set a size for any node. Note that setting .preferredFrameSize on an `ASTextNode` will silently fail. We are working on fixing this, but in the meantime, you can wrap the ASTextNode in a static spec and provide it a .sizeRange.

Set `.sizeRange` to set a size range for any node or layout spec that is the child of a *static* spec consisting. `.sizeRange` is the *only* way to set a size on a layout spec. Again, when using `.sizeRange`, you *must wrap the layoutable in a static layout spec for it to take effect.* 

A `.sizeRange` consists of a minimum and maximum constrained size (these sizes can be a specific point value or a relative value, like 70%). For details on the `.sizeRange` property's custom value type, check out our [Layout API Sizing guide](http://asyncdisplaykit.org/docs/layout-api-sizing.html). 

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

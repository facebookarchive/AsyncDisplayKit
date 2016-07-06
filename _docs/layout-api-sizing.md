---
title: Layout API Sizing
layout: docs
permalink: /docs/layout-api-sizing.html
---

##Question

"I don't think I have a clear understanding of `ASRelativeDimension` / `ASRelativeSizeRange`, and I often see many similar methods to create these structures."

##Answer

To best understand the compound dimension system in the Layout API, it is easiest to see all the units in relation to one another.

<img src="/static/layout-api-sizing-1.png">

## Values  (CGFloat, ASRelativeDimension)
<br>
`ASRelativeDimension` is essentially a normal **CGFloat with support for representing either a point value, or a % value**.  It allows the same API to take in both fixed values, as well as relative ones.  

ASRelativeDimension is used to set the `flexBasis` property on a child of an `ASStackLayoutSpec`.  The flexBasis property specifies the initial size in the stack dimension for this object, where the stack dimension is whether it is a horizontal or vertical stack.  

When a relative (%) value is used, it is resolved against the size of the parent.  For example, an item with 50% flexBasis will ultimately have a point value set on it at the time that the stack achieves a concrete size.

<div class = "note">
Note that .flexBasis can be set on any &ltASLayoutable&gt (a node, or a layout spec), but will only take effect if that element is added as a child of a <i>stack</i> layout spec. This container-dependence of layoutable properties is a key area we’re working on clarifying.
</div>

#### Constructing ASRelativeDimensions
<br>
`ASDimension.h` contains 3 convenience functions to construct an `ASRelativeDimension`.  It is easiest to use function that corresponds to the type (top 2 functions).

``` 
    ASRelativeDimensionMakeWithPoints(CGFloat points);
    ASRelativeDimensionMakeWithPercent(CGFloat percent);
    ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value);
```
#### ASRelativeDimension Example
<br>
`PIPlaceSingleDetailNode` uses flexBasis to set 2 child nodes of a horizontal stack to share the width 40 / 60:

```
    leftSideStack.flexBasis = ASRelativeDimensionMakeWithPercent(0.4f);
    self.detailLabel.flexBasis  = ASRelativeDimensionMakeWithPercent(0.6f);
    [horizontalStack setChildren:@[leftSideStack, self.detailLabel]];
```

<img src="/static/flexbasis.png" width="40%" height="40%">

## Sizes (CGSize,  ASRelativeSize)
<br>
`ASRelativeSize` is essentially a normal **CGSize with support for representing either a point size or a % size**.  ASRelativeSize doesn't have a direct use in the Layout API, except to construct an ASRelativeSizeRange.

- an ASRelativeSize consists of a width and height that are each `ASRelativeDimensions`. 

- percentage and point values can be combined (e.g. you could specify that an ASRelativeSize that has a height in points, but a variable % width)

#### Constructing ASRelativeSizes
<br>
`ASRelativeSize.h` contains 2 convenience functions to construct an `ASRelativeSize`.  If you don't need to support relative (%) values, you can construct a ASRelativeSize from a CGSize.

``` 
    ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height);
    ASRelativeSizeMakeWithCGSize(CGSize size);
```
## Size Ranges (ASSizeRange, ASRelativeSizeRange)

#### ASSizeRange
<br>
UIKit doesn't provide a structure to bundle a minimum and maximum CGSize.  So `ASSizeRange` was created to support **a minimum and maximum CGSize pair**. 

The `constrainedSize` that is passed as an input to `layoutSpecThatFits:` is an ASSizeRange. 

```
    - (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize;
```

#### ASRelativeSizeRange
<br>
Because the layout spec system allows flexibility with elements growing and shrinking, we sometimes need to provide limits / boundaries to its flexibility.  

`ASRelativeSizeRange` is essentially **a minimum and maximum size pair, that are used to constrain the size of a layout object.**  The minimum and maximum sizes must support both point and relative sizes, which is where our friend the ASRelativeSize comes in.  Hence, an ASRelativeSizeRange consists of a minimum and maximum `ASRelativeSize`. 

ASRelativeSizeRange is used to set the `sizeRange` property on a child of an `ASStaticLayoutSpec`.  If specified, the child's size is restricted according to this size.  

In the Pinterest code base, the **minimum size seems to be only necessary for stack specs in order to determine how much space to fill in between the children.**  For example, with buttons in a nav bar, we don’t want them to stack as closely together as they can fit — rather a minimum width, as wide as the screen, is specified and causes the stack to add spacing to satisfy that constraint.

**It’s much more common that the “max” constraint is what matters, though.**  This is the case when text is wrapping or truncating - it’s encountering the maximum allowed width.  Setting a minimum width for text doesn’t actually do anything—the text can’t be made longer—unless it’s in a stack, and spacing is added around it.

<div class = "note">
Note that .sizeRange can be set on any &ltASLayoutable&gt (a node, or a layout spec), but will only take effect if that element is added as a child of a <i>static</i> layout spec. This container-dependence of layoutable properties is a key area we’re working on clarifying.
</div>

#### ASSizeRange vs. ASRelativeSizeRange
<br>
Why do we use an `ASSizeRange` as a `constrainedSize` to pass to a node's `layoutSpecThatFits:` function, but an `ASRelativeSizeRange` to constrain the size of an element within the layoutSpecThatFits: function?

 It’s pretty rare that you need the percent feature for a .sizeRange feature, but it’s there to make the API as flexible as possible. The input value of the constrainedSize that comes into the argument, has already been resolved by the parent’s size. It may have been influenced by a percent type, but has always be converted by that point into points. 

#### Constructing ASRelativeSizeRange
<br>
`ASRelativeSize.h` contains 4 convenience functions to construct an `ASRelativeSizeRange` from the various smaller units.  

- Percentage and point values can be combined. E.g. you could specify that an object is a certain height in points, but a variable percentage width. 

- If you only care to constrain the min / max or width / height, you can pass in CGFLOAT_MIN, CGFLOAT_MAX, constrainedSize.max.width, etc

Most of the time, relative values are not needed for a size range _and_ the design requires an object to be forced to a particular size (min size = max size = no range). In this common case, you can use:

```
    ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact);
```

### Sizing Conclusion
<br>
Here we have our original table, which has been annotated to show the uses of the various units in the Layout API.

<img src="/static/layout-api-sizing-2.png">

It’s worth noting that that there’s a certain flexibility to be able to use so many powerful options with a single API - flexBasis and sizeRange can be used to set points and percentages in different directions. However, since the majority of do not use the full set of options, we should adjust the API so that the powerful capabilities are a slightly more hidden.


---
title: Upgrading to Layout 2.0 <b><i>(Beta)</i></b>
layout: docs
permalink: /docs/layout2-conversion-guide.html
---

A list of the changes:

- Introduction of true flex factors
- `ASStackLayoutSpec` `.alignItems` property default changed to `ASStackLayoutAlignItemsStretch`
- Rename `ASStaticLayoutSpec` to `ASAbsoluteLayoutSpec`
- Rename `ASLayoutable` to `ASLayoutElement`
- Set `ASLayoutElement` properties via `style` property
- Easier way to size of an `ASLayoutElement`
- Deprecation of `-[ASDisplayNode preferredFrameSize]`
- Deprecation of `-[ASLayoutElement measureWithSizeRange:]`
- Deprecation of `-[ASDisplayNode measure:]`
- Removal of `-[ASAbsoluteLayoutElement sizeRange]`
- Rename `ASRelativeDimension` to `ASDimension`
- Introduction of `ASDimensionUnitAuto`
 
In addition to the inline examples comparing **1.x** layout code vs **2.0** layout code, the [example projects](https://github.com/facebook/AsyncDisplayKit/tree/master/examples) and <a href = "layout2-quickstart.html">layout documentation</a> have been updated to use the new API.

All other **2.0** changes not related to the Layout API are documented <a href="adoption-guide-2-0-beta1.html">here</a>. 

## Introduction of true flex factors

With **1.x** the `flexGrow` and `flexShrink` properties were of type `BOOL`. 

With **2.0**, these properties are now type `CGFloat` with default values of `0.0`. 

This behavior is consistent with the Flexbox implementation for web. See [`flexGrow`](https://developer.mozilla.org/en-US/docs/Web/CSS/flex-grow) and [`flexShrink`](https://developer.mozilla.org/en-US/docs/Web/CSS/flex-shrink) for further information.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
id&lt;ASLayoutElement&gt; layoutElement = ...;

// 1.x:
layoutElement.flexGrow = YES;
layoutElement.flexShrink = YES;

// 2.0:
layoutElement.style.flexGrow = 1.0;
layoutElement.style.flexShrink = 1.0;
</pre>

<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## `ASStackLayoutSpec`'s `.alignItems` property default changed 

`ASStackLayoutSpec`'s `.alignItems` property default changed to `ASStackLayoutAlignItemsStretch` instead of `ASStackLayoutAlignItemsStart` to align with the CSS align-items property.

## Rename `ASStaticLayoutSpec` to `ASAbsoluteLayoutSpec` & behavior change

`ASStaticLayoutSpec` has been renamed to `ASAbsoluteLayoutSpec`, to be consistent with web terminology and better represent the intended behavior.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x:
ASStaticLayoutSpec *layoutSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[...]];

// 2.0:
ASAbsoluteLayoutSpec *layoutSpec = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[...]];
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

<br>
**Please note** that there has also been a behavior change introduced. The following text overlay layout was previously created using a `ASStaticLayoutSpec`, `ASInsetLayoutSpec` and `ASOverlayLayoutSpec` as seen in the code below. 

<img src="/static/images/layout-examples-photo-with-inset-text-overlay-diagram.png">

<br>
Using `INFINITY` for the `top` value in the `UIEdgeInsets` property of the `ASInsetLayoutSpec` allowed the text inset to start at the bottom. This was possible because it would adopt the size of the static layout spec's `_photoNode`.  

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _photoNode.preferredFrameSize = CGSizeMake(USER_IMAGE_HEIGHT*2, USER_IMAGE_HEIGHT*2);
  <b>ASStaticLayoutSpec</b> *backgroundImageStaticSpec = [<b>ASStaticLayoutSpec</b> staticLayoutSpecWithChildren:@[_photoNode]];

  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  <b>ASInsetLayoutSpec</b> *textInsetSpec = [<b>ASInsetLayoutSpec</b> insetLayoutSpecWithInsets:insets child:_titleNode];

  <b>ASOverlayLayoutSpec</b> *textOverlaySpec = [<b>ASOverlayLayoutSpec</b> overlayLayoutSpecWithChild:backgroundImageStaticSpec
                                                                                 overlay:textInsetSpec];
  
  return textOverlaySpec;
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>

<br>
With the new `ASAbsoluteLayoutSpec` and same code above, the layout would now look like the picture below. The text is still there, but at ~900 pts (offscreen).

<img src="/static/images/layout-examples-photo-with-inset-text-overlay-diagram.png">

## Rename `ASLayoutable` to `ASLayoutElement`

Remember that an `ASLayoutSpec` contains children that conform to the `ASLayoutElement` protocol. Both `ASDisplayNodes` and `ASLayoutSpecs` conform to this protocol. 

The protocol has remained the same as **1.x**, but the name has been changed to be more descriptive. 

## Set `ASLayoutElement` properties via `ASLayoutElementStyle`

An `ASLayoutElement`'s properties are are now set via it's `ASLayoutElementStyle` object.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
id&lt;ASLayoutElement&gt; *layoutElement = ...;

// 1.x:
layoutElement.spacingBefore = 1.0;

// 2.0:
layoutElement.style.spacingBefore = 1.0;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

However, the properties specific to an `ASLayoutSpec` are still set directly on the layout spec.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x and 2.0
ASStackLayoutSpec *stackLayoutSpec = ...;
stackLayoutSpec.direction = ASStackLayoutDirectionVertical;
stackLayoutSpec.justifyContent = ASStackLayoutJustifyContentStart;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Setting the size of an `ASLayoutElement`

With **2.0** we introduce a new, easier, way to set the size of an `ASLayoutElement`. These methods replace the deprecated `-preferredFrameSize` and `-sizeRange` **1.x** methods.

The following **optional** properties are provided via the layout element's `style` property:

- `-[ASLayoutElementStyle width]`: specifies the width of an ASLayoutElement. The `minWidth` and `maxWidth` properties will override `width`. The height will be set to Auto unless provided. 

- `-[ASLayoutElementStyle minWidth]`: specifies the minimum width of an ASLayoutElement. This prevents the used value of the `width` property from becoming smaller than the specified for `minWidth`.

- `-[ASLayoutElementStyle maxWidth]`: specifies the maximum width of an  ASLayoutElement. It prevents the used value of the `width` property from becoming larger than the specified for `maxWidth`.

- `-[ASLayoutElementStyle height]`: specifies the height of an ASLayoutElement. The `minHeight` and `maxHeight` properties will override `height`. The width will be set to Auto unless provided. 

- `-[ASLayoutElementStyle minHeight]`: specifies the minimum height of an ASLayoutElement. It prevents the used value of the `height` property from becoming smaller than the specified for `minHeight`.

- `-[ASLayoutElementStyle maxHeight]`: specifies the maximum height of an ASLayoutElement. It prevents the used value of the `height` property from becoming larger than the specified for `maxHeight`.

To set both the width and height with a `CGSize` value:

- `-[ASLayoutElementStyle preferredSize]`: Provides a suggested size for a layout element. If the optional minSize or maxSize are provided, and the preferredSize exceeds these, the minSize or maxSize will be enforced. If this optional value is not provided, the layout element’s size will default to it’s intrinsic content size provided calculateSizeThatFits:

- `-[ASLayoutElementStyle minSize]`: An optional property that provides a minimum size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s minimum size is smaller than its child’s minimum size, the child’s minimum size will be enforced and its size will extend out of the layout spec’s.

- `-[ASLayoutElementStyle maxSize]`: An optional property that provides a maximum size bound for a layout element. If provided, this restriction will always be enforced. If a child layout element’s maximum size is smaller than its parent, the child’s maximum size will be enforced and its size will extend out of the layout spec’s.
 
To set both the width and height with a relative (%) value (an `ASRelativeSize`):

- `-[ASLayoutElementStyle preferredRelativeSize]`: Provides a suggested RELATIVE size for a layout element. An ASRelativeSize uses percentages rather than points to specify layout. E.g. width should be 50% of the parent’s width. If the optional minRelativeSize or maxRelativeSize are provided, and the preferredRelativeSize exceeds these, the minRelativeSize or maxRelativeSize will be enforced. If this optional value is not provided, the layout element’s size will default to its intrinsic content size provided calculateSizeThatFits:

- `-[ASLayoutElementStyle minRelativeSize]`: An optional property that provides a minimum RELATIVE size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s minimum relative size is smaller than its child’s minimum relative size, the child’s minimum relative size will be enforced and its size will extend out of the layout spec’s.

- `-[ASLayoutElementStyle maxRelativeSize]`: An optional property that provides a maximum RELATIVE size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s maximum relative size is smaller than its child’s maximum relative size, the child’s maximum relative size will be enforced and its size will extend out of the layout spec’s.

For example, if you want to set a `width` of an `ASDisplayNode`:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x:
// no good way to set an intrinsic size

// 2.0:
ASDisplayNode *ASDisplayNode = ...;

// width 100 points, height: auto
displayNode.style.width = ASDimensionMakeWithPoints(100);

// width 50%, height: auto
displayNode.style.width = ASDimensionMakeWithFraction(0.5);

ASLayoutSpec *layoutSpec = ...;

// width 100 points, height 100 points
layoutSpec.style.preferredSize = CGSizeMake(100, 100);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

If you previously wrapped an `ASLayoutElement` with an `ASStaticLayoutSpec` just to give it a specific size (without setting the `layoutPosition` property on the element too), you don't have to do that anymore.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
ASStackLayoutSpec *stackLayoutSpec = ...;
id&lt;ASLayoutElement&gt; *layoutElement = ...;

// 1.x:
layoutElement.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(50, 50));
ASStaticLayoutSpec *staticLayoutSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[layoutElement]];
stackLayoutSpec.children = @[staticLayoutSpec];

// 2.0:
layoutElement.style.preferredSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(50, 50));
stackLayoutSpec.children = @[layoutElement];
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

If you previously wrapped a `ASLayoutElement` within a `ASStaticLayoutSpec` just to return any layout spec from within `layoutSpecThatFits:` there is a new layout spec now that is called `ASWrapperLayoutSpec`. `ASWrapperLayoutSpec` is an `ASLayoutSpec` subclass that can wrap a `ASLayoutElement` and calculates the layout of the child based on the size given to the `ASLayoutElement`:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x - ASStaticLayoutSpec used as a "wrapper" to return subnode from layoutSpecThatFits: 
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[subnode]];
}

// 2.0
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASWrapperLayoutSpec wrapperWithLayoutElement:subnode];
}

// 1.x - ASStaticLayoutSpec used to set size (but not position) of subnode
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *subnode = ...;
  subnode.preferredSize = ...;
  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[subnode]];
}

// 2.0
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *subnode = ...;
  subnode.style.preferredSize = CGSizeMake(constrainedSize.max.width, constrainedSize.max.height / 2.0);
  return [ASWrapperLayoutSpec wrapperWithLayoutElement:subnode];
}
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Deprecation of `-[ASDisplayNode preferredFrameSize]`

With the introduction of new sizing properties there is no need anymore for the `-[ASDisplayNode preferredFrameSize]` property. Therefore it is deprecated in **2.0**. Instead, use the size values on the `style` object of an `ASDisplayNode`:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode"> 
ASDisplayNode *ASDisplayNode = ...;

// 1.x:
displayNode.preferredFrameSize = CGSize(100, 100);

// 2.0
displayNode.style.preferredSize = CGSize(100, 100);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

`-[ASDisplayNode preferredFrameSize]` was not supported properly and was often more confusing than helpful. The new sizing methods should be easier and more clear to implment.

## Deprecation of `-[ASLayoutElement measureWithSizeRange:]`

`-[ASLayoutElement measureWithSizeRange:]` is deprecated in **2.0**.

#### Calling `measureWithSizeRange:`

If you previously called `-[ASLayoutElement measureWithSizeRange:]` to receive an `ASLayout`, call `-[ASLayoutElement layoutThatFits:]` now instead.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x:
ASLayout *layout = [layoutElement measureWithSizeRange:someSizeRange];

// 2.0:
ASLayout *layout = [layoutElement layoutThatFits:someSizeRange];
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

#### Implementing `measureWithSizeRange:`

If you are implementing a custom `class` that conforms to `ASLayoutElement` (e.g. creating a custom `ASLayoutSpec`) , replace `-measureWithSizeRange:` with `-calculateLayoutThatFits:`

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x:
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize {}

// 2.0:
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize {}
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

`-calculateLayoutThatFits:` takes an `ASSizeRange` that specifies a min size and a max size of type `CGSize`. Choose any size in the given range, to calculate the children's size and position and return a `ASLayout` structure with the layout of child components.

Besides `-calculateLayoutThatFits:` there are two additional methods on `ASLayoutElement` that you should know about if you are implementing classes that conform to `ASLayoutElement`:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

In certain advanced cases, you may want to override this method. Overriding this method allows you to receive the `layoutElement`'s size, parent size, and constrained size. With these values you could calculate the final constrained size and call `-calculateLayoutThatFits:` with the result.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
                  parentSize:(CGSize)parentSize;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

Call this on children`layoutElements` to compute their layouts within your implementation of `-calculateLayoutThatFits:`.

For sample implementations of layout specs and the usage of the `calculateLayoutThatFits:` family of methods, check out the layout specs in AsyncDisplayKit itself!

## Deprecation of `-[ASDisplayNode measure:]` 

Use `-[ASDisplayNode layoutThatFits:]` instead to get an `ASLayout` and call `size` on the returned `ASLayout`:

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 1.x:
CGSize size = [displayNode measure:CGSizeMake(100, 100)];

// 2.0:
ASLayout *layout = [displayNode layoutThatFits:ASSizeMake(CGSizeZero, CGSizeMake(100, 100))];
CGSize size = layout.size;
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Remove of `-[ASAbsoluteLayoutElement sizeRange]`

The `sizeRange` property was removed from the `ASAbsoluteLayoutElement` protocol. Instead set the one of the following:

- `-[ASLayoutElement width]`
- `-[ASLayoutElement height]`
- `-[ASLayoutElement minWidth]`
- `-[ASLayoutElement minHeight]`
- `-[ASLayoutElement maxWidth]`
- `-[ASLayoutElement maxHeight]`
 
<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
id&lt;ASLayoutElement&gt; layoutElement = ...;

// 1.x:
layoutElement.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(50, 50));

// 2.0:
layoutElement.style.preferredSizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(50, 50));
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

Due to the removal of `-[ASAbsoluteLayoutElement sizeRange]`, we also removed the `ASRelativeSizeRange`, as the type was no longer needed.

## Rename `ASRelativeDimension` to `ASDimension`

To simplify the naming and support the fact that dimensions are widely used in ASDK now, `ASRelativeDimension` was renamed to `ASDimension`. Having a shorter name and handy functions to create it was an important goal for us.

`ASRelativeDimensionTypePercent` and associated functions were renamed to use `Fraction` to be consistent with Apple terminology.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 2.0:
// Handy functions to create ASDimensions
ASDimension dimensionInPoints;
dimensionInPoints = ASDimensionMake(ASDimensionTypePoints, 5.0)
dimensionInPoints = ASDimensionMake(5.0)
dimensionInPoints = ASDimensionMakeWithPoints(5.0)
dimensionInPoints = ASDimensionMake("5.0pt");

ASDimension dimensionInFractions;
dimensionInFractions = ASDimensionMake(ASDimensionTypeFraction, 0.5)
dimensionInFractions = ASDimensionMakeWithFraction(0.5)
dimensionInFractions = ASDimensionMake("50%");
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>

## Introduction of `ASDimensionUnitAuto`

Previously `ASDimensionUnitPoints` and `ASDimensionUnitFraction` were the only two `ASDimensionUnit` enum values available. A new dimension type called `ASDimensionUnitAuto` now exists. All of the ``ASLayoutElementStyle` sizing properties are set to `ASDimensionAuto` by default.

`ASDimensionUnitAuto` means more or less: *"I have no opinion" and may be resolved in whatever way makes most sense given the circumstances.* 

Most of the time this is the intrinsic content size of the `ASLayoutElement`.

For example, if an `ASImageNode` has a `width` set to `ASDimensionUnitAuto`, the width of the linked image file will be used. For an `ASTextNode` the intrinsic content size will be calculated based on the text content. If an `ASLayoutElement` cannot provide any intrinsic content size like `ASVideoNode` for example the size needs to set explicitly.

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
// 2.0:
// No specific size needs to be set as the imageNode's size 
// will be calculated from the content (the image in this case)
ASImageNode *imageNode = [ASImageNode new];
imageNode.image = ...;

// Specific size must be set for ASLayoutElement objects that
// do not have an intrinsic content size (ASVideoNode does not
// have a size until it's video downloads)
ASVideoNode *videoNode = [ASVideoNode new];
videoNode.style.preferredSize = CGSizeMake(200, 100);
</pre>
<pre lang="swift" class = "swiftCode hidden">
</pre>
</div>
</div>


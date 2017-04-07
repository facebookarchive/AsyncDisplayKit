---
title: Layout Specs
layout: docs
permalink: /docs/layout2-layoutspec-types.html
prevPage: automatic-layout-examples-2.html
nextPage: layout2-layout-element-properties.html
---

The following `ASLayoutSpec` subclasses can be used to compose simple or very complex layouts. 

<ul>
<li><a href="layout2-layoutspec-types.html#aswrapperlayoutspec"><code>AS<b>Wrapper</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asstacklayoutspec-flexbox-container"><code>AS<b>Stack</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asinsetlayoutspec"><code>AS<b>Inset</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asoverlaylayoutspec"><code>AS<b>Overlay</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asbackgroundlayoutspec"><code>AS<b>Background</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#ascenterlayoutspec"><code>AS<b>Center</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asratiolayoutspec"><code>AS<b>Ratio</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asrelativelayoutspec"><code>AS<b>Relative</b>LayoutSpec</code></a></li>
<li><a href="layout2-layoutspec-types.html#asabsolutelayoutspec"><code>AS<b>Absolute</b>LayoutSpec</code></a></li>
</ul>

You may also subclass <a href="layout2-layoutspec-types.html#aslayoutspec">`ASLayoutSpec`</a> in order to make your own, custom layout specs. 

## ASWrapperLayoutSpec

`ASWrapperLayoutSpec` is a simple `ASLayoutSpec` subclass that can wrap a `ASLayoutElement` and calculate the layout of the child based on the size set on the layout element. 

`ASWrapperLayoutSpec` is ideal for easily returning a single subnode from `-layoutSpecThatFits:`. Optionally, this subnode can have sizing information set on it. However, if you need to set a position in addition to a size, use `ASAbsoluteLayoutSpec` instead.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
// return a single subnode from layoutSpecThatFits: 
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASWrapperLayoutSpec wrapperWithLayoutElement:_subnode];
}

// set a size (but not position)
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _subnode.style.preferredSize = CGSizeMake(constrainedSize.max.width,
                                            constrainedSize.max.height / 2.0);
  return [ASWrapperLayoutSpec wrapperWithLayoutElement:subnode];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
// return a single subnode from layoutSpecThatFits:
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec 
{
  return ASWrapperLayoutSpec(layoutElement: _subnode)
}

// set a size (but not position)
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec 
{
  _subnode.style.preferredSize = CGSize(width: constrainedSize.max.width,
                                        height: constrainedSize.max.height / 2.0)
  return ASWrapperLayoutSpec(layoutElement: _subnode)
}
</pre>
</div>
</div>

## ASStackLayoutSpec (Flexbox Container)
Of all the layoutSpecs in ASDK, `ASStackLayoutSpec` is the most useful and powerful. `ASStackLayoutSpec` uses the flexbox algorithm to determine the position and size of its children. Flexbox is designed to provide a consistent layout on different screen sizes. In a stack layout you align items in either a vertical or horizontal stack. A stack layout can be a child of another stack layout, which makes it possible to create almost any layout using a stack layout spec. 

`ASStackLayoutSpec` has 7 properties in addition to its `<ASLayoutElement>` properties:

- `direction`. Specifies the direction children are stacked in. If horizontalAlignment and verticalAlignment were set, 
they will be resolved again, causing justifyContent and alignItems to be updated accordingly.
- `spacing`. The amount of space between each child.
- `horizontalAlignment`. Specifies how children are aligned horizontally. Depends on the stack direction, setting the alignment causes either
 justifyContent or alignItems to be updated. The alignment will remain valid after future direction changes.
 Thus, it is preferred to those properties.
- `verticalAlignment`. Specifies how children are aligned vertically. Depends on the stack direction, setting the alignment causes either
 justifyContent or alignItems to be updated. The alignment will remain valid after future direction changes.
 Thus, it is preferred to those properties.
- `justifyContent`. The amount of space between each child.
- `alignItems`. Orientation of children along cross axis.
- `flexWrap`. Whether children are stacked into a single or multiple lines. Defaults to single line.
- `alignContent`. Orientation of lines along cross axis if there are multiple lines.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *mainStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                       spacing:6.0
                justifyContent:ASStackLayoutJustifyContentStart
                    alignItems:ASStackLayoutAlignItemsCenter
                      children:@[_iconNode, _countNode]];

  // Set some constrained size to the stack
  mainStack.style.minWidth = ASDimensionMakeWithPoints(60.0);
  mainStack.style.maxHeight = ASDimensionMakeWithPoints(40.0);

  return mainStack;
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec 
{
  let mainStack = ASStackLayoutSpec(direction: .horizontal,
                                    spacing: 6.0,
                                    justifyContent: .start,
                                    alignItems: .center,
                                    children: [titleNode, subtitleNode])

  // Set some constrained size to the stack
  mainStack.style.minWidth = ASDimensionMakeWithPoints(60.0)
  mainStack.style.maxHeight = ASDimensionMakeWithPoints(40.0)

  return mainStack
}
</pre>
</div>
</div>

Flexbox works the same way in AsyncDisplayKit as it does in CSS on the web, with a few exceptions. For example, the defaults are different and there is no `flex` parameter. See <a href = "layout2-web-flexbox-differences.html">Web Flexbox Differences</a> for more information.

<br>

## ASInsetLayoutSpec
During the layout pass, the `ASInsetLayoutSpec` passes its `constrainedSize.max` `CGSize` to its child, after subtracting its insets. Once the child determines it's final size, the inset spec passes its final size up as the size of its child plus its inset margin. Since the inset layout spec is sized based on the size of it's child, the child **must** have an instrinsic size or explicitly set its size. 

<img src="/static/images/layoutSpec-types/ASInsetLayoutSpec-diagram.png" width="75%">

If you set `INFINITY` as a value in the `UIEdgeInsets`, the inset spec will just use the intrinisic size of the child. See an <a href="automatic-layout-examples-2.html#photo-with-inset-text-overlay">example</a> of this.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  UIEdgeInsets *insets = UIEdgeInsetsMake(10, 10, 10, 10);
  ASInsetLayoutSpec *headerWithInset = insetLayoutSpecWithInsets:insets child:textNode];
  ...
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  ...
  let insets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
  let headerWithInset = ASInsetLayoutSpec(insets: insets, child: textNode)
  ...
}
</pre>
</div>
</div>

## ASOverlayLayoutSpec
`ASOverlayLayoutSpec` lays out its child (blue), stretching another component on top of it as an overlay (red). 

<img src="/static/images/layoutSpec-types/ASOverlayLayouSpec-diagram.png" width="65%">

The overlay spec's size is calculated from the child's size. In the diagram below, the child is the blue layer. The child's size is then passed as the `constrainedSize` to the overlay layout element (red layer). Thus, it is important that the child (blue layer) **must** have an intrinsic size or a size set on it. 

<div class = "note">
When using Automatic Subnode Management with the <code>ASOverlayLayoutSpec</code>, the nodes may sometimes appear in the wrong order. This is a known issue that will be fixed soon. The current workaround is to add the nodes manually, with the overlay layout element (red) must added as a subnode to the parent node after the child layout element (blue).
</div>

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:backgroundNode overlay:foregroundNode];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  let backgroundNode = ASDisplayNodeWithBackgroundColor(UIColor.blue)
  let foregroundNode = ASDisplayNodeWithBackgroundColor(UIColor.red)
  return ASOverlayLayoutSpec(child: backgroundNode, overlay: foregroundNode)
}
</pre>
</div>
</div>

## ASBackgroundLayoutSpec
`ASBackgroundLayoutSpec` lays out a component (blue), stretching another component behind it as a backdrop (red). 

<img src="/static/images/layoutSpec-types/ASBackgroundLayoutSpec-diagram.png" width="65%">

The background spec's size is calculated from the child's size. In the diagram below, the child is the blue layer. The child's size is then passed as the `constrainedSize` to the background layout element (red layer). Thus, it is important that the child (blue layer) **must** have an intrinsic size or a size set on it. 

<div class = "note">
When using Automatic Subnode Management with the <code>ASOverlayLayoutSpec</code>, the nodes may sometimes appear in the wrong order. This is a known issue that will be fixed soon. The current workaround is to add the nodes manually, with the child layout element (blue) must added as a subnode to the parent node after the child background element (red).
</div>

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);

  return [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:foregroundNode background:backgroundNode];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  let backgroundNode = ASDisplayNodeWithBackgroundColor(UIColor.blue)
  let foregroundNode = ASDisplayNodeWithBackgroundColor(UIColor.red)

  return ASBackgroundLayoutSpec(child: foregroundNode, background: backgroundNode)
}
</pre>
</div>
</div>

Note: The order in which subnodes are added matters for this layout spec; the background object must be added as a subnode to the parent node before the foreground object. Using ASM does not currently guarantee this order!

## ASCenterLayoutSpec
`ASCenterLayoutSpec` centers its child within its max `constrainedSize`. 

<img src="/static/images/layoutSpec-types/ASCenterLayoutSpec-diagram.png" width="65%">

If the center spec's width or height is unconstrained, it shrinks to the size of the child.

`ASCenterLayoutSpec` has two properties:

- `centeringOptions`. Determines how the child is centered within the center spec. Options include: None, X, Y, XY.
- `sizingOptions`. Determines how much space the center spec will take up. Options include: Default, minimum X, minimum Y, minimum XY.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(70, 100));
  return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
                                                    sizingOptions:ASRelativeLayoutSpecSizingOptionDefault
                                                            child:subnode]
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  let subnode = ASDisplayNodeWithBackgroundColor(UIColor.green, CGSize(width: 60.0, height: 100.0))
  let centerSpec = ASCenterLayoutSpec(centeringOptions: .XY, sizingOptions: [], child: subnode)
  return centerSpec
}
</pre>
</div>
</div>

## ASRatioLayoutSpec
`ASRatioLayoutSpec` lays out a component at a fixed aspect ratio which can scale. This spec **must** have a width or a height passed to it as a constrainedSize as it uses this value to scale itself. 

<img src="/static/images/layoutSpec-types/ASRatioLayoutSpec-diagram.png" width="65%">

It is very common to use a ratio spec to provide an intrinsic size for `ASNetworkImageNode` or `ASVideoNode`, as both do not have an intrinsic size until the content returns from the server. 

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // Half Ratio
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(100, 100));
  return [ASRatioLayoutSpec ratioLayoutSpecWithRatio:0.5 child:subnode];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  // Half Ratio
  let subnode = ASDisplayNodeWithBackgroundColor(UIColor.green, CGSize(width: 100, height: 100.0))
  let ratioSpec = ASRatioLayoutSpec(ratio: 0.5, child: subnode)
  return ratioSpec
}
</pre>
</div>
</div>

## ASRelativeLayoutSpec
Lays out a component and positions it within the layout bounds according to vertical and horizontal positional specifiers. Similar to the “9-part” image areas, a child can be positioned at any of the 4 corners, or the middle of any of the 4 edges, as well as the center.

This is a very powerful class, but too complex to cover in this overview. For more information, look into `ASRelativeLayoutSpec`'s `-calculateLayoutThatFits:` method + properties.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(70, 100));

  ASRelativeLayoutSpec *relativeSpec = [ASRelativeLayoutSpec relativePositionLayoutSpecWithHorizontalPosition:ASRelativeLayoutSpecPositionStart
                                  verticalPosition:ASRelativeLayoutSpecPositionStart
                                      sizingOption:ASRelativeLayoutSpecSizingOptionDefault
                                             child:foregroundNode]

  ASBackgroundLayoutSpec *backgroundSpec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:relativeSpec background:backgroundNode];
  ...
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  ...
  let backgroundNode = ASDisplayNodeWithBackgroundColor(UIColor.blue)
  let foregroundNode = ASDisplayNodeWithBackgroundColor(UIColor.red, CGSize(width: 70.0, height: 100.0))

  let relativeSpec = ASRelativeLayoutSpec(horizontalPosition: .start,
                                          verticalPosition: .start,
                                          sizingOption: [],
                                          child: foregroundNode)

  let backgroundSpec = ASBackgroundLayoutSpec(child: relativeSpec, background: backgroundNode)
  ...
}
</pre>
</div>
</div>

## ASAbsoluteLayoutSpec
Within `ASAbsoluteLayoutSpec` you can specify exact locations (x/y coordinates) of its children by setting their `layoutPosition` property. Absolute layouts are less flexible and harder to maintain than other types of layouts.

`ASAbsoluteLayoutSpec` has one property:

- `sizing`. Determines how much space the absolute spec will take up. Options include: Default, and Size to Fit. *Note* that the Size to Fit option will replicate the behavior of the old `ASStaticLayoutSpec`.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGSize maxConstrainedSize = constrainedSize.max;

  // Layout all nodes absolute in a static layout spec
  guitarVideoNode.layoutPosition = CGPointMake(0, 0);
  guitarVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width, maxConstrainedSize.height / 3.0));

  nicCageVideoNode.layoutPosition = CGPointMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0);
  nicCageVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0));

  simonVideoNode.layoutPosition = CGPointMake(0.0, maxConstrainedSize.height - (maxConstrainedSize.height / 3.0));
  simonVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width/2, maxConstrainedSize.height / 3.0));

  hlsVideoNode.layoutPosition = CGPointMake(0.0, maxConstrainedSize.height / 3.0);
  hlsVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0));

  return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[guitarVideoNode, nicCageVideoNode, simonVideoNode, hlsVideoNode]];
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  let maxConstrainedSize = constrainedSize.max

  // Layout all nodes absolute in a static layout spec
  guitarVideoNode.style.layoutPosition = CGPoint.zero
  guitarVideoNode.style.preferredSize = CGSize(width: maxConstrainedSize.width, height: maxConstrainedSize.height / 3.0)

  nicCageVideoNode.style.layoutPosition = CGPoint(x: maxConstrainedSize.width / 2.0, y: maxConstrainedSize.height / 3.0)
  nicCageVideoNode.style.preferredSize = CGSize(width: maxConstrainedSize.width / 2.0, height: maxConstrainedSize.height / 3.0)

  simonVideoNode.style.layoutPosition = CGPoint(x: 0.0, y: maxConstrainedSize.height - (maxConstrainedSize.height / 3.0))
  simonVideoNode.style.preferredSize = CGSize(width: maxConstrainedSize.width / 2.0, height: maxConstrainedSize.height / 3.0)

  hlsVideoNode.style.layoutPosition = CGPoint(x: 0.0, y: maxConstrainedSize.height / 3.0)
  hlsVideoNode.style.preferredSize = CGSize(width: maxConstrainedSize.width / 2.0, height: maxConstrainedSize.height / 3.0)

  return ASAbsoluteLayoutSpec(children: [guitarVideoNode, nicCageVideoNode, simonVideoNode, hlsVideoNode])
}
</pre>
</div>
</div>

## ASLayoutSpec
`ASLayoutSpec` is the main class from that all layout spec's are subclassed. It's main job is to handle all the children management, but it also can be used to create custom layout specs. Only the super advanced should want / need to create a custom subclasses of `ASLayoutSpec` though. Instead try to use provided layout specs and compose them together to create more advanced layouts.

Another use of `ASLayoutSpec` is to be used as a spacer in a `ASStackLayoutSpec` with other children, when `.flexGrow` and/or `.flexShrink` is applied.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  // ASLayoutSpec as spacer
  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = true;

  stack.children = @[imageNode, spacer, textNode];
  ...
}
</pre>

<pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec
{
  ...
  let spacer = ASLayoutSpec()
  spacer.style.flexGrow = 1.0

  stack.children = [imageNode, spacer, textNode]
  ...
}
</pre>
</div>
</div>

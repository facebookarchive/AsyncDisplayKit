---
title: Layout Examples
layout: docs
permalink: /docs/automatic-layout-examples-2.html
prevPage: layout2-quickstart.html
nextPage: layout2-layoutspec-types.html
---

Check out the layout specs <a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/LayoutSpecExamples">example project</a> to play around with the code below. 

## Simple Header with Left and Right Justified Text

<img src="/static/images/layout-examples-simple-header-with-left-right-justified-text.png">

To create this layout, we will use a:

- a vertical `ASStackLayoutSpec`
- a horizontal `ASStackLayoutSpec`
- `ASInsetLayoutSpec` to inset the entire header

The diagram below shows the composition of the layout elements (nodes + layout specs). 

<img src="/static/images/layout-examples-simple-header-with-left-right-justified-text-diagram.png">

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // when the username / location text is too long, 
  // shrink the stack to fit onscreen rather than push content to the right, offscreen
  ASStackLayoutSpec *nameLocationStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  nameLocationStack.style.flexShrink = 1.0;
  nameLocationStack.style.flexGrow = 1.0;
  
  // if fetching post location data from server, 
  // check if it is available yet and include it if so
  if (_postLocationNode.attributedText) {
    nameLocationStack.children = @[_usernameNode, _postLocationNode];
  } else {
    nameLocationStack.children = @[_usernameNode];
  }
  
  // horizontal stack
  ASStackLayoutSpec *headerStackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                               spacing:40
                                                                        justifyContent:ASStackLayoutJustifyContentStart
                                                                            alignItems:ASStackLayoutAlignItemsCenter
                                                                              children:@[nameLocationStack, _postTimeNode]];
  
  // inset the horizontal stack
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, 10, 0, 10) child:headerStackSpec];
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
  let nameLocationStack = ASStackLayoutSpec.vertical()
  nameLocationStack.style.flexShrink = 1.0
  nameLocationStack.style.flexGrow = 1.0

  if postLocationNode.attributedText != nil {
    nameLocationStack.children = [userNameNode, postLocationNode]
  } else {
    nameLocationStack.children = [userNameNode]
  }

  let headerStackSpec = ASStackLayoutSpec(direction: .horizontal,
                                          spacing: 40,
                                          justifyContent: .start,
                                          alignItems: .center,
                                          children: [nameLocationStack, postTimeNode])

  return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10), child: headerStackSpec)
}
  </pre>
</div>
</div>

Rotate the example project from portrait to landscape to see how the spacer grows and shrinks.

## Photo with Inset Text Overlay

<img src="/static/images/layout-examples-photo-with-inset-text-overlay.png">

To create this layout, we will use a:

- `ASInsetLayoutSpec` to inset the text
- `ASOverlayLayoutSpec` to overlay the inset text spec on top of the photo

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _photoNode.style.preferredSize = CGSizeMake(USER_IMAGE_HEIGHT*2, USER_IMAGE_HEIGHT*2);

  // INIFINITY is used to make the inset unbounded
  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  ASInsetLayoutSpec *textInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_titleNode];
  
  return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_photoNode overlay:textInsetSpec];
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
  let photoDimension: CGFloat = constrainedSize.max.width / 4.0
  photoNode.style.preferredSize = CGSize(width: photoDimension, height: photoDimension)

  // INFINITY is used to make the inset unbounded
  let insets = UIEdgeInsets(top: CGFloat.infinity, left: 12, bottom: 12, right: 12)
  let textInsetSpec = ASInsetLayoutSpec(insets: insets, child: titleNode)

  return ASOverlayLayoutSpec(child: photoNode, overlay: textInsetSpec)
}
  </pre>
</div>
</div>

## Photo with Outset Icon Overlay

<img src="/static/images/layout-examples-photo-with-outset-icon-overlay.png">

To create this layout, we will use a:

- `ASAbsoluteLayoutSpec` to place the photo and icon which have been individually sized and positioned using their `ASLayoutable` properties

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _iconNode.style.preferredSize = CGSizeMake(40, 40);
  _iconNode.style.layoutPosition = CGPointMake(150, 0);
  
  _photoNode.style.preferredSize = CGSizeMake(150, 150);
  _photoNode.style.layoutPosition = CGPointMake(40 / 2.0, 40 / 2.0);
  
  return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithSizing:ASAbsoluteLayoutSpecSizingSizeToFit
                                                   children:@[_photoNode, _iconNode]];
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
  iconNode.style.preferredSize = CGSize(width: 40, height: 40);
  iconNode.style.layoutPosition = CGPoint(x: 150, y: 0);

  photoNode.style.preferredSize = CGSize(width: 150, height: 150);
  photoNode.style.layoutPosition = CGPoint(x: 40 / 2.0, y: 40 / 2.0);

  let absoluteSpec = ASAbsoluteLayoutSpec(children: [photoNode, iconNode])

  // ASAbsoluteLayoutSpec's .sizing property recreates the behavior of ASDK Layout API 1.0's "ASStaticLayoutSpec"
  absoluteSpec.sizing = .sizeToFit

  return absoluteSpec;
}
  </pre>
</div>
</div>



## Simple Inset Text Cell

<img src="/static/images/layout-examples-simple-inset-text-cell.png" width="40%">

To recreate the layout of a <i>single cell</i> as is used in Pinterest's search view above, we will use a:

- `ASInsetLayoutSpec` to inset the text
- `ASCenterLayoutSpec` to center the text according to the specified properties

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 12, 4, 4);
    ASInsetLayoutSpec *inset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets
                                                                      child:_titleNode];

    return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringY
                                                      sizingOptions:ASCenterLayoutSpecSizingOptionMinimumX
                                                              child:inset];
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
    let insets = UIEdgeInsets(top: 0, left: 12, bottom: 4, right: 4)
    let inset = ASInsetLayoutSpec(insets: insets, child: _titleNode)
        
    return ASCenterLayoutSpec(centeringOptions: .Y, sizingOptions: .minimumX, child: inset)
}
  </pre>
</div>
</div>

## Top and Bottom Separator Lines

<img src="/static/images/layout-examples-top-bottom-separator-line.png">

To create the layout above, we will use a:

- a `ASInsetLayoutSpec` to inset the text
- a vertical `ASStackLayoutSpec` to stack the two separator lines on the top and bottom of the text

The diagram below shows the composition of the layoutables (layout specs + nodes). 

<img src="/static/images/layout-examples-top-bottom-separator-line-diagram.png">

The following code can also be found in the `ASLayoutSpecPlayground` [example project]().

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>
<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _topSeparator.style.flexGrow = 1.0;
  _bottomSeparator.style.flexGrow = 1.0;

  ASInsetLayoutSpec *insetContentSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(20, 20, 20, 20) child:_textNode];

  return [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                 spacing:0
                                          justifyContent:ASStackLayoutJustifyContentCenter
                                              alignItems:ASStackLayoutAlignItemsStretch
                                                children:@[_topSeparator, insetContentSpec, _bottomSeparator]];
}
  </pre>
  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
  topSeparator.style.flexGrow = 1.0
  bottomSeparator.style.flexGrow = 1.0
  textNode.style.alignSelf = .center

  let verticalStackSpec = ASStackLayoutSpec.vertical()
  verticalStackSpec.spacing = 20
  verticalStackSpec.justifyContent = .center
  verticalStackSpec.children = [topSeparator, textNode, bottomSeparator]

  return ASInsetLayoutSpec(insets:UIEdgeInsets(top: 60, left: 0, bottom: 60, right: 0), child: verticalStackSpec)
}
  </pre>
</div>
</div>

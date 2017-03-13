---
title: Composing Layout Specs
layout: docs
permalink: /docs/layout2-layoutSpecThatFits.html
---

The composing of layout specs and layoutables are happening within the `layoutSpecThatFits:` method. This is where you will put the majority of your layout code. It defines the layout and does the heavy calculation on a background thread.

Every `ASDisplayNode` that would like to layout it's subnodes should should do this by implementing the `layoutSpecThatFits:` method. This method is where you build out a layout spec object that will produce the size of the node, as well as the size and position of all subnodes.

The following `layoutSpecThatFits:` implementation is from the Kittens example and will implement an easy stack layout with an image with a constrained size on the left and a text to the right. The great thing is, by using a `ASStackLayoutSpec` the height is dynamically calculated based on the image height and the height of the text.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // Set an intrinsic size for the image node
  CGSize imageSize = _isImageEnlarged ? CGSizeMake(2.0 * kImageSize, 2.0 * kImageSize)
                                      : CGSizeMake(kImageSize, kImageSize);
  [_imageNode setSizeFromCGSize:imageSize];

  // Shrink the text node in case the image + text gonna be too wide
  _textNode.flexShrink = YES;

  // Configure stack
  ASStackLayoutSpec *stackLayoutSpec =
  [ASStackLayoutSpec
   stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
   spacing:kInnerPadding
   justifyContent:ASStackLayoutJustifyContentStart
   alignItems:ASStackLayoutAlignItemsStart
   children:_swappedTextAndImage ? @[_textNode, _imageNode] : @[_imageNode, _textNode]];

  // Add inset
  return [ASInsetLayoutSpec
          insetLayoutSpecWithInsets:UIEdgeInsetsMake(kOuterPadding, kOuterPadding, kOuterPadding, kOuterPadding)
          child:stackLayoutSpec];
}
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
  </pre>
</div>
</div>


The result looks like the following:
![Kittens Node](https://d3vv6lp55qjaqc.cloudfront.net/items/2l133Y2B3r1F231a310q/Screen%20Shot%202016-08-23%20at%202.29.12%20PM.png)

Let's look at some more advanced composition of layout spec and layoutable implementation from the `ASDKGram` example that should give you a feel how layout specs and layoutables can be combined to compose a difficult layout. You can also find this code in the `examples/ASDKGram` folder.

<div class = "highlight-group">
<span class="language-toggle">
  <a data-lang="swift" class="swiftButton">Swift</a>
  <a data-lang="objective-c" class = "active objcButton">Objective-C</a>
</span>

<div class = "code">
  <pre lang="objc" class="objcCode">
  </pre>

  <pre lang="swift" class = "swiftCode hidden">
override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {

  // ASImageNode layoutable - constrain avatar image frame size
  self.userAvatarImageView.width = ASDimensionMake(USER_IMAGE_HEIGHT);
  self.userAvatarImageView.height = ASDimensionMake(USER_IMAGE_HEIGHT);

  // ASLayoutSpec as spacer
  let spacer = ASLayoutSpec()
  spacer.flexGrow = true

  // header stack
  let headerStack = ASStackLayoutSpec.horizontalStackLayoutSpec()
  headerStack.alignItems = .Center;       // center items vertically in horizontal stack
  headerStack.justifyContent = .Start;    // justify content to left side of header stack
  headerStack.spacing = HORIZONTAL_BUFFER;
  headerStack.children = [self.userAvatarImageView, self.userNameLabel, spacer, self.photoTimeIntervalSincePostLabel]

  // header inset stack
  let insets = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  let headerWithInset = ASInsetLayoutSpec(insets: insets, child: headerStack)
  headerWithInset.flexShrink = true;

  // footer stack
  let footerStack = ASStackLayoutSpec.verticalStackLayoutSpec();
  footerStack.spacing = VERTICAL_BUFFER;
  footerStack.children = self.photoLikesLabel, self.photoDescriptionLabel, self.photoCommentsView

  // footer inset stack
  let footerInsets = UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER);
  let footerWithInset = ASInsetLayoutSpec(insets: footerInsets, child: footerStack)

  // ASNetworkImageNode layoutable - constrain photo frame size
  let cellWidth = constrainedSize.max.width;
  self.photoImageView.size.width = ASDimensionMake(cellWidth);
  self.photoImageView.size.height = ASDimensionMake(cellWidth);

  // vertical stack
  let verticalStack   = ASStackLayoutSpec.verticalStackLayoutSpec();
  verticalStack.alignItems = .Stretch;    // stretch headerStack to fill horizontal space
  verticalStack.children = [headerWithInset, self.photoImageView, footerWithInset]
  return verticalStack;
}
  </pre>
</div>
</div>

After the layout pass happened the result will look like the following:
![ASDKGram](https://d3vv6lp55qjaqc.cloudfront.net/items/1l0t352p441K3k0C3y1l/layout-example-2.png)

The layout spec object that you create in `layoutSpecThatFits:` is mutable up until the point that it is return in this method. After this point, it will be immutable. It's important to remember not to cache layout specs for use later but instead to recreate them when necessary.

Note: Because it is run on a background thread, you should not set any node.view or node.layer properties here. Also, unless you know what you are doing, do not create any nodes in this method. Additionally, it is not necessary to begin this method with a call to super, unlike other method overrides.
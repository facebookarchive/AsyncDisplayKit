---
title: Layout Examples
layout: docs
permalink: /docs/automatic-layout-examples.html
prevPage: automatic-layout-containers.html
nextPage: automatic-layout-debugging.html
---

Three examples in increasing order of complexity. 
#NSSpain Talk Example

<img src="/static/images/layout-example-1.png">

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constraint
{
  ASStackLayoutSpec *vStack = [[ASStackLayoutSpec alloc] init];
  
  [vStack setChildren:@[titleNode, bodyNode];

  ASStackLayoutSpec *hstack = [[ASStackLayoutSpec alloc] init];
  hStack.direction          = ASStackLayoutDirectionHorizontal;
  hStack.spacing            = 5.0;

  [hStack setChildren:@[imageNode, vStack]];
  
  ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(5,5,5,5) child:hStack];

  return insetSpec;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">

</pre>
</div>
</div>

###Discussion

#Social App Layout

<img src="/static/images/layout-example-2.png">

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // header stack
  _userAvatarImageView.preferredFrameSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);  // constrain avatar image frame size
  
  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow      = YES;

  ASStackLayoutSpec *headerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.alignItems         = ASStackLayoutAlignItemsCenter;       // center items vertically in horizontal stack
  headerStack.justifyContent     = ASStackLayoutJustifyContentStart;    // justify content to left side of header stack
  headerStack.spacing            = HORIZONTAL_BUFFER;

  [headerStack setChildren:@[_userAvatarImageView, _userNameLabel, spacer, _photoTimeIntervalSincePostLabel]];
  
  // header inset stack
  
  UIEdgeInsets insets                = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:headerStack];
  headerWithInset.flexShrink = YES;
  
  // vertical stack
  
  CGFloat cellWidth                  = constrainedSize.max.width;
  _photoImageView.preferredFrameSize = CGSizeMake(cellWidth, cellWidth);  // constrain photo frame size
  
  ASStackLayoutSpec *verticalStack   = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.alignItems           = ASStackLayoutAlignItemsStretch;    // stretch headerStack to fill horizontal space
  
  [verticalStack setChildren:@[headerWithInset, _photoImageView, footerWithInset]];

  return verticalStack;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">

</pre>
</div>
</div>

###Discussion

Get the full ASDK project at examples/ASDKgram.

#Social App Layout 2

<img src="/static/images/layout-example-3.png">

<div class = "highlight-group">
<span class="language-toggle"><a data-lang="swift" class="swiftButton">Swift</a><a data-lang="objective-c" class = "active objcButton">Objective-C</a></span>

<div class = "code">
<pre lang="objc" class="objcCode">
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize {

  ASLayoutSpec *textSpec  = [self textSpec];
  ASLayoutSpec *imageSpec = [self imageSpecWithSize:constrainedSize];
  ASOverlayLayoutSpec *soldOutOverImage = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:imageSpec 
                                                                                  overlay:[self soldOutLabelSpec]];
  
  NSArray *stackChildren = @[soldOutOverImage, textSpec];
  
  ASStackLayoutSpec *mainStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical 
                                                                         spacing:0.0
                                                                  justifyContent:ASStackLayoutJustifyContentStart
                                                                      alignItems:ASStackLayoutAlignItemsStretch          
                                                                        children:stackChildren];
  
  ASOverlayLayoutSpec *soldOutOverlay = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:mainStack 
                                                                                overlay:self.soldOutOverlay];
  
  return soldOutOverlay;
}

- (ASLayoutSpec *)textSpec {
  CGFloat kInsetHorizontal        = 16.0;
  CGFloat kInsetTop               = 6.0;
  CGFloat kInsetBottom            = 0.0;
  UIEdgeInsets textInsets         = UIEdgeInsetsMake(kInsetTop, kInsetHorizontal, kInsetBottom, kInsetHorizontal);
  
  ASLayoutSpec *verticalSpacer    = [[ASLayoutSpec alloc] init];
  verticalSpacer.flexGrow         = YES;
  
  ASLayoutSpec *horizontalSpacer1 = [[ASLayoutSpec alloc] init];
  horizontalSpacer1.flexGrow      = YES;
  
  ASLayoutSpec *horizontalSpacer2 = [[ASLayoutSpec alloc] init];
  horizontalSpacer2.flexGrow      = YES;
  
  NSArray *info1Children = @[self.firstInfoLabel, self.distanceLabel, horizontalSpacer1, self.originalPriceLabel];
  NSArray *info2Children = @[self.secondInfoLabel, horizontalSpacer2, self.finalPriceLabel];
  if ([ItemNode isRTL]) {
    info1Children = [[info1Children reverseObjectEnumerator] allObjects];
    info2Children = [[info2Children reverseObjectEnumerator] allObjects];
  }
  
  ASStackLayoutSpec *info1Stack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal 
                                                                          spacing:1.0
                                                                   justifyContent:ASStackLayoutJustifyContentStart 
                                                                       alignItems:ASStackLayoutAlignItemsBaselineLast children:info1Children];
  
  ASStackLayoutSpec *info2Stack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal 
                                                                          spacing:0.0
                                                                   justifyContent:ASStackLayoutJustifyContentCenter 
                                                                       alignItems:ASStackLayoutAlignItemsBaselineLast children:info2Children];
  
  ASStackLayoutSpec *textStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical 
                                                                         spacing:0.0
                                                                  justifyContent:ASStackLayoutJustifyContentEnd
                                                                      alignItems:ASStackLayoutAlignItemsStretch
                                                                        children:@[self.titleLabel, verticalSpacer, info1Stack, info2Stack]];
  
  ASInsetLayoutSpec *textWrapper = [ASInsetLayoutSpec insetLayoutSpecWithInsets:textInsets 
                                                                          child:textStack];
  textWrapper.flexGrow = YES;
  
  return textWrapper;
}

- (ASLayoutSpec *)imageSpecWithSize:(ASSizeRange)constrainedSize {
  CGFloat imageRatio = [self imageRatioFromSize:constrainedSize.max];
  
  ASRatioLayoutSpec *imagePlace = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:imageRatio child:self.dealImageView];
  
  self.badge.layoutPosition = CGPointMake(0, constrainedSize.max.height - kFixedLabelsAreaHeight - kBadgeHeight);
  self.badge.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMake(ASRelativeDimensionMakeWithPercent(0), ASRelativeDimensionMakeWithPoints(kBadgeHeight)), ASRelativeSizeMake(ASRelativeDimensionMakeWithPercent(1), ASRelativeDimensionMakeWithPoints(kBadgeHeight)));
  ASStaticLayoutSpec *badgePosition = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.badge]];
  
  ASOverlayLayoutSpec *badgeOverImage = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:imagePlace overlay:badgePosition];
  badgeOverImage.flexGrow = YES;
  
  return badgeOverImage;
}

- (ASLayoutSpec *)soldOutLabelSpec {
  ASCenterLayoutSpec *centerSoldOutLabel = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY 
  sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY child:self.soldOutLabelFlat];
  ASStaticLayoutSpec *soldOutBG = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.soldOutLabelBackground]];
  ASCenterLayoutSpec *centerSoldOut = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY   sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:soldOutBG];
  ASBackgroundLayoutSpec *soldOutLabelOverBackground = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:centerSoldOutLabel background:centerSoldOut];
  return soldOutLabelOverBackground;
}
</pre>
<pre lang="swift" class = "swiftCode hidden">

</pre>
</div>
</div>

###Discussion

Get the full ASDK project at examples/CatDealsCollectionView.

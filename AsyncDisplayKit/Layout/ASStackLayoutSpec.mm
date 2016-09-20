//
//  ASStackLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <numeric>
#import <vector>

#import "ASInternalHelpers.h"

#import "ASLayoutSpecUtilities.h"
#import "ASStackBaselinePositionedLayout.h"
#import "ASThread.h"


#pragma mark - ASStackLayoutSpecStyleDeclaration

@implementation ASStackLayoutSpecStyleDeclaration

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _horizontalAlignment = ASHorizontalAlignmentNone;
  _verticalAlignment = ASVerticalAlignmentNone;
  
  return self;
}

- (void)setDirection:(ASStackLayoutDirection)direction
{
  if (_direction != direction) {
    _direction = direction;
    [self resolveHorizontalAlignment];
    [self resolveVerticalAlignment];
  }
}

- (void)setHorizontalAlignment:(ASHorizontalAlignment)horizontalAlignment
{
  if (_horizontalAlignment != horizontalAlignment) {
    _horizontalAlignment = horizontalAlignment;
    [self resolveHorizontalAlignment];
  }
}

- (void)setVerticalAlignment:(ASVerticalAlignment)verticalAlignment
{
  if (_verticalAlignment != verticalAlignment) {
    _verticalAlignment = verticalAlignment;
    [self resolveVerticalAlignment];
  }
}

- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems
{
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _alignItems = alignItems;
}

- (void)setJustifyContent:(ASStackLayoutJustifyContent)justifyContent
{
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _justifyContent = justifyContent;
}


- (void)resolveHorizontalAlignment
{
  if (_direction == ASStackLayoutDirectionHorizontal) {
    _justifyContent = justifyContent(_horizontalAlignment, _justifyContent);
  } else {
    _alignItems = alignment(_horizontalAlignment, _alignItems);
  }
}

- (void)resolveVerticalAlignment
{
  if (_direction == ASStackLayoutDirectionHorizontal) {
    _alignItems = alignment(_verticalAlignment, _alignItems);
  } else {
    _justifyContent = justifyContent(_verticalAlignment, _justifyContent);
  }
}

@end


#pragma mark - ASStackLayoutSpec

@implementation ASStackLayoutSpec {
  ASDN::RecursiveMutex __instanceLock__;
  ASStackLayoutSpecStyleDeclaration *_style;
}

#pragma mark - Class

+ (instancetype)stackLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  return [[self alloc] initWithDirection:direction spacing:spacing justifyContent:justifyContent alignItems:alignItems children:children];
}

+ (instancetype)verticalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.style.direction = ASStackLayoutDirectionVertical;
  return stackLayoutSpec;
}

+ (instancetype)horizontalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.style.direction = ASStackLayoutDirectionHorizontal;
  return stackLayoutSpec;
}

#pragma mark - Class

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal spacing:0.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStretch children:nil];
}

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }

  _style.direction = direction;
  _style.spacing = spacing;
  _style.alignItems = alignItems;
  _style.justifyContent = justifyContent;

  self.children = children;

  return self;
}

#pragma mark - Style

- (void)loadStyle
{
  _style = [[ASStackLayoutSpecStyleDeclaration alloc] init];
}

- (ASStackLayoutSpecStyleDeclaration *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

#pragma mark - ASLayoutSpec

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  std::vector<id<ASLayoutable>> stackChildren;
  for (id<ASLayoutable> child in self.children) {
    stackChildren.push_back(child);
  }
  
  if (stackChildren.empty()) {
    return [ASLayout layoutWithLayoutable:self size:constrainedSize.min];
  }
  
  ASStackLayoutSpecStyleDeclaration *styleDeclaration = self.style;
  ASStackLayoutSpecStyle style = {
    .direction = styleDeclaration.direction,
    .spacing = styleDeclaration.spacing,
    .justifyContent = styleDeclaration.justifyContent,
    .alignItems = styleDeclaration.alignItems,
    .baselineRelativeArrangement = styleDeclaration.baselineRelativeArrangement
  };
  BOOL needsBaselinePass = styleDeclaration.baselineRelativeArrangement
                            || styleDeclaration.alignItems == ASStackLayoutAlignItemsBaselineFirst
                            || styleDeclaration.alignItems == ASStackLayoutAlignItemsBaselineLast;
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  
  CGSize finalSize = CGSizeZero;
  NSArray *sublayouts = nil;
  
  // regardless of whether or not this stack aligns to baseline, we should let ASStackBaselinePositionedLayout::compute find the max ascender
  // and min descender in case this spec is a child in another spec that wants to align to a baseline.
  const auto baselinePositionedLayout = ASStackBaselinePositionedLayout::compute(positionedLayout, style, constrainedSize);
  if (styleDeclaration.direction == ASStackLayoutDirectionVertical) {
    self.style.ascender = stackChildren.front().style.ascender;
    self.style.descender = stackChildren.back().style.descender;
  } else {
    self.style.ascender = baselinePositionedLayout.ascender;
    self.style.descender = baselinePositionedLayout.descender;
  }
  
  if (needsBaselinePass) {
    finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, baselinePositionedLayout.crossSize);
    sublayouts = [NSArray arrayWithObjects:&baselinePositionedLayout.sublayouts[0] count:baselinePositionedLayout.sublayouts.size()];
  } else {
    finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
    sublayouts = [NSArray arrayWithObjects:&positionedLayout.sublayouts[0] count:positionedLayout.sublayouts.size()];
  }
  
  return [ASLayout layoutWithLayoutable:self size:ASSizeRangeClamp(constrainedSize, finalSize) sublayouts:sublayouts];
}

@end

@implementation ASStackLayoutSpec (ASEnvironment)

- (BOOL)supportsUpwardPropagation
{
  return NO;
}

@end

@implementation ASStackLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)asciiArtString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName] direction:self.style.direction];
}

@end

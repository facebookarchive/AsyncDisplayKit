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

@implementation ASStackLayoutSpec
{
  ASDN::RecursiveMutex _propertyLock;
}

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal spacing:0.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStart children:nil];
}

+ (instancetype)stackLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  return [[self alloc] initWithDirection:direction spacing:spacing justifyContent:justifyContent alignItems:alignItems children:children];
}

+ (instancetype)verticalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.direction = ASStackLayoutDirectionVertical;
  return stackLayoutSpec;
}

+ (instancetype)horizontalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.direction = ASStackLayoutDirectionHorizontal;
  return stackLayoutSpec;
}

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  _direction = direction;
  _spacing = spacing;
  _horizontalAlignment = ASHorizontalAlignmentNone;
  _verticalAlignment = ASVerticalAlignmentNone;
  _alignItems = alignItems;
  _justifyContent = justifyContent;
  
  [self setChildren:children];
  return self;
}

- (void)setDirection:(ASStackLayoutDirection)direction
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_direction != direction) {
    _direction = direction;
    [self resolveHorizontalAlignment];
    [self resolveVerticalAlignment];
  }
}

- (void)setHorizontalAlignment:(ASHorizontalAlignment)horizontalAlignment
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_horizontalAlignment != horizontalAlignment) {
    _horizontalAlignment = horizontalAlignment;
    [self resolveHorizontalAlignment];
  }
}

- (void)setVerticalAlignment:(ASVerticalAlignment)verticalAlignment
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_verticalAlignment != verticalAlignment) {
    _verticalAlignment = verticalAlignment;
    [self resolveVerticalAlignment];
  }
}

- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _alignItems = alignItems;
}

- (void)setJustifyContent:(ASStackLayoutJustifyContent)justifyContent
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _justifyContent = justifyContent;
}

- (void)setSpacing:(CGFloat)spacing
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _spacing = spacing;
}

- (void)setBaselineRelativeArrangement:(BOOL)baselineRelativeArrangement
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _baselineRelativeArrangement = baselineRelativeArrangement;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  if (self.children.count == 0) {
    return [ASLayout layoutWithLayoutableObject:self
                           constrainedSizeRange:constrainedSize
                                           size:constrainedSize.min];
  }
  
  ASStackLayoutSpecStyle style = {.direction = _direction, .spacing = _spacing, .justifyContent = _justifyContent, .alignItems = _alignItems, .baselineRelativeArrangement = _baselineRelativeArrangement};
  BOOL needsBaselinePass = _baselineRelativeArrangement || _alignItems == ASStackLayoutAlignItemsBaselineFirst || _alignItems == ASStackLayoutAlignItemsBaselineLast;
  
  std::vector<id<ASLayoutable>> stackChildren = std::vector<id<ASLayoutable>>();
  for (id<ASLayoutable> child in self.children) {
    stackChildren.push_back(child);
  }
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  
  CGSize finalSize = CGSizeZero;
  NSArray *sublayouts = nil;
  
  // regardless of whether or not this stack aligns to baseline, we should let ASStackBaselinePositionedLayout::compute find the max ascender
  // and min descender in case this spec is a child in another spec that wants to align to a baseline.
  const auto baselinePositionedLayout = ASStackBaselinePositionedLayout::compute(positionedLayout, style, constrainedSize);
  if (self.direction == ASStackLayoutDirectionVertical) {
    ASDN::MutexLocker l(_propertyLock);
    self.ascender = [[self.children firstObject] ascender];
    self.descender = [[self.children lastObject] descender];
  } else {
    ASDN::MutexLocker l(_propertyLock);
    self.ascender = baselinePositionedLayout.ascender;
    self.descender = baselinePositionedLayout.descender;
  }
  
  if (needsBaselinePass) {
    finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, baselinePositionedLayout.crossSize);
    sublayouts = [NSArray arrayWithObjects:&baselinePositionedLayout.sublayouts[0] count:baselinePositionedLayout.sublayouts.size()];
  } else {
    finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
    sublayouts = [NSArray arrayWithObjects:&positionedLayout.sublayouts[0] count:positionedLayout.sublayouts.size()];
  }
  
  return [ASLayout layoutWithLayoutableObject:self
                         constrainedSizeRange:constrainedSize
                                         size:ASSizeRangeClamp(constrainedSize, finalSize)
                                   sublayouts:sublayouts];
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
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName] direction:self.direction];
}

@end

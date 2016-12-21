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

#import "ASLayoutElement.h"
#import "ASLayoutElementStylePrivate.h"
#import "ASLayoutSpecUtilities.h"
#import "ASStackBaselinePositionedLayout.h"
#import "ASThread.h"

@implementation ASStackLayoutSpec

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal spacing:0.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStretch children:nil];
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

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  NSArray *children = self.children;
  if (children.count == 0) {
    return [ASLayout layoutWithLayoutElement:self size:constrainedSize.min];
  }
 
  // Accessing the style and size property is pretty costly we create layout spec children we use to figure
  // out the layout for each child
  const auto stackChildren = AS::map(children, [&](const id<ASLayoutElement> child) -> ASStackLayoutSpecChild {
    ASLayoutElementStyle *style = child.style;
    return {child, style, style.size};
  });
  
  const ASStackLayoutSpecStyle style = {.direction = _direction, .spacing = _spacing, .justifyContent = _justifyContent, .alignItems = _alignItems, .baselineRelativeArrangement = _baselineRelativeArrangement};
  
  // First pass is to get the children into a positioned state
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  
  // Figure out if a baseline pass is really needed
  const BOOL directionIsVertical = (style.direction == ASStackLayoutDirectionVertical);
  const BOOL needsBaselineAlignment = ASStackBaselinePositionedLayout::needsBaselineAlignment(style);
  const BOOL needsBaselinePositioning = (directionIsVertical == NO || needsBaselineAlignment == YES);
  
  NSMutableArray *sublayouts = [NSMutableArray array];
  CGSize finalSize = CGSizeZero;
  if (needsBaselinePositioning) {
    // All horizontal stacks, regardless of whether or not they are baseline aligned, should go through a baseline
    // computation. They could be used in another horizontal stack that is baseline aligned and will need to have
    // computed the proper ascender/descender.
    
    // Vertical stacks do not need to go through this computation since we can easily compute ascender/descender by
    // looking at their first/last child's ascender/descender.
    const auto baselinePositionedLayout = ASStackBaselinePositionedLayout::compute(positionedLayout, style, constrainedSize);

    if (directionIsVertical == NO) {
      self.style.ascender = baselinePositionedLayout.ascender;
      self.style.descender = baselinePositionedLayout.descender;
    }
    
    if (needsBaselineAlignment == YES) {
      finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, baselinePositionedLayout.crossSize);

      for (const auto &l : baselinePositionedLayout.items) {
        [sublayouts addObject:l.layout];
      }
    }
  }
  
  if (directionIsVertical == YES) {
    self.style.ascender = stackChildren.front().style.ascender;
    self.style.descender = stackChildren.back().style.descender;
  }
  
  if (needsBaselineAlignment == NO) {
    finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
    
    for (const auto &l : positionedLayout.items) {
      [sublayouts addObject:l.layout];
    }
  }
  
  return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, finalSize) sublayouts:sublayouts];
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

@implementation ASStackLayoutSpec (Debugging)

#pragma mark - ASLayoutElementAsciiArtProtocol

- (NSString *)asciiArtString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName] direction:self.direction];
}

@end

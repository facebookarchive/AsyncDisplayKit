/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASBaselineLayoutSpec.h"
#import "ASStackLayoutable.h"

#import <numeric>
#import <vector>

#import "ASBaseDefines.h"
#import "ASInternalHelpers.h"

#import "ASLayoutSpecUtilities.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASStackPositionedLayout.h"
#import "ASStackUnpositionedLayout.h"
#import "ASBaselinePositionedLayout.h"
#import "ASThread.h"


@implementation ASBaselineLayoutSpec
{
  ASDN::RecursiveMutex _propertyLock;
}

@synthesize ascender = _ascender;
@synthesize descender = _descender;

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing baselineAlignment:(ASBaselineLayoutBaselineAlignment)baselineAlignment justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssert((direction == ASStackLayoutDirectionHorizontal && baselineAlignment != ASBaselineLayoutBaselineAlignmentNone) || direction == ASStackLayoutDirectionVertical, @"baselineAlignment is set to none. If you don't need baseline alignment please use ASStackLayoutSpec");
  _direction = direction;
  _alignItems = alignItems;
  _spacing = spacing;
  _justifyContent = justifyContent;
  _baselineAlignment = baselineAlignment;
  
  [self setChildren:children];
  return self;
}


+ (instancetype)baselineLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing baselineAlignment:(ASBaselineLayoutBaselineAlignment)baselineAlignment justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  return [[ASBaselineLayoutSpec alloc] initWithDirection:direction spacing:spacing baselineAlignment:baselineAlignment justifyContent:justifyContent alignItems:alignItems children:children];
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpecStyle stackStyle = {.direction = _direction, .spacing = _spacing, .justifyContent = _justifyContent, .alignItems = _alignItems};
  ASBaselineLayoutSpecStyle style = { .baselineAlignment = _baselineAlignment, .stackLayoutStyle = stackStyle };
  
  std::vector<id<ASStackLayoutable>> stackChildren = std::vector<id<ASStackLayoutable>>();
  for (id<ASStackLayoutable> child in self.children) {
    stackChildren.push_back(child);
  }
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, stackStyle, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, stackStyle, constrainedSize);
  const auto baselinePositionedLayout = ASBaselinePositionedLayout::compute(positionedLayout, style, constrainedSize);
  
  const CGSize finalSize = directionSize(stackStyle.direction, unpositionedLayout.stackDimensionSum, baselinePositionedLayout.crossSize);
  
  NSArray *sublayouts = [NSArray arrayWithObjects:&baselinePositionedLayout.sublayouts[0] count:baselinePositionedLayout.sublayouts.size()];
  
  ASDN::MutexLocker l(_propertyLock);
  _ascender = baselinePositionedLayout.ascender;
  _descender = baselinePositionedLayout.descender;
  
  return [ASLayout layoutWithLayoutableObject:self
                                         size:ASSizeRangeClamp(constrainedSize, finalSize)
                                   sublayouts:sublayouts];
}

- (void)setChildren:(NSArray *)children
{
  [super setChildren:children];
#if DEBUG
  for (id<ASBaselineLayoutable> child in children) {
    NSAssert(([child finalLayoutable] == child && [child conformsToProtocol:@protocol(ASBaselineLayoutable)]) || ([child finalLayoutable] != child && [[child finalLayoutable] conformsToProtocol:@protocol(ASBaselineLayoutable)]), @"child must conform to ASBaselineLayoutable");
  }
#endif
}

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(NO, @"ASBaselineLayoutSpec only supports setChildren");
}

@end

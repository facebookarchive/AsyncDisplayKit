/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackLayoutSpec.h"

#import <numeric>
#import <vector>

#import "ASBaseDefines.h"
#import "ASInternalHelpers.h"

#import "ASLayoutSpecUtilities.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASStackPositionedLayout.h"
#import "ASStackUnpositionedLayout.h"
#import "ASThread.h"

@implementation ASStackLayoutSpec

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal spacing:0.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStart children:nil];
}

+ (instancetype)stackLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  return [[self alloc] initWithDirection:direction spacing:spacing justifyContent:justifyContent alignItems:alignItems children:children];
}

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  _direction = direction;
  _alignItems = alignItems;
  _spacing = spacing;
  _justifyContent = justifyContent;
  
  [self setChildren:children];
  return self;
}

- (void)setDirection:(ASStackLayoutDirection)direction
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _direction = direction;
}

- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _alignItems = alignItems;
}

- (void)setJustifyContent:(ASStackLayoutJustifyContent)justifyContent
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _justifyContent = justifyContent;
}

- (void)setSpacing:(CGFloat)spacing
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _spacing = spacing;
}

- (void)setChildren:(NSArray *)children
{
  [super setChildren:children];
  
#if DEBUG
  for (id<ASStackLayoutable> child in children) {
    ASDisplayNodeAssert(([child finalLayoutable] == child && [child conformsToProtocol:@protocol(ASStackLayoutable)]) || ([child finalLayoutable] != child && [[child finalLayoutable] conformsToProtocol:@protocol(ASStackLayoutable)]), @"child must conform to ASBaselineLayoutable");
  }
#endif
}

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(NO, @"ASStackLayoutSpec only supports setChildren");
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpecStyle style = {.direction = _direction, .spacing = _spacing, .justifyContent = _justifyContent, .alignItems = _alignItems};
  std::vector<id<ASStackLayoutable>> stackChildren = std::vector<id<ASStackLayoutable>>();
  for (id<ASStackLayoutable> child in self.children) {
    NSAssert([child conformsToProtocol:@protocol(ASStackLayoutable)], @"Child must implement ASStackLayoutable");
    stackChildren.push_back(child);
  }
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  const CGSize finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
  NSArray *sublayouts = [NSArray arrayWithObjects:&positionedLayout.sublayouts[0] count:positionedLayout.sublayouts.size()];
  return [ASLayout layoutWithLayoutableObject:self
                                         size:ASSizeRangeClamp(constrainedSize, finalSize)
                                   sublayouts:sublayouts];
}

@end

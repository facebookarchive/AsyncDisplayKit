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

@implementation ASStackLayoutSpec
{
  std::vector<id<ASLayoutable>> _children;
}

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal
                         spacing:0.0
            contentJustification:ASStackLayoutJustifyContentStart
                   itemAlignment:ASStackLayoutAlignItemsStart
                        children:nil];
}

+ (instancetype)satckLayoutSpecWithDirection:(ASStackLayoutDirection)direction
                                     spacing:(CGFloat)spacing
                        contentJustification:(ASStackLayoutJustifyContent)justifyContent
                               itemAlignment:(ASStackLayoutAlignItems)alignItems
                                    children:(NSArray *)children
{
  return [[self alloc] initWithDirection:direction
                                 spacing:spacing
                    contentJustification:justifyContent
                           itemAlignment:alignItems
                                children:children];
}

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction
                          spacing:(CGFloat)spacing
             contentJustification:(ASStackLayoutJustifyContent)justifyContent
                    itemAlignment:(ASStackLayoutAlignItems)alignItems
                         children:(NSArray *)children;
{
  self = [super init];
  if (self) {
    _direction = direction;
    _alignItems = alignItems;
    _spacing = spacing;
    _justifyContent = justifyContent;
    
    _children = std::vector<id<ASLayoutable>>();
    for (id<ASLayoutable> child in children) {
      _children.push_back(child);
    }
  }
  return self;
}

- (void)addChild:(id<ASLayoutable>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _children.push_back(child);
}

- (void)addChildren:(NSArray *)children
{
  for (id<ASLayoutable> child in children) {
    [self addChild:child];
  }
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

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpecStyle style = {.direction = _direction,
    .spacing = _spacing,
    .justifyContent = _justifyContent,
    .alignItems = _alignItems
  };
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_children, style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  const CGSize finalSize = directionSize(style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
  NSArray *sublayouts = [NSArray arrayWithObjects:&positionedLayout.sublayouts[0] count:positionedLayout.sublayouts.size()];
  return [ASLayout layoutWithLayoutableObject:self
                                         size:ASSizeRangeClamp(constrainedSize, finalSize)
                                   sublayouts:sublayouts];
}

@end

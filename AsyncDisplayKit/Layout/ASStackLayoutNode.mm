/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackLayoutNode.h"

#import <numeric>
#import <vector>

#import "ASBaseDefines.h"
#import "ASInternalHelpers.h"

#import "ASLayoutNodeUtilities.h"
#import "ASStackLayoutNodeUtilities.h"
#import "ASStackPositionedLayout.h"
#import "ASStackUnpositionedLayout.h"

@implementation ASStackLayoutNode
{
  ASStackLayoutNodeStyle _style;
  std::vector<id<ASLayoutable>> _children;
}

+ (instancetype)newWithStyle:(ASStackLayoutNodeStyle)style children:(NSArray *)children
{
  ASStackLayoutNode *n = [super new];
  if (n) {
    n->_style = style;
    n->_children = std::vector<id<ASLayoutable>>();
    for (id<ASLayoutable> child in children) {
      n->_children.push_back(child);
    }
  }
  return n;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_children, _style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, _style, constrainedSize);
  const CGSize finalSize = directionSize(_style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
  NSArray *children = [NSArray arrayWithObjects:&positionedLayout.children[0] count:positionedLayout.children.size()];
  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, finalSize)
                                  children:children];
}

@end

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
{
  ASStackLayoutSpecStyle _style;
  std::vector<id<ASStackLayoutable>> _children;
}

+ (instancetype)newWithStyle:(ASStackLayoutSpecStyle)style children:(NSArray *)children
{
  ASStackLayoutSpec *spec = [super new];
  if (spec) {
    spec->_style = style;
    spec->_children = std::vector<id<ASStackLayoutable>>();
    for (id<ASStackLayoutable> child in children) {
      ASDisplayNodeAssert([child conformsToProtocol:@protocol(ASStackLayoutable)], @"child must conform to ASStackLayoutable");

      spec->_children.push_back(child);
    }
  }
  return spec;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_children, _style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, _style, constrainedSize);
  const CGSize finalSize = directionSize(_style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
  NSArray *sublayouts = [NSArray arrayWithObjects:&positionedLayout.sublayouts[0] count:positionedLayout.sublayouts.size()];
  
  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, finalSize)
                                sublayouts:sublayouts];
}

@end

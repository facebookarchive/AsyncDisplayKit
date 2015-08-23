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
  ASBaselineLayoutSpecStyle _style;
  std::vector<id<ASStackLayoutable>> _stackChildren;
  ASDN::RecursiveMutex _propertyLock;
}

@synthesize ascender = _ascender;
@synthesize descender = _descender;

+ (instancetype)newWithStyle:(ASBaselineLayoutSpecStyle)style children:(NSArray *)children
{
  ASDisplayNodeAssert((style.stackLayoutStyle.direction == ASStackLayoutDirectionHorizontal && style.baselineAlignment != ASBaselineLayoutBaselineAlignmentNone) || style.stackLayoutStyle.direction == ASStackLayoutDirectionVertical, @"baselineAlignment is set to none. If you don't need baseline alignment please use ASStackLayoutSpec");
  
  ASBaselineLayoutSpec *spec = [super new];
  if (spec) {
    spec->_style = style;
    spec->_stackChildren = std::vector<id<ASStackLayoutable>>();
    for (id<ASBaselineLayoutable> child in children) {
      ASDisplayNodeAssert([child conformsToProtocol:@protocol(ASBaselineLayoutable)], @"child must conform to ASStackLayoutable");
      
      spec->_stackChildren.push_back(child);
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
  ASStackLayoutSpecStyle stackStyle = _style.stackLayoutStyle;
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_stackChildren, stackStyle, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, stackStyle, constrainedSize);
  const auto baselinePositionedLayout = ASBaselinePositionedLayout::compute(positionedLayout, _style, constrainedSize);
  
  const CGSize finalSize = directionSize(stackStyle.direction, unpositionedLayout.stackDimensionSum, baselinePositionedLayout.crossSize);
  
  NSArray *sublayouts = [NSArray arrayWithObjects:&baselinePositionedLayout.sublayouts[0] count:baselinePositionedLayout.sublayouts.size()];
  
  ASDN::MutexLocker l(_propertyLock);
  _ascender = baselinePositionedLayout.ascender;
  _descender = baselinePositionedLayout.descender;
  
  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, finalSize)
                                sublayouts:sublayouts];
}
@end

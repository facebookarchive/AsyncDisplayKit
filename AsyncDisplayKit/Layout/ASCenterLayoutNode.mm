/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASCenterLayoutNode.h"

#import "ASInternalHelpers.h"

@implementation ASCenterLayoutNode
{
  ASCenterLayoutNodeCenteringOptions _centeringOptions;
  ASCenterLayoutNodeSizingOptions _sizingOptions;
  id<ASLayoutable> _child;
}

+ (instancetype)newWithCenteringOptions:(ASCenterLayoutNodeCenteringOptions)centeringOptions
                          sizingOptions:(ASCenterLayoutNodeSizingOptions)sizingOptions
                                  child:(id<ASLayoutable>)child
{
  ASCenterLayoutNode *n = [super new];
  if (n) {
    n->_centeringOptions = centeringOptions;
    n->_sizingOptions = sizingOptions;
    n->_child = child;
  }
  return n;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize size = {
    constrainedSize.max.width,
    constrainedSize.max.height
  };

  // Layout the child
  const CGSize minChildSize = {
    (_centeringOptions & ASCenterLayoutNodeCenteringX) != 0 ? 0 : constrainedSize.min.width,
    (_centeringOptions & ASCenterLayoutNodeCenteringY) != 0 ? 0 : constrainedSize.min.height,
  };
  ASLayout *childLayout = [_child calculateLayoutThatFits:ASSizeRangeMake(minChildSize, constrainedSize.max)];

  // If we have an undetermined height or width, use the child size to define the layout
  // size
  size = ASSizeRangeClamp(constrainedSize, {
    isnan(size.width) ? childLayout.size.width : size.width,
    isnan(size.height) ? childLayout.size.height : size.height
  });

  // If minimum size options are set, attempt to shrink the size to the size of the child
  size = ASSizeRangeClamp(constrainedSize, {
    MIN(size.width, (_sizingOptions & ASCenterLayoutNodeSizingOptionMinimumX) != 0 ? childLayout.size.width : size.width),
    MIN(size.height, (_sizingOptions & ASCenterLayoutNodeSizingOptionMinimumY) != 0 ? childLayout.size.height : size.height)
  });

  // Compute the centered postion for the child
  BOOL shouldCenterAlongX = (_centeringOptions & ASCenterLayoutNodeCenteringX);
  BOOL shouldCenterAlongY = (_centeringOptions & ASCenterLayoutNodeCenteringY);
  const CGPoint childPosition = {
    ASRoundPixelValue(shouldCenterAlongX ? (size.width - childLayout.size.width) * 0.5f : 0),
    ASRoundPixelValue(shouldCenterAlongY ? (size.height - childLayout.size.height) * 0.5f : 0)
  };

  return [ASLayout newWithLayoutableObject:self
                                      size:size
                                  children:@[[ASLayoutChild newWithPosition:childPosition layout:childLayout]]];
}

@end

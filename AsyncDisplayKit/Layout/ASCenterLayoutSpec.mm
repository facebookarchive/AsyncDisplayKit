/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASCenterLayoutSpec.h"

#import "ASInternalHelpers.h"

@implementation ASCenterLayoutSpec
{
  ASCenterLayoutSpecCenteringOptions _centeringOptions;
  ASCenterLayoutSpecSizingOptions _sizingOptions;
  id<ASLayoutable> _child;
}

+ (instancetype)newWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                          sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                  child:(id<ASLayoutable>)child
{
  ASCenterLayoutSpec *spec = [super new];
  if (spec) {
    spec->_centeringOptions = centeringOptions;
    spec->_sizingOptions = sizingOptions;
    spec->_child = child;
  }
  return spec;
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
    (_centeringOptions & ASCenterLayoutSpecCenteringX) != 0 ? 0 : constrainedSize.min.width,
    (_centeringOptions & ASCenterLayoutSpecCenteringY) != 0 ? 0 : constrainedSize.min.height,
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
    MIN(size.width, (_sizingOptions & ASCenterLayoutSpecSizingOptionMinimumX) != 0 ? childLayout.size.width : size.width),
    MIN(size.height, (_sizingOptions & ASCenterLayoutSpecSizingOptionMinimumY) != 0 ? childLayout.size.height : size.height)
  });

  // Compute the centered postion for the child
  BOOL shouldCenterAlongX = (_centeringOptions & ASCenterLayoutSpecCenteringX);
  BOOL shouldCenterAlongY = (_centeringOptions & ASCenterLayoutSpecCenteringY);
  childLayout.position = {
    ASRoundPixelValue(shouldCenterAlongX ? (size.width - childLayout.size.width) * 0.5f : 0),
    ASRoundPixelValue(shouldCenterAlongY ? (size.height - childLayout.size.height) * 0.5f : 0)
  };

  return [ASLayout newWithLayoutableObject:self size:size children:@[childLayout]];
}

@end

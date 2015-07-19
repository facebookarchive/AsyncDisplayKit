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
#import "ASLayout.h"

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

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
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
  ASLayout *sublayout = [_child measureWithSizeRange:ASSizeRangeMake(minChildSize, constrainedSize.max)];

  // If we have an undetermined height or width, use the child size to define the layout
  // size
  size = ASSizeRangeClamp(constrainedSize, {
    isnan(size.width) ? sublayout.size.width : size.width,
    isnan(size.height) ? sublayout.size.height : size.height
  });

  // If minimum size options are set, attempt to shrink the size to the size of the child
  size = ASSizeRangeClamp(constrainedSize, {
    MIN(size.width, (_sizingOptions & ASCenterLayoutSpecSizingOptionMinimumX) != 0 ? sublayout.size.width : size.width),
    MIN(size.height, (_sizingOptions & ASCenterLayoutSpecSizingOptionMinimumY) != 0 ? sublayout.size.height : size.height)
  });

  // Compute the centered postion for the child
  BOOL shouldCenterAlongX = (_centeringOptions & ASCenterLayoutSpecCenteringX);
  BOOL shouldCenterAlongY = (_centeringOptions & ASCenterLayoutSpecCenteringY);
  sublayout.position = {
    ASRoundPixelValue(shouldCenterAlongX ? (size.width - sublayout.size.width) * 0.5f : 0),
    ASRoundPixelValue(shouldCenterAlongY ? (size.height - sublayout.size.height) * 0.5f : 0)
  };

  return [ASLayout newWithLayoutableObject:self size:size sublayouts:@[sublayout]];
}

@end

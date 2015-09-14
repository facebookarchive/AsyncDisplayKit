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
}

- (instancetype)initWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                           sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                   child:(id<ASLayoutable>)child;
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  _centeringOptions = centeringOptions;
  _sizingOptions = sizingOptions;
  [self setChild:child];
  return self;
}

+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithCenteringOptions:centeringOptions sizingOptions:sizingOptions child:child];
}

- (void)setCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _centeringOptions = centeringOptions;
}

- (void)setSizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _sizingOptions = sizingOptions;
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
  ASLayout *sublayout = [self.child measureWithSizeRange:ASSizeRangeMake(minChildSize, constrainedSize.max)];

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

  return [ASLayout layoutWithLayoutableObject:self size:size sublayouts:@[sublayout]];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
}

- (NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
  return nil;
}

@end

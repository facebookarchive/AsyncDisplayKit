/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASAbstractLayoutController.h"

#include <vector>

#import "ASAssert.h"

@interface ASAbstractLayoutController () {
  std::vector<ASRangeTuningParameters> _tuningParameters;
}
@end

@implementation ASAbstractLayoutController

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _tuningParameters = std::vector<ASRangeTuningParameters>(ASLayoutRangeTypeCount);
  _tuningParameters[ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 3,
    .trailingBufferScreenfuls = 2
  };
  _tuningParameters[ASLayoutRangeTypeRender] = {
    .leadingBufferScreenfuls = 2,
    .trailingBufferScreenfuls = 1
  };
  
  return self;
}

#pragma mark - Tuning Parameters

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeType] = tuningParameters;
}

// Support for the deprecated tuningParameters property
- (ASRangeTuningParameters)tuningParameters
{
  return [self tuningParametersForRangeType:ASLayoutRangeTypeRender];
}

// Support for the deprecated tuningParameters property
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  [self setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeRender];
}

#pragma mark - Index Path Range Support

// Support for deprecated method
- (BOOL)shouldUpdateForVisibleIndexPath:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize
{
  return [self shouldUpdateForVisibleIndexPaths:indexPaths viewportSize:viewportSize rangeType:ASLayoutRangeTypeRender];
}

// Support for the deprecated method
- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize
{
  return [self indexPathsForScrolling:scrollDirection viewportSize:viewportSize rangeType:ASLayoutRangeTypeRender];
}

#pragma mark - Abstract

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertNotSupported();
  return NO;
}

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

@end

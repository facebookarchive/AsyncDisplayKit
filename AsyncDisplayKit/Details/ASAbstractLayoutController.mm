/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASAbstractLayoutController.h"
#import "ASAssert.h"
#include <vector>

@interface ASAbstractLayoutController () {
  std::vector<ASRangeTuningParameters> _tuningParameters;
  CGSize _viewportSize;
}
@end

@implementation ASAbstractLayoutController

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _tuningParameters = std::vector<ASRangeTuningParameters>(ASLayoutRangeTypeCount);
  _tuningParameters[ASLayoutRangeTypeVisible] = {
    .leadingBufferScreenfuls = 0,
    .trailingBufferScreenfuls = 0
  };
  _tuningParameters[ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 1.5,
    .trailingBufferScreenfuls = 0.75
  };
  _tuningParameters[ASLayoutRangeTypeFetchData] = {
    .leadingBufferScreenfuls = 3,
    .trailingBufferScreenfuls = 2
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
  ASDisplayNodeAssert(rangeType != ASLayoutRangeTypeVisible, @"Must not set Visible range tuning parameters (always 0, 0)");
  _tuningParameters[rangeType] = tuningParameters;
}

#pragma mark - Abstract Index Path Range Support

// FIXME: This method can be removed once ASRangeControllerBeta becomes the main version.
- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertNotSupported();
  return NO;
}

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)setViewportSize:(CGSize)viewportSize
{
  _viewportSize = viewportSize;
}

- (CGSize)viewportSize
{
  return _viewportSize;
}

@end

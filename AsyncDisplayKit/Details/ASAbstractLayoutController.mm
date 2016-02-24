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

extern ASRangeTuningParameters const ASRangeTuningParametersZero = {};

extern BOOL ASRangeTuningParametersEqualToRangeTuningParameters(ASRangeTuningParameters lhs, ASRangeTuningParameters rhs)
{
  return lhs.leadingBufferScreenfuls == rhs.leadingBufferScreenfuls && lhs.trailingBufferScreenfuls == rhs.trailingBufferScreenfuls;
}

@interface ASAbstractLayoutController () {
  std::vector<std::vector<ASRangeTuningParameters>> _tuningParameters;
  CGSize _viewportSize;
}
@end

@implementation ASAbstractLayoutController

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _tuningParameters = std::vector<std::vector<ASRangeTuningParameters>> (ASLayoutRangeModeCount, std::vector<ASRangeTuningParameters> (ASLayoutRangeTypeCount));
  
  _tuningParameters[ASLayoutRangeModeMinimum][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 0.25,
    .trailingBufferScreenfuls = 0.25
  };
  _tuningParameters[ASLayoutRangeModeMinimum][ASLayoutRangeTypeFetchData] = {
    .leadingBufferScreenfuls = 1,
    .trailingBufferScreenfuls = 1
  };

  _tuningParameters[ASLayoutRangeModeFull][ASLayoutRangeTypeDisplay] = {
    .leadingBufferScreenfuls = 1.5,
    .trailingBufferScreenfuls = 0.75
  };
  _tuningParameters[ASLayoutRangeModeFull][ASLayoutRangeTypeFetchData] = {
    .leadingBufferScreenfuls = 3,
    .trailingBufferScreenfuls = 2
  };
  
  return self;
}

#pragma mark - Tuning Parameters

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  return [self setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(),
                      @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeMode][rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(),
                      @"Setting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeMode][rangeType] = tuningParameters;
}

#pragma mark - Abstract Index Path Range Support

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
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

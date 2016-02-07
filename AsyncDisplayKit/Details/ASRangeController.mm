/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRangeController.h"

#import "ASAssert.h"
#import "ASDisplayNodeExtras.h"
#import "ASMultiDimensionalArrayUtils.h"
#import "ASRangeHandlerVisible.h"
#import "ASRangeHandlerRender.h"
#import "ASRangeHandlerPreload.h"
#import "ASInternalHelpers.h"
#import "ASLayoutController.h"
#import "ASLayoutRangeType.h"

@implementation ASRangeController

- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(ASScrollDirection)scrollDirection
{
}

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node
{
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  [_layoutController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [_layoutController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

@end
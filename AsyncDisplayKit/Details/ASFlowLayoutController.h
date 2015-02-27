/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>


typedef NS_ENUM(NSUInteger, ASFlowLayoutDirection) {
  ASFlowLayoutDirectionVertical,
  ASFlowLayoutDirectionHorizontal,
};

/**
 * The controller for flow layout.
 */
@interface ASFlowLayoutController : NSObject <ASLayoutController>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

@end

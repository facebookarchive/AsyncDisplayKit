/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@interface ASAbstractLayoutController : NSObject <ASLayoutController>

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

@property (nonatomic, assign) ASRangeTuningParameters tuningParameters ASDISPLAYNODE_DEPRECATED;

@end

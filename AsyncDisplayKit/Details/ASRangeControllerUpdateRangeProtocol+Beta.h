/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASLayoutRangeType.h"
#import "ASViewController.h"
#import "ASRangeController.h"
#import "ASCollectionNode.h"
#import "ASTableNode.h"


@protocol ASRangeControllerUpdateRangeProtocol <NSObject>

/**
 * Updates the current range mode of the range controller for at least the next range update.
 */
- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;

/**
 * Only ASLayoutRangeModeVisibleOnly or ASLayoutRangeModeLowMemory are recommended.  Default is ASLayoutRangeModeVisibleOnly,
 * because this is the only way to ensure an application will not have blank / flashing views as the user navigates back after
 * a memory warning.  Apps that wish to use the more effective / aggressive ASLayoutRangeModeLowMemory may need to take steps
 * to mitigate this behavior, including: restoring a larger range mode to the next controller before the user navigates there,
 * enabling .neverShowPlaceholders on ASCellNodes so that the navigation operation is blocked on redisplay completing, etc.
 */
+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode;

@end


@interface ASRangeController (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

/**
 * Update the range mode for a range controller to a explicitly set mode until the node that contains the range
 * controller becomes visible again
 *
 * Logic for the automatic range mode:
 * 1. If there are no visible node paths available nothing is to be done and no range update will happen
 * 2. The initial range update if the range controller is visible always will be ASLayoutRangeModeCount
 *    (ASLayoutRangeModeMinimum) as it's the initial fetch
 * 3. The range mode set explicitly via updateCurrentRangeWithMode: will last at least one range update. After that it
      the range controller will use the explicit set range mode until it becomes visible and a new range update was
      triggered or a new range mode via updateCurrentRangeWithMode: is set
 * 4. If range mode is not explicitly set the range mode is variying based if the range controller is visible or not
 */
- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;

@end


@interface ASCollectionNode (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

@end


@interface ASTableNode (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

@end


@interface ASViewController (ASRangeControllerUpdateRangeProtocol)

/// Automatically adjust range mode based on view events if the containing node confirms to the ASRangeControllerUpdateRangeProtocol
@property (nonatomic, assign) BOOL automaticallyAdjustRangeModeBasedOnViewEvents;

@end

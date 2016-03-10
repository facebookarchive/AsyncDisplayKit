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

/// This is a way for a one way update of range with a given mode.
- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;

@end


@interface ASCollectionNode (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

@end


@interface ASTableNode (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

@end


@interface ASViewController (ASRangeControllerUpdateRangeProtocol)

/// Automatically adjust range mode based on view evenets if the containing node confirms to the ASRangeControllerUpdateRangeProtocol
@property (nonatomic, assign) BOOL automaticallyAdjustRangeModeBasedOnViewEvents;

@end

/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

/**
 @summary We want to avoid capturing layer instances on a background queue, but we want a way to cancel rendering
 immediately if another display pass begins.  ASSentinel is owned by the layer and passed to the background
 block.
 */
@interface ASSentinel : NSObject

/**
 Returns the current value of the sentinel.
 */
- (int32_t)value;

/**
 Atomically increments the value and returns the new value.
 */
- (int32_t)increment;

@end

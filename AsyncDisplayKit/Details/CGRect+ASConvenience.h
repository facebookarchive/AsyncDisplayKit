/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <CoreGraphics/CoreGraphics.h>

#import "ASBaseDefines.h"

ASDISPLAYNODE_EXTERN_C_BEGIN

CGRect asdk_CGRectExpandHorizontally(CGRect rect, CGFloat negativeMultiplier, CGFloat positiveMultiplier);
CGRect asdk_CGRectExpandVertically(CGRect rect, CGFloat negativeMultiplier, CGFloat positiveMultiplier);

ASDISPLAYNODE_EXTERN_C_END

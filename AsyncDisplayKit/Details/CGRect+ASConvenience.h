/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "ASBaseDefines.h"
#import "ASLayoutController.h"

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

CGRect CGRectExpandToRangeWithScrollableDirections(CGRect rect,
                                                   ASRangeTuningParameters tuningParameters,
                                                   ASScrollDirection scrollableDirections,
                                                   ASScrollDirection scrollDirection);

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END

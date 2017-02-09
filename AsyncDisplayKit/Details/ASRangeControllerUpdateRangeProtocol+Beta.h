//
//  ASRangeControllerUpdateRangeProtocol+Beta.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>

@protocol ASRangeControllerUpdateRangeProtocol <NSObject>

/**
 * Updates the current range mode of the range controller for at least the next range update
 * and, if the new mode is different from the previous mode, enqueues a range update.
 */
- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;

@end

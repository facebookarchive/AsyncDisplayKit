/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASPreloadRangeDelegate.h"

#import "ASDisplayNode.h"
#import "ASDisplayNode+Subclasses.h"

@implementation ASPreloadRangeDelegate

- (void)node:(ASDisplayNode *)node enteredRangeType:(ASLayoutRangeType)rangeType
{
  [node fetchRemoteData];
}

- (void)node:(ASDisplayNode *)node exitedRangeType:(ASLayoutRangeType)rangeType
{
  [node clearRemoteData];
}

@end

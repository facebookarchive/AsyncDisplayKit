/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutNode.h"
#import "ASLayoutNodeSubclass.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@implementation ASLayoutNode

#pragma mark - Layout

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout newWithNode:self size:constrainedSize.min];
}

@end

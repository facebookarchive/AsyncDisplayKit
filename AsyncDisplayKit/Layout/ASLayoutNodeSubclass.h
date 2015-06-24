/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutNode.h>
#import <AsyncDisplayKit/ASLayout.h>

@interface ASLayoutNode ()

/**
 Override this method to calculate your node's layout.

 @param constrainedSize The maximum size the receiver should fit in.

 @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

@end

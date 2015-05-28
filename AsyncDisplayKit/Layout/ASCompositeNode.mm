/*
 *  Copyright (c) 2015-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASCompositeNode.h"

#import "ASBaseDefines.h"

#import "ASDisplayNode.h"
#import "ASLayoutNodeSubclass.h"

@implementation ASCompositeNode

+ (instancetype)newWithDisplayNode:(ASDisplayNode *)displayNode
{
  return [self newWithSize:ASLayoutNodeSizeZero displayNode:displayNode];
}

+ (instancetype)newWithSize:(ASLayoutNodeSize)size displayNode:(ASDisplayNode *)displayNode
{
  if (displayNode == nil) {
    return nil;
  }
  ASCompositeNode *n = [super newWithSize:size];
  if (n) {
    n->_displayNode = displayNode;
  }
  return n;
}

+ (instancetype)newWithSize:(ASLayoutNodeSize)size
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize measuredSize = ASSizeRangeClamp(constrainedSize, [_displayNode measure:constrainedSize.max]);
  return [ASLayout newWithNode:self size:measuredSize];
}

@end
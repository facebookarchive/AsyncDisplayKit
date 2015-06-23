/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASOverlayLayoutNode.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASLayoutNodeSubclass.h"

@implementation ASOverlayLayoutNode
{
  ASLayoutNode *_overlay;
  ASLayoutNode *_node;
}

+ (instancetype)newWithNode:(ASLayoutNode *)node overlay:(ASLayoutNode *)overlay
{
  ASOverlayLayoutNode *n = [super new];
  if (n) {
    ASDisplayNodeAssertNotNil(node, @"Node that will be overlayed on shouldn't be nil");
    n->_overlay = overlay;
    n->_node = node;
  }
  return n;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 First layout the contents, then fit the overlay on top of it.
 */
- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASLayout *contentsLayout = [_node computeLayoutThatFits:constrainedSize];
  NSMutableArray *layoutChildren = [NSMutableArray arrayWithObject:[ASLayoutChild newWithPosition:{0, 0} layout:contentsLayout]];
  if (_overlay) {
    ASLayout *overlayLayout = [_overlay computeLayoutThatFits:{contentsLayout.size, contentsLayout.size}];
    [layoutChildren addObject:[ASLayoutChild newWithPosition:{0, 0} layout:overlayLayout]];
  }
  
  return [ASLayout newWithNode:self size:contentsLayout.size children:layoutChildren];
}

@end

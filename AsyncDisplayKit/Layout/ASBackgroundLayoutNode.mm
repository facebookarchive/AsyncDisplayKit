/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASBackgroundLayoutNode.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASLayoutNodeSubclass.h"

@interface ASBackgroundLayoutNode ()
{
  ASLayoutNode *_node;
  ASLayoutNode *_background;
}
@end

@implementation ASBackgroundLayoutNode

+ (instancetype)newWithNode:(ASLayoutNode *)node background:(ASLayoutNode *)background
{
  if (node == nil) {
    return nil;
  }
  ASBackgroundLayoutNode *n = [super new];
  n->_node = node;
  n->_background = background;
  return n;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 First layout the contents, then fit the background image.
 */
- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASLayout *contentsLayout = [_node computeLayoutThatFits:constrainedSize];

  NSMutableArray *children = [NSMutableArray arrayWithCapacity:2];
  if (_background) {
    // Size background to exactly the same size.
    ASLayout *backgroundLayout = [_background computeLayoutThatFits:{contentsLayout.size, contentsLayout.size}];
    [children addObject:[ASLayoutChild newWithPosition:{0,0} layout:backgroundLayout]];
  }
  [children addObject:[ASLayoutChild newWithPosition:{0,0} layout:contentsLayout]];

  return [ASLayout newWithNode:self size:contentsLayout.size children:children];
}

@end

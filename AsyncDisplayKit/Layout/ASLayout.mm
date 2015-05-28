 /*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayout.h"

@implementation ASLayout

+ (instancetype)newWithNode:(ASLayoutNode *)node size:(CGSize)size children:(NSArray *)children
{
  ASLayout *l = [super new];
  if (l) {
    l->_node = node;
    l->_size = size;
    l->_children = [children copy];
  }
  return l;
}

+ (instancetype)newWithNode:(ASLayoutNode *)node size:(CGSize)size
{
  return [self newWithNode:node size:size children:nil];
}

@end

@implementation ASLayoutChild

+ (instancetype)newWithPosition:(CGPoint)position layout:(ASLayout *)layout
{
  ASLayoutChild *c = [super new];
  if (c) {
    c->_position = position;
    c->_layout = layout;
  }
  return c;
}

@end

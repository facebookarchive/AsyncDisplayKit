/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStaticLayoutNode.h"

#import "ASLayoutNodeUtilities.h"
#import "ASLayoutNodeSubclass.h"
#import "ASInternalHelpers.h"

@implementation ASStaticLayoutNodeChild

+ (instancetype)newWithPosition:(CGPoint)position node:(ASLayoutNode *)node size:(ASRelativeSizeRange)size
{
  ASStaticLayoutNodeChild *c = [super new];
  if (c) {
    c->_position = position;
    c->_node = node;
    c->_size = size;
  }
  return c;
}

+ (instancetype)newWithPosition:(CGPoint)position node:(ASLayoutNode *)node
{
  return [self newWithPosition:position node:node size:{}];
}

@end

@implementation ASStaticLayoutNode
{
  NSArray *_children;
}

+ (instancetype)newWithSize:(ASLayoutNodeSize)size
                   children:(NSArray *)children
{
  ASStaticLayoutNode *n = [super newWithSize:size];
  if (n) {
    n->_children = children;
  }
  return n;
}

+ (instancetype)newWithChildren:(NSArray *)children
{
  return [self newWithSize:{} children:children];
}

- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize size = {
    isinf(constrainedSize.max.width) ? kASLayoutNodeParentDimensionUndefined : constrainedSize.max.width,
    isinf(constrainedSize.max.height) ? kASLayoutNodeParentDimensionUndefined : constrainedSize.max.height
  };

  NSMutableArray *layoutChildren = [NSMutableArray arrayWithCapacity:_children.count];
  for (ASStaticLayoutNodeChild *child in _children) {
    CGSize autoMaxSize = {
      constrainedSize.max.width - child.position.x,
      constrainedSize.max.height - child.position.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeResolveSizeRange(child.size, size, {{0,0}, autoMaxSize});
    ASLayoutChild *layoutChild = [ASLayoutChild newWithPosition:child.position
                                                         layout:[child.node layoutThatFits:childConstraint parentSize: size]];
    [layoutChildren addObject:layoutChild];
  }
  
  if (isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayoutChild *child in layoutChildren) {
      size.width = MAX(size.width, child.position.x + child.layout.size.width);
    }
  }

  if (isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayoutChild *child in layoutChildren) {
      size.height = MAX(size.height, child.position.y + child.layout.size.height);
    }
  }

  return [ASLayout newWithNode:self size:ASSizeRangeClamp(constrainedSize, size) children:layoutChildren];
}

@end

/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStaticLayoutSpec.h"

#import "ASLayoutSpecUtilities.h"
#import "ASInternalHelpers.h"

@implementation ASStaticLayoutSpecChild

+ (instancetype)newWithPosition:(CGPoint)position layoutableObject:(id<ASLayoutable>)layoutableObject size:(ASRelativeSizeRange)size
{
  ASStaticLayoutSpecChild *c = [super new];
  if (c) {
    c->_position = position;
    c->_layoutableObject = layoutableObject;
    c->_size = size;
  }
  return c;
}

+ (instancetype)newWithPosition:(CGPoint)position layoutableObject:(id<ASLayoutable>)layoutableObject
{
  return [self newWithPosition:position layoutableObject:layoutableObject size:ASRelativeSizeRangeUnconstrained];
}

@end

@implementation ASStaticLayoutSpec
{
  NSArray *_children;
}

+ (instancetype)newWithChildren:(NSArray *)children
{
  ASStaticLayoutSpec *spec = [super new];
  if (spec) {
    spec->_children = children;
  }
  return spec;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGSize size = {
    constrainedSize.max.width,
    constrainedSize.max.height
  };

  NSMutableArray *layoutChildren = [NSMutableArray arrayWithCapacity:_children.count];
  for (ASStaticLayoutSpecChild *child in _children) {
    CGSize autoMaxSize = {
      constrainedSize.max.width - child.position.x,
      constrainedSize.max.height - child.position.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, child.size)
      ? ASSizeRangeMake({0, 0}, autoMaxSize)
      : ASRelativeSizeRangeResolve(child.size, size);
    ASLayout *childLayout = [child.layoutableObject calculateLayoutThatFits:childConstraint];
    childLayout.position = child.position;
    [layoutChildren addObject:childLayout];
  }
  
  if (isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayout *child in layoutChildren) {
      size.width = MAX(size.width, child.position.x + child.size.width);
    }
  }

  if (isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayout *child in layoutChildren) {
      size.height = MAX(size.height, child.position.y + child.size.height);
    }
  }

  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, size)
                                  children:layoutChildren];
}

@end

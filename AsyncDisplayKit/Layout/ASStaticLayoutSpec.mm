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
#import "ASLayout.h"

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

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  CGSize size = {
    constrainedSize.max.width,
    constrainedSize.max.height
  };

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:_children.count];
  for (ASStaticLayoutSpecChild *child in _children) {
    CGSize autoMaxSize = {
      constrainedSize.max.width - child.position.x,
      constrainedSize.max.height - child.position.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, child.size)
      ? ASSizeRangeMake({0, 0}, autoMaxSize)
      : ASRelativeSizeRangeResolve(child.size, size);
    ASLayout *sublayout = [child.layoutableObject measureWithSizeRange:childConstraint];
    sublayout.position = child.position;
    [sublayouts addObject:sublayout];
  }
  
  if (isnan(size.width)) {
    size.width = constrainedSize.min.width;
    for (ASLayout *sublayout in sublayouts) {
      size.width = MAX(size.width, sublayout.position.x + sublayout.size.width);
    }
  }

  if (isnan(size.height)) {
    size.height = constrainedSize.min.height;
    for (ASLayout *sublayout in sublayouts) {
      size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
    }
  }

  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, size)
                                sublayouts:sublayouts];
}

@end

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
#import "ASAssert.h"

CGPoint const CGPointNull = {NAN, NAN};

extern BOOL CGPointIsNull(CGPoint point)
{
  return isnan(point.x) && isnan(point.y);
}

@implementation ASLayout

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               position:(CGPoint)position
                               children:(NSArray *)children
{
  for (ASLayout *child in children) {
    ASDisplayNodeAssert(!CGPointIsNull(child.position), @"Invalid position is not allowed in children.");
  }
  
  ASLayout *l = [super new];
  if (l) {
    l->_layoutableObject = layoutableObject;
    l->_size = size;
    l->_position = position;
    l->_children = [children copy];
  }
  return l;
}

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               children:(NSArray *)children
{
  return [self newWithLayoutableObject:layoutableObject size:size position:CGPointNull children:children];
}

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject size:(CGSize)size
{
  return [self newWithLayoutableObject:layoutableObject size:size children:nil];
}

- (void)setPosition:(CGPoint)position
{
  ASDisplayNodeAssert(CGPointIsNull(_position), @"Position can be set once and only once.");
  ASDisplayNodeAssert(!CGPointIsNull(position), @"Position must not be set to null.");
  _position = position;
}

@end

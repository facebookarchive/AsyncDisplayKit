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
#import "ASLayoutSpecUtilities.h"
#import <stack>

CGPoint const CGPointNull = {NAN, NAN};

extern BOOL CGPointIsNull(CGPoint point)
{
  return isnan(point.x) && isnan(point.y);
}

@implementation ASLayout

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                      size:(CGSize)size
                                  position:(CGPoint)position
                                sublayouts:(NSArray *)sublayouts
{
  ASDisplayNodeAssert(layoutableObject, @"layoutableObject is required.");
#if DEBUG
  for (ASLayout *sublayout in sublayouts) {
    ASDisplayNodeAssert(!CGPointIsNull(sublayout.position), @"Invalid position is not allowed in sublayout.");
  }
#endif
  
  ASLayout *l = [super new];
  if (l) {
    l->_layoutableObject = layoutableObject;
    l->_size = size;
    l->_position = position;
    l->_sublayouts = [sublayouts copy];
  }
  return l;
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                      size:(CGSize)size
                                sublayouts:(NSArray *)sublayouts
{
  return [self layoutWithLayoutableObject:layoutableObject size:size position:CGPointNull sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject size:(CGSize)size
{
  return [self layoutWithLayoutableObject:layoutableObject size:size sublayouts:nil];
}

- (ASLayout *)flattenedLayoutUsingPredicateBlock:(BOOL (^)(ASLayout *))predicateBlock
{
  NSMutableArray *flattenedSublayouts = [NSMutableArray array];
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
    BOOL visited;
  };
  
  // Stack of Contexts, used to keep track of sublayouts while traversing this layout in a DFS fashion.
  std::stack<Context> stack;
  stack.push({self, CGPointMake(0, 0), NO});
  
  while (!stack.empty()) {
    Context &context = stack.top();
    if (context.visited) {
      stack.pop();
    } else {
      context.visited = YES;
      
      if (predicateBlock(context.layout)) {
        [flattenedSublayouts addObject:[ASLayout layoutWithLayoutableObject:context.layout.layoutableObject
                                                                       size:context.layout.size
                                                                   position:context.absolutePosition
                                                                 sublayouts:nil]];
      }
      
      for (ASLayout *sublayout in context.layout.sublayouts) {
        stack.push({sublayout, context.absolutePosition + sublayout.position, NO});
      }
    }
  }
  
  return [ASLayout layoutWithLayoutableObject:_layoutableObject size:_size sublayouts:flattenedSublayouts];
}

@end

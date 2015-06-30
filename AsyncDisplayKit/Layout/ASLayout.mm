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
#import "ASLayoutNodeUtilities.h"
#import <stack>

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
  ASDisplayNodeAssert(layoutableObject, @"layoutableObject is required.");
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

- (ASLayout *)flattenedLayoutUsingPredicateBlock:(BOOL (^)(ASLayout *))predicateBlock
{
  NSMutableArray *flattenedChildren = [NSMutableArray array];
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
    BOOL visited;
  };
  
  // Stack of Contexts, used to keep track of sub layouts while traversing the calculated layout in a DFS fashion.
  std::stack<Context> stack;
  stack.push({self, CGPointMake(0, 0), NO});
  
  while (!stack.empty()) {
    Context &context = stack.top();
    if (context.visited) {
      stack.pop();
    } else {
      context.visited = YES;
      
      if (predicateBlock(context.layout)) {
        [flattenedChildren addObject:[ASLayout newWithLayoutableObject:context.layout.layoutableObject
                                                                  size:context.layout.size
                                                              position:context.absolutePosition
                                                              children:nil]];
      }
      
      for (ASLayout *child in context.layout.children) {
        stack.push({child, context.absolutePosition + child.position, NO});
      }
    }
  }
  
  return [ASLayout newWithLayoutableObject:_layoutableObject size:_size children:flattenedChildren];
}

@end

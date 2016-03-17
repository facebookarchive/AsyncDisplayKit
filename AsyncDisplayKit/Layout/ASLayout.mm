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
#import "ASInternalHelpers.h"
#import <queue>

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
                                 flattened:(BOOL)flattened
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
    l->_size = CGSizeMake(ASCeilPixelValue(size.width), ASCeilPixelValue(size.height));
    if (CGPointIsNull(position) == NO) {
      l->_position = CGPointMake(ASCeilPixelValue(position.x), ASCeilPixelValue(position.y));
    } else {
      l->_position = position;
    }
    l->_sublayouts = [sublayouts copy];
    l->_flattened = flattened;
    
    NSMutableArray<ASLayout *> *result = [NSMutableArray array];
    for (ASLayout *sublayout in l->_sublayouts) {
      if (!sublayout.isFlattened) {
        [result addObject:sublayout];
      }
    }
    l->_immediateSublayouts = result;
  }
  return l;
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                      size:(CGSize)size
                                sublayouts:(NSArray *)sublayouts
{
  return [self layoutWithLayoutableObject:layoutableObject size:size position:CGPointNull sublayouts:sublayouts flattened:NO];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject size:(CGSize)size
{
  return [self layoutWithLayoutableObject:layoutableObject size:size sublayouts:nil];
}

+ (instancetype)flattenedLayoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                               size:(CGSize)size
                                         sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutableObject:layoutableObject size:size position:CGPointNull sublayouts:sublayouts flattened:YES];
}

- (ASLayout *)flattenedLayoutUsingPredicateBlock:(BOOL (^)(ASLayout *))predicateBlock
{
  NSMutableArray *flattenedSublayouts = [NSMutableArray array];
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
    BOOL visited;
    BOOL flattened;
  };
  
  // Queue used to keep track of sublayouts while traversing this layout in a BFS fashion.
  std::queue<Context> queue;
  queue.push({self, CGPointMake(0, 0), NO, NO});
  
  while (!queue.empty()) {
    Context &context = queue.front();
    if (context.visited) {
      queue.pop();
    } else {
      context.visited = YES;
      
      if (predicateBlock(context.layout)) {
        [flattenedSublayouts addObject:[ASLayout layoutWithLayoutableObject:context.layout.layoutableObject
                                                                       size:context.layout.size
                                                                   position:context.absolutePosition
                                                                 sublayouts:nil
                                                                  flattened:context.flattened]];
      }
      
      for (ASLayout *sublayout in context.layout.sublayouts) {
        // Mark layout trees that have already been flattened for future identification of immediate sublayouts
        BOOL flattened = context.flattened ? : context.layout.flattened;
        queue.push({sublayout, context.absolutePosition + sublayout.position, NO, flattened});
      }
    }
  }

  return [ASLayout flattenedLayoutWithLayoutableObject:_layoutableObject size:_size sublayouts:flattenedSublayouts];
}

- (CGRect)frame
{
  CGRect subnodeFrame = CGRectZero;
  CGPoint adjustedOrigin = _position;
  if (isfinite(adjustedOrigin.x) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.x = 0;
  }
  if (isfinite(adjustedOrigin.y) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedOrigin.y = 0;
  }
  subnodeFrame.origin = adjustedOrigin;
  
  CGSize adjustedSize = _size;
  if (isfinite(adjustedSize.width) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid size");
    adjustedSize.width = 0;
  }
  if (isfinite(adjustedSize.height) == NO) {
    ASDisplayNodeAssert(0, @"Layout has an invalid position");
    adjustedSize.height = 0;
  }
  subnodeFrame.size = adjustedSize;
  
  return subnodeFrame;
}

@end

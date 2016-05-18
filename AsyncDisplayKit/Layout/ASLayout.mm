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

+ (instancetype)layoutWithProducer:(id<ASLayoutProducer>)producer
                              size:(CGSize)size
                          position:(CGPoint)position
                        sublayouts:(NSArray *)sublayouts
                         flattened:(BOOL)flattened
{
  ASDisplayNodeAssert(producer, @"producer is required.");
#if DEBUG
  for (ASLayout *sublayout in sublayouts) {
    ASDisplayNodeAssert(!CGPointIsNull(sublayout.position), @"Invalid position is not allowed in sublayout.");
  }
#endif
  
  ASLayout *l = [super new];
  if (l) {
    l->_layoutProducer = producer;
    
    if (!isValidForLayout(size.width) || !isValidForLayout(size.height)) {
      ASDisplayNodeAssert(NO, @"layoutSize is invalid and unsafe to provide to Core Animation!  Production will force to 0, 0.  Size = %@, node = %@", NSStringFromCGSize(size), producer);
      size = CGSizeZero;
    } else {
      size = CGSizeMake(ASCeilPixelValue(size.width), ASCeilPixelValue(size.height));
    }
    l->_size = size;
    
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

+ (instancetype)layoutWithProducer:(id<ASLayoutProducer>)producer
                              size:(CGSize)size
                        sublayouts:(NSArray *)sublayouts
{
  return [self layoutWithProducer:producer size:size position:CGPointNull sublayouts:sublayouts flattened:NO];
}

+ (instancetype)layoutWithProducer:(id<ASLayoutProducer>)producer size:(CGSize)size
{
  return [self layoutWithProducer:producer size:size sublayouts:nil];
}

+ (instancetype)flattenedLayoutWithProducer:(id<ASLayoutProducer>)producer
                                       size:(CGSize)size
                                 sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithProducer:producer size:size position:CGPointNull sublayouts:sublayouts flattened:YES];
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
        [flattenedSublayouts addObject:[ASLayout layoutWithProducer:context.layout.layoutProducer
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

  return [ASLayout flattenedLayoutWithProducer:_layoutProducer size:_size sublayouts:flattenedSublayouts];
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

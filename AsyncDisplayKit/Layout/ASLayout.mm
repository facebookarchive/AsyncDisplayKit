//
//  ASLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayout.h"

#import "ASInternalHelpers.h"
#import "ASLayoutSpecUtilities.h"

#import <queue>

CGPoint const CGPointNull = {NAN, NAN};

extern BOOL CGPointIsNull(CGPoint point)
{
  return isnan(point.x) && isnan(point.y);
}

@interface ASLayout ()

/**
 * A boolean describing if the current layout has been flattened.
 */
@property (nonatomic, getter=isFlattened) BOOL flattened;

@end

@implementation ASLayout

@dynamic frame, type;

- (instancetype)initWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                    constrainedSizeRange:(ASSizeRange)sizeRange
                                    size:(CGSize)size
                                position:(CGPoint)position
                              sublayouts:(NSArray *)sublayouts
{
  self = [super init];
  if (self) {
    NSParameterAssert(layoutableObject);
#if DEBUG
    for (ASLayout *sublayout in sublayouts) {
      ASDisplayNodeAssert(CGPointIsNull(sublayout.position) == NO, @"Invalid position is not allowed in sublayout.");
    }
#endif
    
    _layoutableObject = layoutableObject;
    
    if (!isValidForLayout(size.width) || !isValidForLayout(size.height)) {
      ASDisplayNodeAssert(NO, @"layoutSize is invalid and unsafe to provide to Core Animation!  Production will force to 0, 0.  Size = %@, node = %@", NSStringFromCGSize(size), layoutableObject);
      size = CGSizeZero;
    } else {
      size = CGSizeMake(ASCeilPixelValue(size.width), ASCeilPixelValue(size.height));
    }
    _constrainedSizeRange = sizeRange;
    _size = size;
    _dirty = NO;
    
    if (CGPointIsNull(position) == NO) {
      _position = CGPointMake(ASCeilPixelValue(position.x), ASCeilPixelValue(position.y));
    } else {
      _position = position;
    }
    _sublayouts = sublayouts != nil ? [sublayouts copy] : @[];
    _flattened = NO;
  }
  return self;
}

- (instancetype)init
{
  ASDisplayNodeAssert(NO, @"Use the designated initializer");
  return [self init];
}

#pragma mark - Class Constructors

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                      constrainedSizeRange:(ASSizeRange)sizeRange
                                      size:(CGSize)size
                                  position:(CGPoint)position
                                sublayouts:(NSArray *)sublayouts
{
  return [[self alloc] initWithLayoutableObject:layoutableObject
                           constrainedSizeRange:sizeRange
                                           size:size
                                       position:position
                                     sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                      constrainedSizeRange:(ASSizeRange)sizeRange
                                      size:(CGSize)size
                                sublayouts:(NSArray *)sublayouts
{
  return [self layoutWithLayoutableObject:layoutableObject
                     constrainedSizeRange:sizeRange
                                     size:size
                                 position:CGPointNull
                               sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                      constrainedSizeRange:(ASSizeRange)sizeRange
                                      size:(CGSize)size
{
  return [self layoutWithLayoutableObject:layoutableObject
                     constrainedSizeRange:sizeRange
                                     size:size
                               sublayouts:nil];
}

+ (instancetype)flattenedLayoutWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                               constrainedSizeRange:(ASSizeRange)sizeRange
                                               size:(CGSize)size
                                         sublayouts:(nullable NSArray<ASLayout *> *)sublayouts
{
  return [self layoutWithLayoutableObject:layoutableObject
                     constrainedSizeRange:sizeRange
                                     size:size
                                 position:CGPointNull
                               sublayouts:sublayouts];
}

+ (instancetype)layoutWithLayout:(ASLayout *)layout position:(CGPoint)position
{
  return [self layoutWithLayoutableObject:layout.layoutableObject
                     constrainedSizeRange:layout.constrainedSizeRange
                                     size:layout.size
                                 position:position
                               sublayouts:layout.sublayouts];
}

#pragma mark - Layout Flattening

- (ASLayout *)filteredNodeLayoutTree
{
  NSMutableArray *flattenedSublayouts = [NSMutableArray array];
  
  struct Context {
    ASLayout *layout;
    CGPoint absolutePosition;
  };
  
  // Queue used to keep track of sublayouts while traversing this layout in a BFS fashion.
  std::queue<Context> queue;
  queue.push({self, CGPointMake(0, 0)});
  
  while (!queue.empty()) {
    Context context = queue.front();
    queue.pop();

    if (self != context.layout && context.layout.type == ASLayoutableTypeDisplayNode) {
      ASLayout *layout = [ASLayout layoutWithLayout:context.layout position:context.absolutePosition];
      layout.flattened = YES;
      [flattenedSublayouts addObject:layout];
    }
    
    for (ASLayout *sublayout in context.layout.sublayouts) {
      if (sublayout.isFlattened == NO) {
        queue.push({sublayout, context.absolutePosition + sublayout.position});
      }
    }
  }

  return [ASLayout layoutWithLayoutableObject:_layoutableObject
                         constrainedSizeRange:_constrainedSizeRange
                                         size:_size
                                   sublayouts:flattenedSublayouts];
}

#pragma mark - Accessors

- (ASLayoutableType)type
{
  return _layoutableObject.layoutableType;
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

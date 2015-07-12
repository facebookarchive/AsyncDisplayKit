/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASLayoutable.h>

extern CGPoint const CGPointNull;

extern BOOL CGPointIsNull(CGPoint point);

/** Represents a computed immutable layout tree. */
@interface ASLayout : NSObject

@property (nonatomic, weak, readonly) id<ASLayoutable> layoutableObject;
@property (nonatomic, readonly) CGSize size;
/**
 * Position in parent. Default to CGPointNull.
 * 
 * @discussion When being used as a sublayout, this property must not equal CGPointNull.
 */
@property (nonatomic, readwrite) CGPoint position;
/** 
 * Array of ASLayouts. Each must have a valid non-null position.
 */
@property (nonatomic, readonly) NSArray *sublayouts;

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               position:(CGPoint)position
                             sublayouts:(NSArray *)sublayouts;

/**
 * Convenience that has CGPointNull position. 
 * Best used by ASDisplayNode subclasses that are manually creating a layout for -calculateLayoutThatFits:,
 * or for ASLayoutSpec subclasses that are referencing the "self" level in the layout tree,
 * or for creating a sublayout of which the position is yet to be determined.
 */
+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                             sublayouts:(NSArray *)sublayouts;

/**
 * Convenience that has CGPointNull position and no sublayouts. 
 * Best used for creating a layout that has no sublayouts, and is either a root one
 * or a sublayout of which the position is yet to be determined.
 */
+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject size:(CGSize)size;


/**
 * @abstract Evaluates a given predicate block against each object in the receiving layout tree
 * and returns a new, 1-level deep layout containing the objects for which the predicate block returns true.
 *
 * @param predicateBlock The block is applied to a layout to be evaluated. 
 * The block takes 1 argument: evaluatedLayout - the layout to be evaluated.
 * The block returns YES if evaluatedLayout evaluates  to true, otherwise NO.
 *
 * @return A new, 1-level deep layout containing the layouts for which the predicate block returns true.
 */
- (ASLayout *)flattenedLayoutUsingPredicateBlock:(BOOL (^)(ASLayout *evaluatedLayout))predicateBlock;

@end

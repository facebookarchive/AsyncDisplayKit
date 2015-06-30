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

@property (nonatomic, readonly) id<ASLayoutable> layoutableObject;
@property (nonatomic, readonly) CGSize size;
/**
 * Position parent (if any). Default to CGPointNull.
 * 
 * @discussion Before being used as a child layout, this property must be set and no longer equal CGPointNull.
 *
 * @discussion Unlike all other properties, this property is read-write because often by initializaion time, it has yet been determined.
 * To enforce immutability, this property can be set once and only once.
 *
 */
@property (nonatomic, readwrite) CGPoint position;
/** 
 * Array of ASLayout children. Each child must have a valid non-null position.
 */
@property (nonatomic, readonly) NSArray *children;

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               position:(CGPoint)position
                               children:(NSArray *)children;

/**
 * Convenience that has CGPointNull position.
 */
+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               children:(NSArray *)children;

/**
 * Convenience that has CGPointNull position and no children.
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
 * @return A new, 1-level deep layout containing the layout children for which the predicate block returns true.
 */
- (ASLayout *)flattenedLayoutUsingPredicateBlock:(BOOL (^)(ASLayout *evaluatedLayout))predicateBlock;

@end

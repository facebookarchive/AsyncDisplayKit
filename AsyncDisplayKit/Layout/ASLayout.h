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

/** Represents the computed size of a layout node, as well as the computed sizes and positions of its children. */
@interface ASLayout : NSObject

@property (nonatomic, readonly) id<ASLayoutable> layoutableObject;
@property (nonatomic, readonly) CGSize size;
/** 
 * Each item is of type ASLayoutChild. 
 */
@property (nonatomic, readonly) NSArray *children;

+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject
                                   size:(CGSize)size
                               children:(NSArray *)children;

/**
 * Convenience that does not have any children.
 */
+ (instancetype)newWithLayoutableObject:(id<ASLayoutable>)layoutableObject size:(CGSize)size;

@end

@interface ASLayoutChild : NSObject

@property (nonatomic, readonly) CGPoint position;
@property (nonatomic, readonly) ASLayout *layout;

/**
 * Designated initializer
 */
+ (instancetype)newWithPosition:(CGPoint)position layout:(ASLayout *)layout;

@end

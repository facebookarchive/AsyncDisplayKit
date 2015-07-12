/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASRelativeSize.h>

@interface ASStaticLayoutSpecChild : NSObject

@property (nonatomic, readonly) CGPoint position;
@property (nonatomic, readonly) id<ASLayoutable> layoutableObject;

/**
 If specified, the child's size is restricted according to this size. Percentages are resolved relative to the static layout spec.
 */
@property (nonatomic, readonly) ASRelativeSizeRange size;

+ (instancetype)newWithPosition:(CGPoint)position layoutableObject:(id<ASLayoutable>)layoutableObject size:(ASRelativeSizeRange)size;

/**
 Convenience with default size is Unconstrained in both dimensions, which sets the child's min size to zero 
 and max size to the maximum available space it can consume without overflowing the spec's bounds.
 */
+ (instancetype)newWithPosition:(CGPoint)position layoutableObject:(id<ASLayoutable>)layoutableObject;

@end

/*
 A layout spec that positions children at fixed positions.

 Computes a size that is the union of all childrens' frames.
 */
@interface ASStaticLayoutSpec : ASLayoutSpec

/**
 @param children Children to be positioned at fixed positions, each is of type ASStaticLayoutSpecChild.
 */
+ (instancetype)newWithChildren:(NSArray *)children;

@end

/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutNode.h>
#import <AsyncDisplayKit/ASStaticLayoutNodeDimension.h>

@interface ASStaticLayoutNodeChild : NSObject

@property (nonatomic, readonly) CGPoint position;
@property (nonatomic, readonly) ASLayoutNode *node;

/**
 If specified, the node's size is restricted according to this size. Percentages are resolved relative to the
 static layout node.
 */
@property (nonatomic, readonly) ASRelativeSizeRange size;

+ (instancetype)newWithPosition:(CGPoint)position node:(ASLayoutNode *)node size:(ASRelativeSizeRange)size;

/**
 Convenience with default size is Unconstrained in both dimensions, which sets the child's min size to zero 
 and max size to the maximum available space it can consume without overflowing the node's bounds.
 */
+ (instancetype)newWithPosition:(CGPoint)position node:(ASLayoutNode *)node;

@end

/*
 A layout node that positions children at fixed positions.

 Computes a size that is the union of all childrens' frames.
 */
@interface ASStaticLayoutNode : ASLayoutNode

/**
 @param children Children to be positioned at fixed positions, each is of type ASStaticLayoutNodeChild.
 */
+ (instancetype)newWithChildren:(NSArray *)children;

@end

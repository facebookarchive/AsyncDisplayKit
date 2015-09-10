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

/**
 * A layout spec that positions children at fixed positions.
 * 
 * Computes a size that is the union of all childrens' frames.
 */
@interface ASStaticLayoutSpec : ASLayoutSpec

/**
 @param children Children to be positioned at fixed positions, each conforms to ASStaticLayoutable
 */
+ (instancetype)staticLayoutSpecWithChildren:(NSArray *)children;

@end

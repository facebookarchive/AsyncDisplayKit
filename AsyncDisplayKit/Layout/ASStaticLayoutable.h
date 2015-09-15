/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASRelativeSize.h>

/**
 *  Layout options that can be defined for an ASLayoutable being added to a ASStaticLayoutSpec. 
 */
@protocol ASStaticLayoutable

/**
 If specified, the child's size is restricted according to this size. Percentages are resolved relative to the static layout spec.
 */
@property (nonatomic, assign) ASRelativeSizeRange sizeRange;

/** The position of this object within its parent spec. */
@property (nonatomic, assign) CGPoint layoutPosition;

@end

//
//  ASStaticLayoutable.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASRelativeSize.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Layout options that can be defined for an ASLayoutable being added to a ASStaticLayoutSpec. 
 */
@protocol ASStaticLayoutable

/**
 * @abstract If specified, the child's size is restricted according to this size. Fractions are resolved relative to the static layout spec.
 *
 * If you define a sizeRange you have to wrap the Layoutable within a ASStaticLayoutSpec otherwise it will not have any effect.
 *
 * The default is ASRelativeDimensionUnconstrained, which sets the child's min size to zero and max size to the maximum available space it can consume without overflowing the spec's size.
 */
@property (nonatomic, assign) ASRelativeSizeRange sizeRange;

/**
 * @abstract The position of this object within its parent spec.
 */
@property (nonatomic, assign) CGPoint layoutPosition;

@end

NS_ASSUME_NONNULL_END

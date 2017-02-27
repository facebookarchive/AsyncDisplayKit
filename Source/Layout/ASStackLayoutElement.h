//
//  ASStackLayoutElement.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDimension.h>

#import <AsyncDisplayKit/ASStackLayoutDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Layout options that can be defined for an ASLayoutElement being added to a ASStackLayoutSpec.
 */
@protocol ASStackLayoutElement <NSObject>

/**
 * @abstract Additional space to place before this object in the stacking direction.
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) CGFloat spacingBefore;

/**
 * @abstract Additional space to place after this object in the stacking direction.
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) CGFloat spacingAfter;

/**
 * @abstract If the sum of childrens' stack dimensions is less than the minimum size, how much should this component grow?
 * This value represents the "flex grow factor" and determines how much this component should grow in relation to any
 * other flexible children.
 */
@property (nonatomic, readwrite) CGFloat flexGrow;

/**
 * @abstract If the sum of childrens' stack dimensions is greater than the maximum size, how much should this component shrink?
 * This value represents the "flex shrink factor" and determines how much this component should shink in relation to
 * other flexible children.
 */
@property (nonatomic, readwrite) CGFloat flexShrink;

/**
 * @abstract Specifies the initial size in the stack dimension for this object.
 * Defaults to ASDimensionAuto.
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) ASDimension flexBasis;

/**
 * @abstract Orientation of the object along cross axis, overriding alignItems.
 * Defaults to ASStackLayoutAlignSelfAuto.
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;

/**
 *  @abstract Used for baseline alignment. The distance from the top of the object to its baseline.
 */
@property (nonatomic, readwrite) CGFloat ascender;

/**
 *  @abstract Used for baseline alignment. The distance from the baseline of the object to its bottom.
 */
@property (nonatomic, readwrite) CGFloat descender;

@end

NS_ASSUME_NONNULL_END

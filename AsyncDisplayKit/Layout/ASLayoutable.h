//
//  ASLayoutable.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASRelativeSize.h>
#import <AsyncDisplayKit/ASStackLayoutDefines.h>
#import <AsyncDisplayKit/ASStackLayoutable.h>
#import <AsyncDisplayKit/ASStaticLayoutable.h>

#import <AsyncDisplayKit/ASLayoutablePrivate.h>
#import <AsyncDisplayKit/ASEnvironment.h>
#import <AsyncDisplayKit/ASLayoutableExtensibility.h>

@class ASLayout;
@class ASLayoutSpec;

/** A constant that indicates that the parent's size is not yet determined in a given dimension. */
extern CGFloat const ASLayoutableParentDimensionUndefined;

/** A constant that indicates that the parent's size is not yet determined in either dimension. */
extern CGSize const ASLayoutableParentSizeUndefined;

/** Type of ASLayoutable  */
typedef NS_ENUM(NSUInteger, ASLayoutableType) {
  ASLayoutableTypeLayoutSpec,
  ASLayoutableTypeDisplayNode
};

NS_ASSUME_NONNULL_BEGIN

/** 
 * The ASLayoutable protocol declares a method for measuring the layout of an object. A layout
 * is defined by an ASLayout return value, and must specify 1) the size (but not position) of the
 * layoutable object, and 2) the size and position of all of its immediate child objects. The tree 
 * recursion is driven by parents requesting layouts from their children in order to determine their 
 * size, followed by the parents setting the position of the children once the size is known
 *
 * The protocol also implements a "family" of Layoutable protocols. These protocols contain layout 
 * options that can be used for specific layout specs. For example, ASStackLayoutSpec has options
 * defining how a layoutable should shrink or grow based upon available space.
 *
 * These layout options are all stored in an ASLayoutOptions class (that is defined in ASLayoutablePrivate).
 * Generally you needn't worry about the layout options class, as the layoutable protocols allow all direct
 * access to the options via convenience properties. If you are creating custom layout spec, then you can
 * extend the backing layout options class to accommodate any new layout options.
 */
@protocol ASLayoutable <ASEnvironment, ASStackLayoutable, ASStaticLayoutable, ASLayoutablePrivate, ASLayoutableExtensibility>

/**
 * @abstract A size constraint that should apply to this ASLayoutable.
 */
@property (nonatomic, assign, readwrite) ASRelativeSizeRange size;

/**
 * @abstract Returns type of layoutable
 */
@property (nonatomic, assign, readonly) ASLayoutableType layoutableType;

/**
 * @abstract Returns if the layoutable can be used to layout in an asynchronous way on a background thread.
 */
@property (nonatomic, assign, readonly) BOOL canLayoutAsynchronous;


#pragma mark - Calculate layout

/**
 * Call this on children layoutables to compute their layouts within your implementation of -calculateLayoutThatFits:.
 *
 * @warning You may not override this method. Override -calculateLayoutThatFits: instead.
 * @warning In almost all cases, prefer the use of ASCalculateLayout in ASLayout
 *
 * @param constrainedSize Specifies a minimum and maximum size. The receiver must choose a size that is in this range.
 * @param parentSize The parent node's size. If the parent component does not have a final size in a given dimension,
 *                  then it should be passed as ASLayoutableParentDimensionUndefined (for example, if the parent's width
 *                  depends on the child's size).
 *
 * @return A struct defining the layout of the receiver and its children.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize;

/**
 * Override this method to compute your nodes's layout.
 *
 * @discussion Why do you need to override -calculateLayoutThatFits: instead of -calculateLayoutThatFits:parentSize:?
 * The base implementation of -calculateLayoutThatFits:parentSize: does the following for you:
 * 1. First, it uses the parentSize parameter to resolve the nodes's size (the one assigned to the sizeRange property).
 * 2. Then, it intersects the resolved size with the constrainedSize parameter. If the two don't intersect,
 *    constrainedSize wins. This allows a component to always override its childrens' sizes when computing its layout.
 *    (The analogy for UIView: you might return a certain size from -sizeThatFits:, but a parent view can always override
 *    that size and set your frame to any size.)
 *
 * @param constrainedSize A min and max size. This is computed as described in the description. The ASLayout you
 *                        return MUST have a size between these two sizes.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 * ASLayoutable's implementation of -calculateLayoutThatFits:parentSize: calls this method to resolve the component's size
 * against parentSize, intersect it with constrainedSize, and call -calculateLayoutThatFits: with the result.
 *
 * In certain advanced cases, you may want to customize this logic. Overriding this method allows you to receive all
 * three parameters and do the computation yourself.
 *
 * @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                restrictedToSizeRange:(ASRelativeSizeRange)size
                 relativeToParentSize:(CGSize)parentSize;



#pragma mark - Layout options from the Layoutable Protocols


#pragma mark - ASStackLayoutable
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
 * @abstract If the sum of childrens' stack dimensions is less than the minimum size, should this object grow?
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) BOOL flexGrow;

/**
 * @abstract If the sum of childrens' stack dimensions is greater than the maximum size, should this object shrink?
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) BOOL flexShrink;

/**
 * @abstract Specifies the initial size in the stack dimension for this object.
 * Default to ASRelativeDimensionUnconstrained.
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) ASRelativeDimension flexBasis;

/**
 * @abstract Orientation of the object along cross axis, overriding alignItems
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


#pragma mark - ASStaticLayoutable

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


#pragma mark - Deprecated

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize; //ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

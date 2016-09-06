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
 * @abstract Returns type of layoutable
 */
@property (nonatomic, assign, readonly) ASLayoutableType layoutableType;

/**
 * @abstract Returns if the layoutable can be used to layout in an asynchronous way on a background thread.
 */
@property (nonatomic, assign, readonly) BOOL canLayoutAsynchronous;

#pragma mark - Sizing

/**
 * @abstract The width property specifies the height of the content area of an ASLayoutable.
 * The minWidth and maxWidth properties override width.
 * Defaults to ASRelativeDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension width;

/**
 * @abstract The height property specifies the height of the content area of an ASLayoutable
 * The minHeight and maxHeight properties override height.
 * Defaults to ASDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension height;

/**
 * @abstract The minHeight property is used to set the minimum height of a given element. It prevents the used value
 * of the height property from becoming smaller than the value specified for minHeight.
 * The value of minHeight overrides both maxHeight and height.
 * Defaults to ASDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension minHeight;

/**
 * @abstract The maxHeight property is used to set the maximum height of an element. It prevents the used value of the
 * height property from becoming larger than the value specified for maxHeight.
 * The value of maxHeight overrides height, but minHeight overrides maxHeight.
 * Defaults to ASDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension maxHeight;

/**
 * @abstract The minWidth property is used to set the minimum width of a given element. It prevents the used value of
 * the width property from becoming smaller than the value specified for minWidth.
 * The value of minWidth overrides both maxWidth and width.
 * Defaults to ASDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension minWidth;

/**
 * @abstract The maxWidth property is used to set the maximum width of a given element. It prevents the used value of
 * the width property from becoming larger than the value specified for maxWidth.
 * The value of maxWidth overrides width, but minWidth overrides maxWidth.
 * Defaults to ASDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension maxWidth;

/**
 * @abstract Set max and width properties from given size
 */
- (void)setSizeWithCGSize:(CGSize)size;

/**
 * @abstract Set minHeight, maxHeight and minWidth, maxWidth properties from given size
 */
- (void)setExactSizeWithCGSize:(CGSize)size;


#pragma mark - Calculate layout

/**
 * @abstract Asks the node to return a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @warning Subclasses must not override this; it caches results from -calculateLayoutThatFits:.  Calling this method may
 * be expensive if result is not cached.
 *
 * @see [ASDisplayNode(Subclassing) calculateLayoutThatFits:]
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize;

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
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize;

/**
 * Override this method to compute your layoutable's layout.
 *
 * @discussion Why do you need to override -calculateLayoutThatFits: instead of -layoutThatFits:parentSize:?
 * The base implementation of -layoutThatFits:parentSize: does the following for you:
 * 1. First, it uses the parentSize parameter to resolve the nodes's size (the one assigned to the size property).
 * 2. Then, it intersects the resolved size with the constrainedSize parameter. If the two don't intersect,
 *    constrainedSize wins. This allows a component to always override its childrens' sizes when computing its layout.
 *    (The analogy for UIView: you might return a certain size from -sizeThatFits:, but a parent view can always override
 *    that size and set your frame to any size.)
 * 3. It caches it result for reuse
 *
 * @param constrainedSize A min and max size. This is computed as described in the description. The ASLayout you
 *                        return MUST have a size between these two sizes.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 * In certain advanced cases, you may want to override this method. Overriding this method allows you to receive the
 * layoutable's size, parentSize, and constrained size. With these values you could calculate the final constrained size
 * and call -calculateLayoutThatFits: with the result.
 *
 * @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutableSize)size
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
 * Default to ASRelativeDimensionAuto
 * Used when attached to a stack layout.
 */
@property (nonatomic, readwrite) ASDimension flexBasis;

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
 *
 * @deprecated Deprecated in version 2.0: Use ASCalculateRootLayout or ASCalculateLayout instead
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

//
//  ASLayoutElement.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASStackLayoutDefines.h>
#import <AsyncDisplayKit/ASStackLayoutElement.h>
#import <AsyncDisplayKit/ASAbsoluteLayoutElement.h>
#import <AsyncDisplayKit/ASLayoutElementPrivate.h>
#import <AsyncDisplayKit/ASEnvironment.h>
#import <AsyncDisplayKit/ASLayoutElementExtensibility.h>

@class ASLayout;
@class ASLayoutSpec;

/** A constant that indicates that the parent's size is not yet determined in a given dimension. */
extern CGFloat const ASLayoutElementParentDimensionUndefined;

/** A constant that indicates that the parent's size is not yet determined in either dimension. */
extern CGSize const ASLayoutElementParentSizeUndefined;

/** Type of ASLayoutElement  */
typedef NS_ENUM(NSUInteger, ASLayoutElementType) {
  ASLayoutElementTypeLayoutSpec,
  ASLayoutElementTypeDisplayNode
};

NS_ASSUME_NONNULL_BEGIN

/** 
 * The ASLayoutElement protocol declares a method for measuring the layout of an object. A layout
 * is defined by an ASLayout return value, and must specify 1) the size (but not position) of the
 * layoutElement object, and 2) the size and position of all of its immediate child objects. The tree 
 * recursion is driven by parents requesting layouts from their children in order to determine their 
 * size, followed by the parents setting the position of the children once the size is known
 *
 * The protocol also implements a "family" of LayoutElement protocols. These protocols contain layout 
 * options that can be used for specific layout specs. For example, ASStackLayoutSpec has options
 * defining how a layoutElement should shrink or grow based upon available space.
 *
 * These layout options are all stored in an ASLayoutOptions class (that is defined in ASLayoutElementPrivate).
 * Generally you needn't worry about the layout options class, as the layoutElement protocols allow all direct
 * access to the options via convenience properties. If you are creating custom layout spec, then you can
 * extend the backing layout options class to accommodate any new layout options.
 */
@protocol ASLayoutElement <ASEnvironment, ASLayoutElementPrivate, ASLayoutElementExtensibility, NSFastEnumeration>

#pragma mark - Getter

/**
 * @abstract Returns type of layoutElement
 */
@property (nonatomic, assign, readonly) ASLayoutElementType layoutElementType;

/**
 * @abstract Returns if the layoutElement can be used to layout in an asynchronous way on a background thread.
 */
@property (nonatomic, assign, readonly) BOOL canLayoutAsynchronous;

/**
 * @abstract A size constraint that should apply to this ASLayoutElement.
 */
@property (nonatomic, assign, readonly) ASLayoutElementStyle *style;

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
 * Call this on children layoutElements to compute their layouts within your implementation of -calculateLayoutThatFits:.
 *
 * @warning You may not override this method. Override -calculateLayoutThatFits: instead.
 * @warning In almost all cases, prefer the use of ASCalculateLayout in ASLayout
 *
 * @param constrainedSize Specifies a minimum and maximum size. The receiver must choose a size that is in this range.
 * @param parentSize The parent node's size. If the parent component does not have a final size in a given dimension,
 *                  then it should be passed as ASLayoutElementParentDimensionUndefined (for example, if the parent's width
 *                  depends on the child's size).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 */
- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize;

/**
 * Override this method to compute your layoutElement's layout.
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
 * layoutElement's size, parentSize, and constrained size. With these values you could calculate the final constrained size
 * and call -calculateLayoutThatFits: with the result.
 *
 * @warning Overriding this method should be done VERY rarely.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize;


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

extern NSString * const ASLayoutElementStyleWidthProperty;
extern NSString * const ASLayoutElementStyleMinWidthProperty;
extern NSString * const ASLayoutElementStyleMaxWidthProperty;

extern NSString * const ASLayoutElementStyleHeightProperty;
extern NSString * const ASLayoutElementStyleMinHeightProperty;
extern NSString * const ASLayoutElementStyleMaxHeightProperty;

extern NSString * const ASLayoutElementStyleSpacingBeforeProperty;
extern NSString * const ASLayoutElementStyleSpacingAfterProperty;
extern NSString * const ASLayoutElementStyleFlexGrowProperty;
extern NSString * const ASLayoutElementStyleFlexShrinkProperty;
extern NSString * const ASLayoutElementStyleFlexBasisProperty;
extern NSString * const ASLayoutElementStyleAlignSelfProperty;
extern NSString * const ASLayoutElementStyleAscenderProperty;
extern NSString * const ASLayoutElementStyleDescenderProperty;

extern NSString * const ASLayoutElementStyleLayoutPositionProperty;

#pragma mark - ASLayoutElementStyle

@protocol ASLayoutElementStyleDelegate <NSObject>
- (void)style:(__kindof ASLayoutElementStyle *)style propertyDidChange:(NSString *)propertyName;
@end

@interface ASLayoutElementStyle : NSObject <ASStackLayoutElement, ASAbsoluteLayoutElement>

/**
 * @abstract Initializes the layoutElement style with a specified delegate
 */
- (instancetype)initWithDelegate:(id<ASLayoutElementStyleDelegate>)delegate;

/**
 * @abstract The object that acts as the delegate of the style.
 *
 * @discussion The delegate must adopt the ASLayoutElementStyleDelegate protocol. The delegate is not retained.
 */
@property (nullable, nonatomic, weak, readonly) id<ASLayoutElementStyleDelegate> delegate;

#pragma mark - Sizing

/**
 * @abstract A size constraint that should apply to this ASLayoutElement.
 */
@property (nonatomic, assign, readwrite) ASLayoutElementSize size;

/**
 * @abstract The width property specifies the height of the content area of an ASLayoutElement.
 * The minWidth and maxWidth properties override width.
 * Defaults to ASRelativeDimensionTypeAuto
 */
@property (nonatomic, assign, readwrite) ASDimension width;

/**
 * @abstract The height property specifies the height of the content area of an ASLayoutElement
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


#pragma mark - ASStackLayoutElement

/**
 * @abstract Additional space to place before this object in the stacking direction.
 * Used when attached to a stack layout.
 */
@property (nonatomic, assign) CGFloat spacingBefore;

/**
 * @abstract Additional space to place after this object in the stacking direction.
 * Used when attached to a stack layout.
 */
@property (nonatomic, assign) CGFloat spacingAfter;

/**
 * @abstract If the sum of childrens' stack dimensions is less than the minimum size, how much should this component grow?
 * This value represents the "flex grow factor" and determines how much this component should grow in relation to any
 * other flexible children.
 */
@property (nonatomic, assign) CGFloat flexGrow;

/**
 * @abstract If the sum of childrens' stack dimensions is greater than the maximum size, how much should this component shrink?
 * This value represents the "flex shrink factor" and determines how much this component should shink in relation to
 * other flexible children.
 */
@property (nonatomic, assign) CGFloat flexShrink;

/**
 * @abstract Specifies the initial size in the stack dimension for this object.
 * Default to ASRelativeDimensionAuto
 * Used when attached to a stack layout.
 */
@property (nonatomic, assign) ASDimension flexBasis;

/**
 * @abstract Orientation of the object along cross axis, overriding alignItems
 * Used when attached to a stack layout.
 */
@property (nonatomic, assign) ASStackLayoutAlignSelf alignSelf;

/**
 *  @abstract Used for baseline alignment. The distance from the top of the object to its baseline.
 */
@property (nonatomic, assign) CGFloat ascender;

/**
 *  @abstract Used for baseline alignment. The distance from the baseline of the object to its bottom.
 */
@property (nonatomic, assign) CGFloat descender;

#pragma mark - ASAbsoluteLayoutElement

/**
 * @abstract The position of this object within its parent spec.
 */
@property (nonatomic, assign) CGPoint layoutPosition;

@end

NS_ASSUME_NONNULL_END

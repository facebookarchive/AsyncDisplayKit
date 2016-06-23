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
#import <AsyncDisplayKit/ASRelativeLayoutDefines.h>
#import <AsyncDisplayKit/ASCenterLayoutDefines.h>


@class ASLayout;
@class ASRatioLayoutSpec;
@class ASBackgroundLayoutSpec;
@class ASOverlayLayoutSpec;
@class ASInsetLayoutSpec;
@class ASStaticLayoutSpec;
@class ASCenterLayoutSpec;
@class ASRelativeLayoutSpec;

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

@property (nonatomic, readonly) ASLayoutableType layoutableType;

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver and its children.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize;

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
 If specified, the child's size is restricted according to this size. Percentages are resolved relative to the static layout spec.
 */
@property (nonatomic, assign) ASRelativeSizeRange sizeRange;

/** The position of this object within its parent spec. */
@property (nonatomic, assign) CGPoint layoutPosition;

#pragma mark - Convenience

// TODO: Finalize documentation
/**
 * Set flexBasis on the receiver and return the receiver.
 */
- (instancetype)withFlexBasis:(ASRelativeDimension)flexBasis;

/**
 * Set flexGrow on the receiver and return the receiver.
 */
- (instancetype)withFlexGrow:(BOOL)flexGrow;

/**
 * Set flexShrink on the receiver and return the receiver.
 */
- (instancetype)withFlexShrink:(BOOL)flexShrink;

/**
 * Set flexShrink on the receiver and return the receiver.
 */
- (instancetype)withAlignSelf:(ASStackLayoutAlignSelf)alignSelf;

/**
 * Set spacingBefore and spacingAfter on the receiver, then return the receiver.
 */
- (instancetype)withSpacingBefore:(CGFloat)spacingBefore after:(CGFloat)spacingAfter;

/**
 * Embed the receiver in a center layout spec with the given options.
 */
- (ASCenterLayoutSpec *)centeredWithOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions;

/**
 * Embed the receiver in a relative layout spec with the given options.
 */
- (ASRelativeLayoutSpec *)positionedRelativeWithHorizontalPosition:(ASRelativeLayoutSpecPosition)horizontalPosition verticalPosition:(ASRelativeLayoutSpecPosition)verticalPosition sizingOption:(ASRelativeLayoutSpecSizingOption)sizingOption;

/**
 * Embed the receiver in a static layout spec with the given size range and layout position
 */
- (ASStaticLayoutSpec *)withStaticSizeRange:(ASRelativeSizeRange)sizeRange position:(CGPoint)layoutPosition;

/**
 * Embed the receiver in a ratio layout spec with the given ratio.
 */
- (ASRatioLayoutSpec *)withAspectRatio:(CGFloat)ratio;

/**
 * Embed the receiver in an overlay layout spec with the given overlay.
 */
- (ASOverlayLayoutSpec *)withOverlay:(nullable id<ASLayoutable>)overlay;

/**
 * Embed the receiver in a background layout spec with the given background.
 */
- (ASBackgroundLayoutSpec *)withBackground:(nullable id<ASLayoutable>)background;

/**
 * Embed the receiver in an inset layout spec with the given insets.
 */
- (ASInsetLayoutSpec *)withInset:(UIEdgeInsets)insets;

@end

NS_ASSUME_NONNULL_END

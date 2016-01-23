//
//  ASRelativePositionLayoutSpec.h
//  Pods
//
//  Created by Samuel Stow on 12/31/15.
//
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/** How the child is positioned within the spec. */
typedef NS_OPTIONS(NSUInteger, ASRelativePositionLayoutSpecPosition) {
    /** The child is positioned at point 0 relatively to the layout axis (ie left / top most) */
    ASRelativePositionLayoutSpecPositionZero = 0,
    /** The child is centered along the specified axis */
    ASRelativePositionLayoutSpecPositionCenter = 1 << 0,
    /** The child is positioned at the maximum point of the layout axis (ie right / bottom most) */
    ASRelativePositionLayoutSpecPositionMax = 1 << 1,
};

/** How much space the spec will take up. */
typedef NS_OPTIONS(NSUInteger, ASRelativePositionLayoutSpecSizingOption) {
    /** The spec will take up the maximum size possible */
    ASRelativePositionLayoutSpecSizingOptionDefault,
    /** The spec will take up the minimum size possible along the X axis */
    ASRelativePositionLayoutSpecSizingOptionOptionMinimumX = 1 << 0,
    /** The spec will take up the minimum size possible along the Y axis */
    ASRelativePositionLayoutSpecSizingOptionOptionMinimumY = 1 << 1,
    /** Convenience option to take up the minimum size along both the X and Y axis */
    ASRelativePositionLayoutSpecSizingOptionMinimumXY = ASRelativePositionLayoutSpecSizingOptionOptionMinimumX | ASRelativePositionLayoutSpecSizingOptionOptionMinimumY,
};

NS_ASSUME_NONNULL_BEGIN

/** Lays out a single layoutable child and position it so that it is positioned in the layout bounds according to vertical and horizontal positional specifiers. */
@interface ASRelativePositionLayoutSpec : ASLayoutSpec

@property (nonatomic, assign) ASRelativePositionLayoutSpecPosition horizontalPosition;
@property (nonatomic, assign) ASRelativePositionLayoutSpecPosition verticalPosition;
@property (nonatomic, assign) ASRelativePositionLayoutSpecSizingOption sizingOption;

/*!
 * @discussion convenience constructor for a ASRelativePositionLayoutSpec
 * @param horizontalPosition how to position the item on the horizontal (x) axis
 * @param verticalPosition how to position the item on the vertical (y) axis
 * @param sizingOption how much size to take up
 * @param child the child to layout
 * @return a configured ASRelativePositionLayoutSpec
 */
+ (instancetype)relativePositionLayoutSpecWithHorizontalPosition:(ASRelativePositionLayoutSpecPosition)horizontalPosition
                                                   verticalPosition:(ASRelativePositionLayoutSpecPosition)verticalPosition
                                                       sizingOption:(ASRelativePositionLayoutSpecSizingOption)sizingOption
                                                              child:(id<ASLayoutable>)child;

@end

NS_ASSUME_NONNULL_END
//
//  ASDimension.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#define ASPointsAreValidForLayout(x) ((isnormal(x) || x == 0.0) && x >= 0.0 && x < (CGFLOAT_MAX / 2.0))
#define ASCGSizeIsValidForLayout(x) (ASPointsAreValidForLayout(x.width) && ASPointsAreValidForLayout(x.height))

/**
 * A dimension relative to constraints to be provided in the future.
 * A RelativeDimension can be one of three types:
 *
 * "Auto" - This indicated "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances.
 *
 * "Points" - Just a number. It will always resolve to exactly this amount.
 *
 * "Percent" - Multiplied to a provided parent amount to resolve a final amount.
 */
typedef NS_ENUM(NSInteger, ASRelativeDimensionType) {
  /** This indicates "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances. */
  ASRelativeDimensionTypeAuto,
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASRelativeDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASRelativeDimensionTypeFraction,
};

typedef struct {
  ASRelativeDimensionType type;
  CGFloat value;
} ASRelativeDimension;

/**
 * Expresses a size with relative dimensions.
 */
typedef struct {
  ASRelativeDimension width;
  ASRelativeDimension height;
} ASRelativeSize;

/**
 * Expresses an inclusive range of sizes. Used to provide a simple constraint to layout.
 */
typedef struct {
  CGSize min;
  CGSize max;
} ASSizeRange;

/**
 * A struct specifying a ASLayoutable's size. Example:
 *
 *  ASSize size = (ASSize){
 *    .width = ASRelativeDimensionMakeWithFraction(0.25),
 *    .maxWidth = ASRelativeDimensionMakeWithPoints(200),
 *    .minHeight = ASRelativeDimensionMakeWithFraction(0.50)
 *  };
 *
 *  Description: <ASSize: exact={25%, Auto}, min={Auto, 50%}, max={200pt, Auto}>
 *
 */
typedef struct {
  ASRelativeDimension width;
  ASRelativeDimension height;
  ASRelativeDimension minWidth;
  ASRelativeDimension maxWidth;
  ASRelativeDimension minHeight;
  ASRelativeDimension maxHeight;
} ASSize;

extern ASRelativeDimension const ASRelativeDimensionAuto;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASRelativeDimension

ASOVERLOADABLE extern ASRelativeDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value);

ASOVERLOADABLE extern ASRelativeDimension ASRelativeDimensionMake(CGFloat points);

ASOVERLOADABLE extern ASRelativeDimension ASRelativeDimensionMake(NSString *dimension);

extern ASRelativeDimension ASRelativeDimensionMakeWithPoints(CGFloat points);

extern ASRelativeDimension ASRelativeDimensionMakeWithFraction(CGFloat fraction);

extern ASRelativeDimension ASRelativeDimensionCopy(ASRelativeDimension aDimension);

extern BOOL ASRelativeDimensionEqualToRelativeDimension(ASRelativeDimension lhs, ASRelativeDimension rhs);

extern NSString *NSStringFromASRelativeDimension(ASRelativeDimension dimension);

extern CGFloat ASRelativeDimensionResolve(ASRelativeDimension dimension, CGFloat autoSize, CGFloat parent);

#define ASRD(x) ASRelativeDimensionMake(x)
#define ASD(x) ASRelativeDimensionMake(x)

@interface NSNumber (ASRelativeDimension)
@property (nonatomic, readonly) ASRelativeDimension points;
@property (nonatomic, readonly) ASRelativeDimension fraction;
@end

#pragma mark - ASSize

/**
 * Returns an ASSize with default values.
 */
extern ASSize ASSizeMake();

/**
 * Returns an ASSize with the specified CGSize values as width and height.
 */
extern ASSize ASSizeMakeFromCGSize(CGSize size);

/**
 * Returns whether two ASSize are equal.
 */
extern BOOL ASSizeEqualToSize(ASSize lhs, ASSize rhs);

/**
 * Returns a string formatted to contain the data from an ASSize.
 */
extern NSString *NSStringFromASSize(ASSize size);

extern ASSizeRange ASSizeResolve(ASSize size, const CGSize parentSize);
extern ASSizeRange ASSizeResolveAutoSize(ASSize size, const CGSize parentSize, ASSizeRange autoASSizeRange);

#pragma mark - ASSizeRange

/**
 * Creates an ASSizeRange with provided min and max size.
 */
extern ASSizeRange ASSizeRangeMake(CGSize min, CGSize max);

/**
 * Creates an ASSizeRange with the provided size as both min and max.
 */
extern ASSizeRange ASSizeRangeMakeWithExactCGSize(CGSize size);

/**
 * Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange.
 */
extern CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size);

/**
 * Intersects another size range. If the other size range does not overlap in either dimension, this size range
 * "wins" by returning a single point within its own range that is closest to the non-overlapping range.
 */
extern ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

/**
 * Returns whether two size ranges are equal in min and max size
 */
extern BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs);

/**
 * Returns a string representation of a size range
 */
extern NSString *NSStringFromASSizeRange(ASSizeRange sizeRange);


#pragma mark - Deprecated

/**
 * Function is deprecated please use ASSizeRangeMakeWithExactCGSize
 */
extern ASSizeRange ASSizeRangeMakeExactSize(CGSize size);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

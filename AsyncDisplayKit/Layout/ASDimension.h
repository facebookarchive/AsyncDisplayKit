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
typedef NS_ENUM(NSInteger, ASDimensionType) {
  /** This indicates "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances. */
  ASDimensionTypeAuto,
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASDimensionTypeFraction,
};

typedef struct {
  ASDimensionType type;
  CGFloat value;
} ASDimension;

/**
 * Expresses a size with relative dimensions.
 */
typedef struct {
  ASDimension width;
  ASDimension height;
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
 *    .width = ASDimensionMakeWithFraction(0.25),
 *    .maxWidth = ASDimensionMakeWithPoints(200),
 *    .minHeight = ASDimensionMakeWithFraction(0.50)
 *  };
 *
 *  Description: <ASSize: exact={25%, Auto}, min={Auto, 50%}, max={200pt, Auto}>
 *
 */
typedef struct {
  ASDimension width;
  ASDimension height;
  ASDimension minWidth;
  ASDimension maxWidth;
  ASDimension minHeight;
  ASDimension maxHeight;
} ASSize;

extern ASDimension const ASDimensionAuto;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASDimension

/**
 * Returns a dimension with the specified type and value.
 */
ASOVERLOADABLE extern ASDimension ASDimensionMake(ASDimensionType type, CGFloat value);

/**
 * Returns a dimension with the specified points value.
 */
ASOVERLOADABLE extern ASDimension ASDimensionMake(CGFloat points);

/**
 * Returns a dimension by parsing the specified dimension string.
 * Examples: ASDimensionMake(@"0.5%") = ASDimensionMake(ASDimensionTypeFraction, 0.5)
 *           ASDimensionMake(@"0.5pt") = ASDimensionMake(ASDimensionTypePoints, 0.5)
 */
ASOVERLOADABLE extern ASDimension ASDimensionMake(NSString *dimension);

/**
 * Returns a dimension with the specified points value.
 */
extern ASDimension ASDimensionMakeWithPoints(CGFloat points);

/**
 * Returns a dimension with the specified fraction value.
 */
extern ASDimension ASDimensionMakeWithFraction(CGFloat fraction);

/**
 * Returns a dimension with the same type and value as the specified dimension.
 */
extern ASDimension ASDimensionCopy(ASDimension aDimension);

/**
 * Returns whether two dimensions are equal.
 */
extern BOOL ASDimensionEqualToDimension(ASDimension lhs, ASDimension rhs);

/**
 * Returns a NSString representation of a dimension.
 */
extern NSString *NSStringFromASDimension(ASDimension dimension);

/**
 * Resolve this dimension to a parent size.
 */
extern CGFloat ASDimensionResolve(ASDimension dimension, CGFloat autoSize, CGFloat parent);

#define ASD(...) ASDimensionMake(__VA_ARGS__)

@interface NSNumber (ASRelativeDimension)
@property (nonatomic, readonly) ASDimension as_points;
@property (nonatomic, readonly) ASDimension as_fraction;
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
 * Returns whether two sizes are equal.
 */
extern BOOL ASSizeEqualToSize(ASSize lhs, ASSize rhs);

/**
 * Returns a string formatted to contain the data from an ASSize.
 */
extern NSString *NSStringFromASSize(ASSize size);

/**
 * Resolve this size to a parent size.
 */
extern ASSizeRange ASSizeResolve(ASSize size, const CGSize parentSize);

/**
 * Resolve this size to a parent size and use autoASSizeRange if
 */
extern ASSizeRange ASSizeResolveAutoSize(ASSize size, const CGSize parentSize, ASSizeRange autoASSizeRange);

#pragma mark - ASSizeRange

/**
 * Creates an ASSizeRange with provided size as both min and max.
 */
ASOVERLOADABLE extern ASSizeRange ASSizeRangeMake(CGSize size);

/**
 * Creates an ASSizeRange with provided min and max size.
 */
ASOVERLOADABLE extern ASSizeRange ASSizeRangeMake(CGSize min, CGSize max);

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
 * Function is deprecated. Use ASSizeRangeMakeWithExactCGSize instead.
 */
extern ASSizeRange ASSizeRangeMakeExactSize(CGSize size);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

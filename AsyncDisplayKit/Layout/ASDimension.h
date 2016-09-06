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
#import <AsyncDisplayKit/ASAssert.h>

ASDISPLAYNODE_INLINE BOOL ASPointsAreValidForLayout(CGFloat points)
{
  return ((isnormal(points) || points == 0.0) && points >= 0.0 && points < (CGFLOAT_MAX / 2.0));
}

ASDISPLAYNODE_INLINE BOOL ASIsCGSizeValidForLayout(CGSize size)
{
  return (ASPointsAreValidForLayout(size.width) && ASPointsAreValidForLayout(size.height));  
}

/**
 * A dimension relative to constraints to be provided in the future.
 * A ASDimension can be one of three types:
 *
 * "Auto" - This indicated "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances.
 *
 * "Points" - Just a number. It will always resolve to exactly this amount.
 *
 * "Percent" - Multiplied to a provided parent amount to resolve a final amount.
 */
typedef NS_ENUM(NSInteger, ASDimensionUnit) {
  /** This indicates "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances. */
  ASDimensionUnitAuto,
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASDimensionUnitPoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASDimensionUnitFraction,
};

typedef struct {
  ASDimensionUnit unit;
  CGFloat value;
} ASDimension;

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
 *  ASLayoutableSize size = (ASLayoutableSize){
 *    .width = ASDimensionMakeWithFraction(0.25),
 *    .maxWidth = ASDimensionMakeWithPoints(200),
 *    .minHeight = ASDimensionMakeWithFraction(0.50)
 *  };
 *
 *  Description: <ASLayoutableSize: exact={25%, Auto}, min={Auto, 50%}, max={200pt, Auto}>
 *
 */
typedef struct {
  ASDimension width;
  ASDimension height;
  ASDimension minWidth;
  ASDimension maxWidth;
  ASDimension minHeight;
  ASDimension maxHeight;
} ASLayoutableSize;

extern ASDimension const ASDimensionAuto;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN


#pragma mark - ASDimension

/**
 * Returns a dimension with the specified type and value.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE ASDimension ASDimensionMake(ASDimensionUnit unit, CGFloat value)
{
  if (unit == ASDimensionUnitPoints) {
    ASDisplayNodeCAssertPositiveReal(@"Points", value);
  } else if (unit == ASDimensionUnitFraction) {
    // TODO: Enable this assertion for 2.0.  Check that there is no use case for using a larger value, e.g. to layout for a clipsToBounds = NO element.
    // ASDisplayNodeCAssert( 0 <= value && value <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", value);
  }
  ASDimension dimension;
  dimension.unit = unit;
  dimension.value = value;
  return dimension;
}

/**
 * Returns a dimension with the specified points value.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE ASDimension ASDimensionMake(CGFloat points)
{
  return ASDimensionMake(ASDimensionUnitPoints, points);
}

/**
 * Returns a dimension by parsing the specified dimension string.
 * Examples: ASDimensionMake(@"0.5%") = ASDimensionMake(ASDimensionUnitFraction, 0.5)
 *           ASDimensionMake(@"0.5pt") = ASDimensionMake(ASDimensionUnitPoints, 0.5)
 */
ASOVERLOADABLE extern ASDimension ASDimensionMake(NSString *dimension);

/**
 * Returns a dimension with the specified points value.
 */
ASDISPLAYNODE_INLINE ASDimension ASDimensionMakeWithPoints(CGFloat points)
{
  ASDisplayNodeCAssertPositiveReal(@"Points", points);
  return ASDimensionMake(ASDimensionUnitPoints, points);
}

/**
 * Returns a dimension with the specified fraction value.
 */
ASDISPLAYNODE_INLINE ASDimension ASDimensionMakeWithFraction(CGFloat fraction)
{
  ASDisplayNodeCAssert( 0 <= fraction && fraction <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", fraction);
  return ASDimensionMake(ASDimensionUnitFraction, fraction);
}

/**
 * Returns whether two dimensions are equal.
 */
ASDISPLAYNODE_INLINE BOOL ASDimensionEqualToDimension(ASDimension lhs, ASDimension rhs)
{
  return (lhs.unit == rhs.unit && lhs.value == rhs.value);
}

/**
 * Returns a NSString representation of a dimension.
 */
extern NSString *NSStringFromASDimension(ASDimension dimension);

/**
 * Resolve this dimension to a parent size.
 */
ASDISPLAYNODE_INLINE CGFloat ASDimensionResolve(ASDimension dimension, CGFloat parentSize, CGFloat autoSize)
{
  switch (dimension.unit) {
    case ASDimensionUnitAuto:
      return autoSize;
    case ASDimensionUnitPoints:
      return dimension.value;
    case ASDimensionUnitFraction:
      return dimension.value * parentSize;
  }
}


#pragma mark - NSNumber+ASDimension

@interface NSNumber (ASDimension)
@property (nonatomic, readonly) ASDimension as_pointDimension;
@property (nonatomic, readonly) ASDimension as_fractionDimension;
@end


#pragma mark - ASSizeRange

/**
 * Creates an ASSizeRange with provided min and max size.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE ASSizeRange ASSizeRangeMake(CGSize min, CGSize max)
{
  ASDisplayNodeCAssertPositiveReal(@"Range min width", min.width);
  ASDisplayNodeCAssertPositiveReal(@"Range min height", min.height);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max width", max.width);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max height", max.height);
  ASDisplayNodeCAssert(min.width <= max.width,
                       @"Range min width (%f) must not be larger than max width (%f).", min.width, max.width);
  ASDisplayNodeCAssert(min.height <= max.height,
                       @"Range min height (%f) must not be larger than max height (%f).", min.height, max.height);
  ASSizeRange sizeRange;
  sizeRange.min = min;
  sizeRange.max = max;
  return sizeRange;
}

/**
 * Creates an ASSizeRange with provided size as both min and max.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE ASSizeRange ASSizeRangeMake(CGSize exactSize)
{
  return ASSizeRangeMake(exactSize, exactSize);
}

/**
 * Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange.
 */
ASDISPLAYNODE_INLINE CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size)
{
  return CGSizeMake(MAX(sizeRange.min.width, MIN(sizeRange.max.width, size.width)),
                    MAX(sizeRange.min.height, MIN(sizeRange.max.height, size.height)));
}

/**
 * Intersects another size range. If the other size range does not overlap in either dimension, this size range
 * "wins" by returning a single point within its own range that is closest to the non-overlapping range.
 */
extern ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

/**
 * Returns whether two size ranges are equal in min and max size
 */
ASDISPLAYNODE_INLINE BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs)
{
  return CGSizeEqualToSize(lhs.min, rhs.min) && CGSizeEqualToSize(lhs.max, rhs.max);
}

/**
 * Returns a string representation of a size range
 */
extern NSString *NSStringFromASSizeRange(ASSizeRange sizeRange);


#pragma mark - ASLayoutableSize

/**
 * Returns an ASLayoutableSize with default values.
 */
ASDISPLAYNODE_INLINE ASLayoutableSize ASLayoutableSizeMake()
{
  return (ASLayoutableSize){
    .width = ASDimensionAuto,
    .height = ASDimensionAuto,
    .minWidth = ASDimensionAuto,
    .maxWidth = ASDimensionAuto,
    .minHeight = ASDimensionAuto,
    .maxHeight = ASDimensionAuto
  };
}

/**
 * Returns an ASLayoutableSize with the specified CGSize values as width and height.
 */
ASDISPLAYNODE_INLINE ASLayoutableSize ASLayoutableSizeMakeFromCGSize(CGSize size)
{
  ASLayoutableSize s = ASLayoutableSizeMake();
  s.width = ASDimensionMakeWithPoints(size.width);
  s.height = ASDimensionMakeWithPoints(size.height);
  return s;
}

/**
 * Returns whether two sizes are equal.
 */
ASDISPLAYNODE_INLINE BOOL ASLayoutableSizeEqualToLayoutableSize(ASLayoutableSize lhs, ASLayoutableSize rhs)
{
  return (ASDimensionEqualToDimension(lhs.width, rhs.width)
  && ASDimensionEqualToDimension(lhs.height, rhs.height)
  && ASDimensionEqualToDimension(lhs.minWidth, rhs.minWidth)
  && ASDimensionEqualToDimension(lhs.maxWidth, rhs.maxWidth)
  && ASDimensionEqualToDimension(lhs.minHeight, rhs.minHeight)
  && ASDimensionEqualToDimension(lhs.maxHeight, rhs.maxHeight));
}

/**
 * Returns a string formatted to contain the data from an ASLayoutableSize.
 */
extern NSString *NSStringFromASLayoutableSize(ASLayoutableSize size);

/**
 * Resolve the given size relative to a parent size and an auto size.
 * From the given size uses width, height to resolve the exact size constraint, uses the minHeight and minWidth to
 * resolve the min size constraint and the maxHeight and maxWidth to resolve the max size constraint. For every
 * dimension with unit ASDimensionUnitAuto the given autoASSizeRange value will be used.
 * Based on the calculated exact, min and max size constraints the final size range will be calculated.
 */
extern ASSizeRange ASLayoutableSizeResolveAutoSize(ASLayoutableSize size, const CGSize parentSize, ASSizeRange autoASSizeRange);

/**
 * Resolve the given size to a parent size. Uses internally ASLayoutableSizeResolveAutoSize with {INFINITY, INFINITY} as
 * as autoASSizeRange. For more information look at ASLayoutableSizeResolveAutoSize.
 */
ASDISPLAYNODE_INLINE ASSizeRange ASLayoutableSizeResolve(ASLayoutableSize size, const CGSize parentSize)
{
  return ASLayoutableSizeResolveAutoSize(size, parentSize, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
}


#pragma mark - Deprecated

/**
 * Function is deprecated. Use ASSizeRangeMakeWithExactCGSize instead.
 */
extern ASSizeRange ASSizeRangeMakeExactSize(CGSize size) ASDISPLAYNODE_DEPRECATED;

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

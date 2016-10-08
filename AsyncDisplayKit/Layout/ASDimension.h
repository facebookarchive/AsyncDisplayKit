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

ASDISPLAYNODE_INLINE BOOL AS_WARN_UNUSED_RESULT ASPointsValidForLayout(CGFloat points)
{
  return ((isnormal(points) || points == 0.0) && points >= 0.0 && points < (CGFLOAT_MAX / 2.0));
}

ASDISPLAYNODE_INLINE BOOL AS_WARN_UNUSED_RESULT ASIsCGSizeValidForLayout(CGSize size)
{
    return (ASPointsValidForLayout(size.width) && ASPointsValidForLayout(size.height));
}

ASDISPLAYNODE_INLINE BOOL AS_WARN_UNUSED_RESULT ASPointsValidForSize(CGFloat points)
{
    return ((isnormal(points) || points == 0.0) && points >= 0.0 && points < (FLT_MAX / 2.0));
}

ASDISPLAYNODE_INLINE BOOL AS_WARN_UNUSED_RESULT ASIsCGSizeValidForSize(CGSize size)
{
    return (ASPointsValidForSize(size.width) && ASPointsValidForSize(size.height));
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
 * A struct specifying a ASLayoutElement's size. Example:
 *
 *  ASLayoutElementSize size = (ASLayoutElementSize){
 *    .width = ASDimensionMakeWithFraction(0.25),
 *    .maxWidth = ASDimensionMakeWithPoints(200),
 *    .minHeight = ASDimensionMakeWithFraction(0.50)
 *  };
 *
 *  Description: <ASLayoutElementSize: exact={25%, Auto}, min={Auto, 50%}, max={200pt, Auto}>
 *
 */
typedef struct {
  ASDimension width;
  ASDimension height;
  ASDimension minWidth;
  ASDimension maxWidth;
  ASDimension minHeight;
  ASDimension maxHeight;
} ASLayoutElementSize;

extern ASDimension const ASDimensionAuto;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN


#pragma mark - ASDimension

/**
 * Returns a dimension with the specified type and value.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE ASDimension ASDimensionMake(ASDimensionUnit unit, CGFloat value)
{
  if (unit == ASDimensionUnitAuto ) {
    ASDisplayNodeCAssert(value == 0, @"ASDimension auto value must be 0.");
  } else if (unit == ASDimensionUnitPoints) {
    ASDisplayNodeCAssertPositiveReal(@"Points", value);
  } else if (unit == ASDimensionUnitFraction) {
    ASDisplayNodeCAssert( 0 <= value && value <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", value);
  }
  ASDimension dimension;
  dimension.unit = unit;
  dimension.value = value;
  return dimension;
}

/**
 * Returns a dimension with the specified points value.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASDimension ASDimensionMake(CGFloat points)
{
  return ASDimensionMake(ASDimensionUnitPoints, points);
}

/**
 * Returns a dimension by parsing the specified dimension string.
 * Examples: ASDimensionMake(@"50%") = ASDimensionMake(ASDimensionUnitFraction, 0.5)
 *           ASDimensionMake(@"0.5pt") = ASDimensionMake(ASDimensionUnitPoints, 0.5)
 */
ASOVERLOADABLE AS_WARN_UNUSED_RESULT extern ASDimension ASDimensionMake(NSString *dimension);

/**
 * Returns a dimension with the specified points value.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASDimension ASDimensionMakeWithPoints(CGFloat points)
{
  ASDisplayNodeCAssertPositiveReal(@"Points", points);
  return ASDimensionMake(ASDimensionUnitPoints, points);
}

/**
 * Returns a dimension with the specified fraction value.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASDimension ASDimensionMakeWithFraction(CGFloat fraction)
{
  ASDisplayNodeCAssert( 0 <= fraction && fraction <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", fraction);
  return ASDimensionMake(ASDimensionUnitFraction, fraction);
}

/**
 * Returns whether two dimensions are equal.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASDimensionEqualToDimension(ASDimension lhs, ASDimension rhs)
{
  return (lhs.unit == rhs.unit && lhs.value == rhs.value);
}

/**
 * Returns a NSString representation of a dimension.
 */
extern AS_WARN_UNUSED_RESULT NSString *NSStringFromASDimension(ASDimension dimension);

/**
 * Resolve this dimension to a parent size.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT CGFloat ASDimensionResolve(ASDimension dimension, CGFloat parentSize, CGFloat autoSize)
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


#pragma mark - ASLayoutSize

/**
 * Expresses a size with relative dimensions. Only used for calculations internally in ASDimension.h
 */
typedef struct {
  ASDimension width;
  ASDimension height;
} ASLayoutSize;

/*
 * Creates an ASLayoutSize with provided min and max dimensions.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASLayoutSize ASLayoutSizeMake(ASDimension width, ASDimension height)
{
  ASLayoutSize size;
  size.width = width;
  size.height = height;
  return size;
}

/*
 * Returns a string representation of a relative size.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT NSString *NSStringFromASLayoutSize(ASLayoutSize size);

#pragma mark - ASSizeRange

/**
 * Creates an ASSizeRange with provided min and max size.
 */
ASOVERLOADABLE ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASSizeRange ASSizeRangeMake(CGSize min, CGSize max)
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
ASOVERLOADABLE ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASSizeRange ASSizeRangeMake(CGSize exactSize)
{
  return ASSizeRangeMake(exactSize, exactSize);
}

/**
 * Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size)
{
  return CGSizeMake(MAX(sizeRange.min.width, MIN(sizeRange.max.width, size.width)),
                    MAX(sizeRange.min.height, MIN(sizeRange.max.height, size.height)));
}

/**
 * Intersects another size range. If the other size range does not overlap in either dimension, this size range
 * "wins" by returning a single point within its own range that is closest to the non-overlapping range.
 */
extern AS_WARN_UNUSED_RESULT ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

/**
 * Returns whether two size ranges are equal in min and max size.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs)
{
  return CGSizeEqualToSize(lhs.min, rhs.min) && CGSizeEqualToSize(lhs.max, rhs.max);
}

/**
 * Returns a string representation of a size range
 */
extern AS_WARN_UNUSED_RESULT NSString *NSStringFromASSizeRange(ASSizeRange sizeRange);


#pragma mark - ASLayoutElementSize

/**
 * Returns an ASLayoutElementSize with default values.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASLayoutElementSize ASLayoutElementSizeMake()
{
  return (ASLayoutElementSize){
    .width = ASDimensionAuto,
    .height = ASDimensionAuto,
    .minWidth = ASDimensionAuto,
    .maxWidth = ASDimensionAuto,
    .minHeight = ASDimensionAuto,
    .maxHeight = ASDimensionAuto
  };
}

/**
 * Returns an ASLayoutElementSize with the specified CGSize values as width and height.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASLayoutElementSize ASLayoutElementSizeMakeFromCGSize(CGSize size)
{
  ASLayoutElementSize s = ASLayoutElementSizeMake();
  s.width = ASDimensionMakeWithPoints(size.width);
  s.height = ASDimensionMakeWithPoints(size.height);
  return s;
}

/**
 * Returns whether two sizes are equal.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT BOOL ASLayoutElementSizeEqualToLayoutElementSize(ASLayoutElementSize lhs, ASLayoutElementSize rhs)
{
  return (ASDimensionEqualToDimension(lhs.width, rhs.width)
  && ASDimensionEqualToDimension(lhs.height, rhs.height)
  && ASDimensionEqualToDimension(lhs.minWidth, rhs.minWidth)
  && ASDimensionEqualToDimension(lhs.maxWidth, rhs.maxWidth)
  && ASDimensionEqualToDimension(lhs.minHeight, rhs.minHeight)
  && ASDimensionEqualToDimension(lhs.maxHeight, rhs.maxHeight));
}

/**
 * Returns a string formatted to contain the data from an ASLayoutElementSize.
 */
extern AS_WARN_UNUSED_RESULT NSString *NSStringFromASLayoutElementSize(ASLayoutElementSize size);

/**
 * Resolve the given size relative to a parent size and an auto size.
 * From the given size uses width, height to resolve the exact size constraint, uses the minHeight and minWidth to
 * resolve the min size constraint and the maxHeight and maxWidth to resolve the max size constraint. For every
 * dimension with unit ASDimensionUnitAuto the given autoASSizeRange value will be used.
 * Based on the calculated exact, min and max size constraints the final size range will be calculated.
 */
extern AS_WARN_UNUSED_RESULT ASSizeRange ASLayoutElementSizeResolveAutoSize(ASLayoutElementSize size, const CGSize parentSize, ASSizeRange autoASSizeRange);

/**
 * Resolve the given size to a parent size. Uses internally ASLayoutElementSizeResolveAutoSize with {INFINITY, INFINITY} as
 * as autoASSizeRange. For more information look at ASLayoutElementSizeResolveAutoSize.
 */
ASDISPLAYNODE_INLINE AS_WARN_UNUSED_RESULT ASSizeRange ASLayoutElementSizeResolve(ASLayoutElementSize size, const CGSize parentSize)
{
  return ASLayoutElementSizeResolveAutoSize(size, parentSize, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
}


#pragma mark - Deprecated

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
typedef NS_ENUM(NSInteger, ASRelativeDimensionType) {
  /** This indicates "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances. */
  ASRelativeDimensionTypeAuto,
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASRelativeDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASRelativeDimensionTypeFraction,
};

#define ASRelativeDimension ASDimension
#define ASRelativeSize ASLayoutSize
#define ASRelativeDimensionMakeWithPoints ASDimensionMakeWithPoints
#define ASRelativeDimensionMakeWithFraction ASDimensionMakeWithFraction

/**
 * Function is deprecated. Use ASSizeRangeMakeWithExactCGSize instead.
 */
extern AS_WARN_UNUSED_RESULT ASSizeRange ASSizeRangeMakeExactSize(CGSize size) ASDISPLAYNODE_DEPRECATED;

/**
 Expresses an inclusive range of relative sizes. Used to provide additional constraint to layout.
 Used by ASStaticLayoutSpec.
 */
typedef struct {
  ASLayoutSize min;
  ASLayoutSize max;
} ASRelativeSizeRange;

extern ASRelativeSizeRange const ASRelativeSizeRangeUnconstrained;

#pragma mark - ASRelativeDimension

extern ASDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value) ASDISPLAYNODE_DEPRECATED;

#pragma mark - ASRelativeSize

extern ASLayoutSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height) ASDISPLAYNODE_DEPRECATED;

/** Convenience constructor to provide size in points. */
extern ASLayoutSize ASRelativeSizeMakeWithCGSize(CGSize size) ASDISPLAYNODE_DEPRECATED;

/** Convenience constructor to provide size as a fraction. */
extern ASLayoutSize ASRelativeSizeMakeWithFraction(CGFloat fraction) ASDISPLAYNODE_DEPRECATED;

extern BOOL ASRelativeSizeEqualToRelativeSize(ASLayoutSize lhs, ASLayoutSize rhs) ASDISPLAYNODE_DEPRECATED;

extern NSString *NSStringFromASRelativeSize(ASLayoutSize size) ASDISPLAYNODE_DEPRECATED;

#pragma mark - ASRelativeSizeRange

extern ASRelativeSizeRange ASRelativeSizeRangeMake(ASLayoutSize min, ASLayoutSize max) ASDISPLAYNODE_DEPRECATED;

#pragma mark Convenience constructors to provide an exact size (min == max).
extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeSize(ASLayoutSize exact) ASDISPLAYNODE_DEPRECATED;

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact) ASDISPLAYNODE_DEPRECATED;

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactFraction(CGFloat fraction) ASDISPLAYNODE_DEPRECATED;

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeDimensions(ASRelativeDimension exactWidth, ASRelativeDimension exactHeight) ASDISPLAYNODE_DEPRECATED;

extern BOOL ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRange lhs, ASRelativeSizeRange rhs) ASDISPLAYNODE_DEPRECATED;

/** Provided a parent size, compute final dimensions for this RelativeSizeRange to arrive at a SizeRange. */
extern ASSizeRange ASRelativeSizeRangeResolve(ASRelativeSizeRange relativeSizeRange, CGSize parentSize) ASDISPLAYNODE_DEPRECATED;

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

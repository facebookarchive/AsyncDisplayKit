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
#import <CoreGraphics/CGBase.h>
#import <CoreGraphics/CGGeometry.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 * A dimension relative to constraints to be provided in the future.
 */
typedef NS_ENUM(NSInteger, ASDimensionType) {
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASDimensionTypeFraction,
};

typedef struct {
  ASDimensionType type;
  CGFloat value;
} ASDimension;

extern ASDimension const ASDimensionUnconstrained;

#define isValidForLayout(x) ((isnormal(x) || x == 0.0) && x >= 0.0 && x < (CGFLOAT_MAX / 2.0))

#define ASDimensionIsPoints(dimension) (dimension.type == ASDimensionTypePoints)
#define ASSizeRangeCAssertPoints(sizeRange) NSCAssert(ASDimensionIsPoints(sizeRange.min.width) && ASDimensionIsPoints(sizeRange.min.height) && ASDimensionIsPoints(sizeRange.max.width) && ASDimensionIsPoints(sizeRange.max.height), @"")
#define ASSizeRangeAssertPoints(sizeRange) NSAssert(ASDimensionIsPoints(sizeRange.min.width) && ASDimensionIsPoints(sizeRange.min.height) && ASDimensionIsPoints(sizeRange.max.width) && ASDimensionIsPoints(sizeRange.max.height), @"")

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASDimension

/**
 * Returns a dimension with the specified type and value.
 */
extern ASDimension ASDimensionMake(ASDimensionType type, CGFloat value);

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
 * Try to unwrap the points value. Asserts if the passed in dimension is not of type ASDimensionTypePoints
 */
extern CGFloat ASDimensionGetPoints(ASDimension dimension);

/**
 * Try to unwrap the fraction value. Asserts if the passed in dimension is not of type ASDimensionTypeFraction
 */
extern CGFloat ASDimensionGetFraction(ASDimension dimension);

/**
 * Returns a NSString representation of a dimension.
 */
extern NSString *NSStringFromASDimension(ASDimension dimension);

/**
 * Resolve this dimension to a parent size.
 */
extern CGFloat ASDimensionResolve(ASDimension dimension, CGFloat parent);

#pragma mark - ASSizeRange

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

/**
 * Expresses a size with relative dimensions.
 */
typedef struct {
  ASDimension width;
  ASDimension height;
} ASRelativeSize;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASRelativeSize

/**
 * Create size range with width and height dimension
 */
OVERLOADABLE extern ASRelativeSize ASRelativeSizeMake(ASDimension width, ASDimension height);

/**
 * Create size range with exact width and heights in points.
 */
OVERLOADABLE extern ASRelativeSize ASRelativeSizeMake(CGSize exactSize);

/**
 * Create size range with exact widht and heights in fraction.
 */
OVERLOADABLE extern ASRelativeSize ASRelativeSizeMake(CGFloat exactFraction);

/**
 * Convenience constructor to provide size in points.
 */
extern ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size);

/**
 * Convenience constructor to provide size in fraction.
 */
extern ASRelativeSize ASRelativeSizeMakeWithFraction(CGFloat fraction);

/**
 * Resolve this relative size relative to a parent size.
 */
extern CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize);

/**
 * Returns whether two size ranges are equal in size
 */
extern BOOL ASRelativeSizeEqualToRelativeSize(ASRelativeSize lhs, ASRelativeSize rhs);

/**
 * Returns a CGSize representation of a relative size
 */
extern CGSize CGSizeFromASRelativeSize(ASRelativeSize relativeSize);

/*
 * Returns a string representation of a size
 */
extern NSString *NSStringFromASRelativeSize(ASRelativeSize size);


#pragma mark - ASSizeRange

/**
 * Expresses an inclusive range of relative sizes. Used to provide additional constraint to layout.
 */
typedef struct {
  ASRelativeSize min;
  ASRelativeSize max;
} ASSizeRange;

extern ASSizeRange const ASSizeRangeUnconstrained;

/**
 * Create size range with min and max relative size
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(ASRelativeSize min, ASRelativeSize max);

/**
 * Create size range with exact relative size
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(ASRelativeSize exact);

/**
 * Create size range with exact size
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(CGSize exact);

/**
 * Create size range with exact width and height dimension
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(ASDimension exactWidth, ASDimension exactHeight);

/**
 * Create size range based on min and max CGSize
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(CGSize minSize, CGSize maxSize);

/**
 * Create size range based on 4 dimensions: min width, max width, min height, max height
 */
OVERLOADABLE extern ASSizeRange ASSizeRangeMake(ASDimension minWidth, ASDimension maxWidth,
                                                ASDimension minHeight, ASDimension maxHeight);

/**
 * Returns a Boolean value indicating whether the two size ranges are equal.
 */
extern BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs);

/**
 * Returns the min size for the size range
 */
extern CGSize ASSizeRangeGetMinSize(ASSizeRange sizeRange);

/**
 * Returns the max size for the size range
 */
extern CGSize ASSizeRangeGetMaxSize(ASSizeRange sizeRange);

/**
 * Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange.
 */
extern CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size);

/**
 * Returns the size range representing the intersection of two size ranges
 */
extern ASSizeRange ASSizeRangeIntersection(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

/**
 * Provided a parent size, compute final dimensions for this ASSizeRange to arrive at a resolved ASSizeRange with only
 * dimensions of type ASDimensionTypePoints.
 */
extern ASSizeRange ASSizeRangeResolve(ASSizeRange sizeRange, CGSize parentSize);

/**
 * Returns a string representation of a size range
 */
extern NSString *NSStringFromASSizeRange(ASSizeRange size);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

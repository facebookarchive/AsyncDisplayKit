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

/**
 A dimension relative to constraints to be provided in the future.
 */
typedef NS_ENUM(NSInteger, ASRelativeDimensionType) {
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASRelativeDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASRelativeDimensionTypePercent,
};

typedef struct {
  ASRelativeDimensionType type;
  CGFloat value;
} ASRelativeDimension;

/** Expresses an inclusive range of sizes. Used to provide a simple constraint to layout. */
typedef struct {
  CGSize min;
  CGSize max;
} ASSizeRange;

extern ASRelativeDimension const ASRelativeDimensionUnconstrained;

#define isValidForLayout(x) ((isnormal(x) || x == 0.0) && x >= 0.0 && x < (CGFLOAT_MAX / 2.0))

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark ASRelativeDimension

extern ASRelativeDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value);

extern ASRelativeDimension ASRelativeDimensionMakeWithPoints(CGFloat points);

extern ASRelativeDimension ASRelativeDimensionMakeWithPercent(CGFloat percent);

extern ASRelativeDimension ASRelativeDimensionCopy(ASRelativeDimension aDimension);

extern BOOL ASRelativeDimensionEqualToRelativeDimension(ASRelativeDimension lhs, ASRelativeDimension rhs);

extern NSString *NSStringFromASRelativeDimension(ASRelativeDimension dimension);

extern CGFloat ASRelativeDimensionResolve(ASRelativeDimension dimension, CGFloat parent);

#pragma mark -
#pragma mark ASSizeRange

extern ASSizeRange ASSizeRangeMake(CGSize min, CGSize max);

/** Creates an ASSizeRange with the provided size as both min and max */
extern ASSizeRange ASSizeRangeMakeExactSize(CGSize size);

/** Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange. */
extern CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size);

/**
 Intersects another size range. If the other size range does not overlap in either dimension, this size range
 "wins" by returning a single point within its own range that is closest to the non-overlapping range.
 */
extern ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

extern BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs);

extern NSString *NSStringFromASSizeRange(ASSizeRange sizeRange);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

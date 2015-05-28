/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 A dimension relative to constraints to be provided in the future.
 A RelativeDimension can be one of three types:
 
 "Auto" - This indicated "I have no opinion" and may be resolved in whatever way makes most sense given
 the circumstances. This is the default type.
 
 "Points" - Just a number. It will always resolve to exactly this amount.
 
 "Percent" - Multiplied to a provided parent amount to resolve a final amount.
 */
typedef NS_ENUM(NSInteger, ASRelativeDimensionType) {
  ASRelativeDimensionTypeAuto,
  ASRelativeDimensionTypePoints,
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

/** Expresses a size with relative dimensions. */
typedef struct {
  ASRelativeDimension width;
  ASRelativeDimension height;
} ASRelativeSize;

/**
 Expresses an inclusive range of relative sizes. Used to provide additional constraint to layout.
 */
typedef struct {
  ASRelativeSize min;
  ASRelativeSize max;
} ASRelativeSizeRange;

/** type = Auto; value = 0 */
extern ASRelativeDimension const ASRelativeDimensionAuto;

/** min = {0,0}; max = {INFINITY, INFINITY} */
extern ASSizeRange const ASSizeRangeUnconstrained;

/** width = Auto; height = Auto */
extern ASRelativeSize const ASRelativeSizeAuto;

/** min = {Auto, Auto}; max = {Auto, Auto} */
extern ASRelativeSizeRange const ASRelativeSizeRangeAuto;

ASDISPLAYNODE_EXTERN_C_BEGIN

#pragma mark ASRelativeDimension

extern ASRelativeDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value);

extern ASRelativeDimension ASRelativeDimensionMakeWithPoints(CGFloat points);

extern ASRelativeDimension ASRelativeDimensionMakeWithPercent(CGFloat percent);

extern ASRelativeDimension ASRelativeDimensionCopy(ASRelativeDimension aDimension);

extern BOOL ASRelativeDimensionEqualToDimension(ASRelativeDimension lhs, ASRelativeDimension rhs);

extern NSString *NSStringFromASRelativeDimension(ASRelativeDimension dimension);

extern CGFloat ASRelativeDimensionResolve(ASRelativeDimension dimension, CGFloat autoSize, CGFloat parent);

#pragma mark -
#pragma mark ASSizeRange

extern ASSizeRange ASSizeRangeMake(CGSize min, CGSize max);

/** Clamps the provided CGSize between the [min, max] bounds of this ASSizeRange. */
extern CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size);

/**
 Intersects another size range. If the other size range does not overlap in either dimension, this size range
 "wins" by returning a single point within its own range that is closest to the non-overlapping range.
 */
extern ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange);

extern BOOL ASSizeRangeEqualToRange(ASSizeRange lhs, ASSizeRange rhs);

extern NSString * NSStringFromASSizeRange(ASSizeRange sizeRange);

#pragma mark -
#pragma mark ASRelativeSize

extern ASRelativeSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height);

/** Convenience constructor to provide size in Points. */
extern ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size);

/** Resolve this relative size relative to a parent size and an auto size. */
extern CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize, CGSize autoSize);

extern BOOL ASRelativeSizeEqualToSize(ASRelativeSize lhs, ASRelativeSize rhs);

extern NSString *NSStringFromASRelativeSize(ASRelativeSize size);

#pragma mark -
#pragma mark ASRelativeSizeRange

extern ASRelativeSizeRange ASRelativeSizeRangeMake(ASRelativeSize min, ASRelativeSize max);

#pragma mark Convenience constructors to provide an exact size (min == max).
extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSize exact);

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact);

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeDimensions(ASRelativeDimension exactWidth,
                                                                              ASRelativeDimension exactHeight);

/**
 Provided a parent size and values to use in place of Auto, compute final dimensions for this RelativeSizeRange
 to arrive at a SizeRange.
 */
extern ASSizeRange ASRelativeSizeRangeResolveSizeRange(ASRelativeSizeRange relativeSizeRange,
                                                       CGSize parentSize,
                                                       ASSizeRange autoSizeRange);

/**
 Provided a parent size and a default autoSizeRange, compute final dimensions for this RelativeSizeRange
 to arrive at a SizeRange. As an example:
 
 CGSize parent = {200, 120};
 RelativeSizeRange rel = {Percent(0.5), Percent(2/3)}
 ASRelativeSizeRangeResolve(rel, parent); // {{100, 60}, {100, 60}}
 
 The default autoSizeRange is *everything*, meaning ASSizeRangeUnconstrained.
 */
extern ASSizeRange ASRelativeSizeRangeResolveSizeRangeWithDefaultAutoSizeRange(ASRelativeSizeRange relativeSizeRange,
                                                                               CGSize parentSize);

ASDISPLAYNODE_EXTERN_C_END

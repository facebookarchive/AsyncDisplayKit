//
//  ASDimensionDeprecated.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDimension.h>

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

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
 * Function is deprecated. Use ASSizeRangeMake instead.
 */
extern AS_WARN_UNUSED_RESULT ASSizeRange ASSizeRangeMakeExactSize(CGSize size) ASDISPLAYNODE_DEPRECATED_MSG("Use ASSizeRangeMake instead.");

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

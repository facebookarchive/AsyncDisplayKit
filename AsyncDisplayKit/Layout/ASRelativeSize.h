//
//  ASRelativeSize.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDimension.h>

/** 
 Expresses a size with relative dimensions.
 Used by ASStaticLayoutSpec.
 */
typedef struct {
  ASRelativeDimension width;
  ASRelativeDimension height;
} ASRelativeSize;

/**
 Expresses an inclusive range of relative sizes. Used to provide additional constraint to layout. 
 Used by ASStaticLayoutSpec.
 */
typedef struct {
  ASRelativeSize min;
  ASRelativeSize max;
} ASRelativeSizeRange;

extern ASRelativeSizeRange const ASRelativeSizeRangeUnconstrained;

ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark ASRelativeSize

extern ASRelativeSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height);

/** Convenience constructor to provide size in Points. */
extern ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size);

/** Resolve this relative size relative to a parent size. */
extern CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize);

extern BOOL ASRelativeSizeEqualToRelativeSize(ASRelativeSize lhs, ASRelativeSize rhs);

extern NSString *NSStringFromASRelativeSize(ASRelativeSize size);

#pragma mark -
#pragma mark ASRelativeSizeRange

extern ASRelativeSizeRange ASRelativeSizeRangeMake(ASRelativeSize min, ASRelativeSize max);

#pragma mark Convenience constructors to provide an exact size (min == max).
extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSize exact);

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact);

extern ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeDimensions(ASRelativeDimension exactWidth,
                                                                              ASRelativeDimension exactHeight);

extern BOOL ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRange lhs, ASRelativeSizeRange rhs);

/**
 Provided a parent size, compute final dimensions for this RelativeSizeRange to arrive at a SizeRange.
 */
extern ASSizeRange ASRelativeSizeRangeResolve(ASRelativeSizeRange relativeSizeRange,
                                                       CGSize parentSize);

NS_ASSUME_NONNULL_END
ASDISPLAYNODE_EXTERN_C_END

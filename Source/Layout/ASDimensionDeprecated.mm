//
//  ASDimensionDeprecated.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDimensionDeprecated.h>

ASDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value)
{
  if (type == ASRelativeDimensionTypePoints) {
    return ASDimensionMakeWithPoints(value);
  } else if (type == ASRelativeDimensionTypeFraction) {
    return ASDimensionMakeWithFraction(value);
  }
  
  ASDisplayNodeCAssert(NO, @"ASRelativeDimensionMake does not support the given ASRelativeDimensionType");
  return ASDimensionMakeWithPoints(0);
}

ASSizeRange ASSizeRangeMakeExactSize(CGSize size)
{
  return ASSizeRangeMake(size);
}

ASRelativeSizeRange const ASRelativeSizeRangeUnconstrained = {};

#pragma mark - ASRelativeSize

ASLayoutSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height)
{
  return ASLayoutSizeMake(width, height);
}

ASLayoutSize ASRelativeSizeMakeWithCGSize(CGSize size)
{
  return ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(size.width),
                            ASRelativeDimensionMakeWithPoints(size.height));
}

ASLayoutSize ASRelativeSizeMakeWithFraction(CGFloat fraction)
{
  return ASRelativeSizeMake(ASRelativeDimensionMakeWithFraction(fraction),
                            ASRelativeDimensionMakeWithFraction(fraction));
}

BOOL ASRelativeSizeEqualToRelativeSize(ASLayoutSize lhs, ASLayoutSize rhs)
{
  return ASDimensionEqualToDimension(lhs.width, rhs.width)
  && ASDimensionEqualToDimension(lhs.height, rhs.height);
}


#pragma mark - ASRelativeSizeRange

ASRelativeSizeRange ASRelativeSizeRangeMake(ASLayoutSize min, ASLayoutSize max)
{
  ASRelativeSizeRange sizeRange; sizeRange.min = min; sizeRange.max = max; return sizeRange;
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeSize(ASLayoutSize exact)
{
  return ASRelativeSizeRangeMake(exact, exact);
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact)
{
  return ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSizeMakeWithCGSize(exact));
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactFraction(CGFloat fraction)
{
  return ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSizeMakeWithFraction(fraction));
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeDimensions(ASRelativeDimension exactWidth, ASRelativeDimension exactHeight)
{
  return ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSizeMake(exactWidth, exactHeight));
}

BOOL ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRange lhs, ASRelativeSizeRange rhs)
{
  return ASRelativeSizeEqualToRelativeSize(lhs.min, rhs.min) && ASRelativeSizeEqualToRelativeSize(lhs.max, rhs.max);
}

ASSizeRange ASRelativeSizeRangeResolve(ASRelativeSizeRange relativeSizeRange,
                                       CGSize parentSize)
{
  return ASSizeRangeMake(ASLayoutSizeResolveSize(relativeSizeRange.min, parentSize, parentSize),
                         ASLayoutSizeResolveSize(relativeSizeRange.max, parentSize, parentSize));
}

//
//  ASRelativeSize.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASRelativeSize.h"

ASRelativeSizeRange const ASRelativeSizeRangeUnconstrained = {};

#pragma mark -
#pragma mark ASRelativeSize

ASRelativeSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height)
{
  ASRelativeSize size; size.width = width; size.height = height; return size;
}

ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size)
{
  return ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(size.width),
                            ASRelativeDimensionMakeWithPoints(size.height));
}

CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize)
{
  return CGSizeMake(ASRelativeDimensionResolve(relativeSize.width, parentSize.width),
                    ASRelativeDimensionResolve(relativeSize.height, parentSize.height));
}

BOOL ASRelativeSizeEqualToRelativeSize(ASRelativeSize lhs, ASRelativeSize rhs)
{
  return ASRelativeDimensionEqualToRelativeDimension(lhs.width, rhs.width)
    && ASRelativeDimensionEqualToRelativeDimension(lhs.height, rhs.height);
}

NSString *NSStringFromASRelativeSize(ASRelativeSize size)
{
  return [NSString stringWithFormat:@"{%@, %@}",
          NSStringFromASRelativeDimension(size.width),
          NSStringFromASRelativeDimension(size.height)];
}

#pragma mark -
#pragma mark ASRelativeSizeRange

ASRelativeSizeRange ASRelativeSizeRangeMake(ASRelativeSize min, ASRelativeSize max)
{
  ASRelativeSizeRange sizeRange; sizeRange.min = min; sizeRange.max = max; return sizeRange;
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSize exact)
{
  return ASRelativeSizeRangeMake(exact, exact);
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactCGSize(CGSize exact)
{
  return ASRelativeSizeRangeMakeWithExactRelativeSize(ASRelativeSizeMakeWithCGSize(exact));
}

ASRelativeSizeRange ASRelativeSizeRangeMakeWithExactRelativeDimensions(ASRelativeDimension exactWidth,
                                                                       ASRelativeDimension exactHeight)
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
  return ASSizeRangeMake(ASRelativeSizeResolveSize(relativeSizeRange.min, parentSize),
                         ASRelativeSizeResolveSize(relativeSizeRange.max, parentSize));
}

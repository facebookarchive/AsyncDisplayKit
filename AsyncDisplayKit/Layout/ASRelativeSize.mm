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

#pragma mark - ASRelativeSize

ASRelativeSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height)
{
  ASRelativeSize size; size.width = width; size.height = height; return size;
}

ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size)
{
  return ASRelativeSizeMake(ASRelativeDimensionMakeWithPoints(size.width),
                            ASRelativeDimensionMakeWithPoints(size.height));
}

ASRelativeSize ASRelativeSizeMakeWithFraction(CGFloat fraction)
{
  return ASRelativeSizeMake(ASRelativeDimensionMakeWithFraction(fraction),
                            ASRelativeDimensionMakeWithFraction(fraction));
}

CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize, CGSize autoSize)
{
  return CGSizeMake(ASRelativeDimensionResolve(relativeSize.width, autoSize.width, parentSize.width),
                    ASRelativeDimensionResolve(relativeSize.height, autoSize.height, parentSize.height));
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

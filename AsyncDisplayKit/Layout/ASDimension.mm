//
//  ASDimension.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDimension.h"
#import "ASAssert.h"

ASDimension const ASDimensionUnconstrained = {};


#pragma mark - ASDimension

ASDimension ASDimensionMake(ASDimensionType type, CGFloat value)
{
  if (type == ASDimensionTypePoints) {
    ASDisplayNodeCAssertInfOrPositiveReal(@"Points", value);
  } else if (type == ASDimensionTypeFraction) {
    // TODO: Enable this assertion for 2.0.  Check that there is no use case for using a larger value, e.g. to layout for a clipsToBounds = NO element.
    // ASDisplayNodeCAssert( 0 <= value && value <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", value);
  }
  ASDimension dimension; dimension.type = type; dimension.value = value; return dimension;
}

ASDimension ASDimensionMakeWithPoints(CGFloat points)
{
  ASDisplayNodeCAssertInfOrPositiveReal(@"Points", points);
  return ASDimensionMake(ASDimensionTypePoints, points);
}

ASDimension ASDimensionMakeWithFraction(CGFloat fraction)
{
  // ASDisplayNodeCAssert( 0 <= fraction && fraction <= 1.0, @"ASDimension fraction value (%f) must be between 0 and 1.", fraction);
  return ASDimensionMake(ASDimensionTypeFraction, fraction);
}

ASDimension ASDimensionCopy(ASDimension aDimension)
{
  return ASDimensionMake(aDimension.type, aDimension.value);
}

BOOL ASDimensionEqualToDimension(ASDimension lhs, ASDimension rhs)
{
  return lhs.type == rhs.type && lhs.value == rhs.value;
}

CGFloat ASDimensionGetPoints(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.type == ASDimensionTypePoints, @"Only points allowed");
  return dimension.value;
}

CGFloat ASDimensionGetFraction(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.type == ASDimensionTypeFraction, @"Only points allowed");
  return dimension.value;
}

NSString *NSStringFromASDimension(ASDimension dimension)
{
  switch (dimension.type) {
    case ASDimensionTypePoints:
      return [NSString stringWithFormat:@"%.0fpt", dimension.value];
    case ASDimensionTypeFraction:
      return [NSString stringWithFormat:@"%.0f%%", dimension.value * 100.0];
  }
}

CGFloat ASDimensionResolve(ASDimension dimension, CGFloat parent)
{
  switch (dimension.type) {
    case ASDimensionTypePoints:
      return dimension.value;
    case ASDimensionTypeFraction:
      return dimension.value * parent;
  }
}

#pragma mark - ASRelativeSize


OVERLOADABLE ASRelativeSize ASRelativeSizeMake(ASDimension width, ASDimension height)
{
  ASRelativeSize size; size.width = width; size.height = height; return size;
}

OVERLOADABLE ASRelativeSize ASRelativeSizeMake(CGSize exactSize)
{
  return ASRelativeSizeMake(ASDimensionMakeWithPoints(exactSize.width),
                            ASDimensionMakeWithPoints(exactSize.height));
}

OVERLOADABLE ASRelativeSize ASRelativeSizeMake(CGFloat exactFraction)
{
  return ASRelativeSizeMake(ASDimensionMakeWithFraction(exactFraction),
                            ASDimensionMakeWithFraction(exactFraction));
}

ASRelativeSize ASRelativeSizeMakeWithCGSize(CGSize size)
{
  return ASRelativeSizeMake(ASDimensionMakeWithPoints(size.width),
                            ASDimensionMakeWithPoints(size.height));
}

ASRelativeSize ASRelativeSizeMakeWithFraction(CGFloat fraction)
{
  return ASRelativeSizeMake(ASDimensionMakeWithFraction(fraction),
                            ASDimensionMakeWithFraction(fraction));
}

CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize)
{
  return CGSizeMake(ASDimensionResolve(relativeSize.width, parentSize.width),
                    ASDimensionResolve(relativeSize.height, parentSize.height));
}

BOOL ASRelativeSizeEqualToRelativeSize(ASRelativeSize lhs, ASRelativeSize rhs)
{
  return ASDimensionEqualToDimension(lhs.width, rhs.width) &&
         ASDimensionEqualToDimension(lhs.height, rhs.height);
}

CGSize CGSizeFromASRelativeSize(ASRelativeSize relativeSize)
{
  return CGSizeMake(ASDimensionGetPoints(relativeSize.width),
                    ASDimensionGetPoints(relativeSize.height));
}

NSString *NSStringFromASRelativeSize(ASRelativeSize size)
{
  return [NSString stringWithFormat:@"{%@, %@}",
          NSStringFromASDimension(size.width),
          NSStringFromASDimension(size.height)];
}


#pragma mark - ASSizeRange

ASSizeRange const ASSizeRangeUnconstrained = {};

OVERLOADABLE ASSizeRange ASSizeRangeMake(ASRelativeSize min, ASRelativeSize max)
{
  ASSizeRange sizeRange; sizeRange.min = min; sizeRange.max = max; return sizeRange;
}

OVERLOADABLE ASSizeRange ASSizeRangeMake(ASRelativeSize exact)
{
  return ASSizeRangeMake(exact, exact);
}

OVERLOADABLE ASSizeRange ASSizeRangeMake(CGSize exact)
{
  return ASSizeRangeMake(exact, exact);
}

OVERLOADABLE ASSizeRange ASSizeRangeMake(ASDimension exactWidth, ASDimension exactHeight)
{
  return ASSizeRangeMake(ASRelativeSizeMake(exactWidth, exactHeight));
}

OVERLOADABLE ASSizeRange ASSizeRangeMake(CGSize min, CGSize max)
{
  ASDisplayNodeCAssertPositiveReal(@"Range min width", min.width);
  ASDisplayNodeCAssertPositiveReal(@"Range min height", min.height);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max width", max.width);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max height", max.height);
  ASDisplayNodeCAssert(min.width <= max.width,
                       @"Range min width (%f) must not be larger than max width (%f).", min.width, max.width);
  ASDisplayNodeCAssert(min.height <= max.height,
                       @"Range min height (%f) must not be larger than max height (%f).", min.height, max.height);

  return ASSizeRangeMake(
    ASDimensionMakeWithPoints(min.width),
    ASDimensionMakeWithPoints(max.width),
    ASDimensionMakeWithPoints(min.height),
    ASDimensionMakeWithPoints(max.height)
  );
}

OVERLOADABLE ASSizeRange ASSizeRangeMake(ASDimension minWidth, ASDimension maxWidth,
                                         ASDimension minHeight, ASDimension maxHeight)
{
  return ASSizeRangeMake(ASRelativeSizeMake(minWidth, minHeight), ASRelativeSizeMake(maxWidth, maxHeight));
}

BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs)
{
  return ASRelativeSizeEqualToRelativeSize(lhs.min, rhs.min) && ASRelativeSizeEqualToRelativeSize(lhs.max, rhs.max);
}

CGSize ASSizeRangeGetMinSize(ASSizeRange sizeRange)
{
  return CGSizeFromASRelativeSize(sizeRange.min);
}

CGSize ASSizeRangeGetMaxSize(ASSizeRange sizeRange)
{
  return CGSizeFromASRelativeSize(sizeRange.max);
}

CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size)
{
  return CGSizeMake(MAX(ASDimensionGetPoints(sizeRange.min.width),
                        MIN(ASDimensionGetPoints(sizeRange.max.width), size.width)),
                    MAX(ASDimensionGetPoints(sizeRange.min.height),
                        MIN(ASDimensionGetPoints(sizeRange.max.height), size.height)));
}

ASSizeRange ASSizeRangeResolve(ASSizeRange relativeSizeRange, CGSize parentSize)
{
  return ASSizeRangeMake(ASRelativeSizeResolveSize(relativeSizeRange.min, parentSize),
                         ASRelativeSizeResolveSize(relativeSizeRange.max, parentSize));
}

struct _Range {
  CGFloat min;
  CGFloat max;
  
  /**
   Intersects another dimension range. If the other range does not overlap, this size range "wins" by returning a
   single point within its own range that is closest to the non-overlapping range.
   */
  _Range intersect(const _Range &other) const
  {
  CGFloat newMin = MAX(min, other.min);
  CGFloat newMax = MIN(max, other.max);
  if (newMin <= newMax) {
    return {newMin, newMax};
  } else {
    // No intersection. If we're before the other range, return our max; otherwise our min.
    if (min < other.min) {
      return {max, max};
    } else {
      return {min, min};
    }
  }
  }
};

ASSizeRange ASSizeRangeIntersection(ASSizeRange sizeRange, ASSizeRange otherSizeRange)
{
  auto w = _Range({ASDimensionGetPoints(sizeRange.min.width),
                   ASDimensionGetPoints(sizeRange.max.width)})
                .intersect({ASDimensionGetPoints(otherSizeRange.min.width),
                             ASDimensionGetPoints(otherSizeRange.max.width)});
  auto h = _Range({ASDimensionGetPoints(sizeRange.min.height),
                   ASDimensionGetPoints(sizeRange.max.height)})
                .intersect({ASDimensionGetPoints(otherSizeRange.min.height),
                            ASDimensionGetPoints(otherSizeRange.max.height)});
  return ASSizeRangeMake({w.min, h.min}, {w.max, h.max});
}

NSString *NSStringFromASSizeRange(ASSizeRange sizeRange)
{
  return [NSString stringWithFormat:@"{%@, %@}",
          NSStringFromASRelativeSize(sizeRange.min),
          NSStringFromASRelativeSize(sizeRange.max)];
}

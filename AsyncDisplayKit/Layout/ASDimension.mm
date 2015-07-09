/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASDimension.h"
#import "ASAssert.h"

ASRelativeDimension const ASRelativeDimensionUnconstrained = {};

#pragma mark ASRelativeDimension

ASRelativeDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value)
{
  if (type == ASRelativeDimensionTypePoints) { ASDisplayNodeCAssertPositiveReal(@"Points", value); }
  ASRelativeDimension dimension; dimension.type = type; dimension.value = value; return dimension;
}

ASRelativeDimension ASRelativeDimensionMakeWithPoints(CGFloat points)
{
  return ASRelativeDimensionMake(ASRelativeDimensionTypePoints, points);
}

ASRelativeDimension ASRelativeDimensionMakeWithPercent(CGFloat percent)
{
  return ASRelativeDimensionMake(ASRelativeDimensionTypePercent, percent);
}

ASRelativeDimension ASRelativeDimensionCopy(ASRelativeDimension aDimension)
{
  return ASRelativeDimensionMake(aDimension.type, aDimension.value);
}

BOOL ASRelativeDimensionEqualToRelativeDimension(ASRelativeDimension lhs, ASRelativeDimension rhs)
{
  return lhs.type == rhs.type && lhs.value == rhs.value;
}

NSString *NSStringFromASRelativeDimension(ASRelativeDimension dimension)
{
  switch (dimension.type) {
    case ASRelativeDimensionTypePoints:
      return [NSString stringWithFormat:@"%.0fpt", dimension.value];
    case ASRelativeDimensionTypePercent:
      return [NSString stringWithFormat:@"%.0f%%", dimension.value * 100.0];
  }
}

CGFloat ASRelativeDimensionResolve(ASRelativeDimension dimension, CGFloat parent)
{
  switch (dimension.type) {
    case ASRelativeDimensionTypePoints:
      return dimension.value;
    case ASRelativeDimensionTypePercent:
      return round(dimension.value * parent);
  }
}

#pragma mark -
#pragma mark ASSizeRange

ASSizeRange ASSizeRangeMake(CGSize min, CGSize max)
{
  ASDisplayNodeCAssertPositiveReal(@"Range min width", min.width);
  ASDisplayNodeCAssertPositiveReal(@"Range min height", min.height);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max width", max.width);
  ASDisplayNodeCAssertInfOrPositiveReal(@"Range max height", max.height);
  ASDisplayNodeCAssert(min.width <= max.width,
                       @"Range min width (%f) must not be larger than max width (%f).", min.width, max.width);
  ASDisplayNodeCAssert(min.height <= max.height,
                       @"Range min height (%f) must not be larger than max height (%f).", min.height, max.height);
  ASSizeRange sizeRange; sizeRange.min = min; sizeRange.max = max; return sizeRange;
}

CGSize ASSizeRangeClamp(ASSizeRange sizeRange, CGSize size)
{
  return CGSizeMake(MAX(sizeRange.min.width, MIN(sizeRange.max.width, size.width)),
                    MAX(sizeRange.min.height, MIN(sizeRange.max.height, size.height)));
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
  if (!(newMin > newMax)) {
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

ASSizeRange ASSizeRangeIntersect(ASSizeRange sizeRange, ASSizeRange otherSizeRange)
{
  auto w = _Range({sizeRange.min.width, sizeRange.max.width}).intersect({otherSizeRange.min.width, otherSizeRange.max.width});
  auto h = _Range({sizeRange.min.height, sizeRange.max.height}).intersect({otherSizeRange.min.height, otherSizeRange.max.height});
  return {{w.min, h.min}, {w.max, h.max}};
}

BOOL ASSizeRangeEqualToSizeRange(ASSizeRange lhs, ASSizeRange rhs)
{
  return CGSizeEqualToSize(lhs.min, rhs.min) && CGSizeEqualToSize(lhs.max, rhs.max);
}

NSString * NSStringFromASSizeRange(ASSizeRange sizeRange)
{
  return [NSString stringWithFormat:@"<ASSizeRange: min=%@, max=%@>",
          NSStringFromCGSize(sizeRange.min),
          NSStringFromCGSize(sizeRange.max)];
}

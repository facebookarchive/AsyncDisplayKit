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

ASRelativeDimension const ASRelativeDimensionAuto = {ASRelativeDimensionTypeAuto, 0};

#pragma mark - ASRelativeDimension

ASRelativeDimension ASRelativeDimensionMake(ASRelativeDimensionType type, CGFloat value)
{
  if (type == ASRelativeDimensionTypePoints) {
    ASDisplayNodeCAssertPositiveReal(@"Points", value);
  } else if (type == ASRelativeDimensionTypeFraction) {
    // TODO: Enable this assertion for 2.0.  Check that there is no use case for using a larger value, e.g. to layout for a clipsToBounds = NO element.
    // ASDisplayNodeCAssert( 0 <= value && value <= 1.0, @"ASRelativeDimension fraction value (%f) must be between 0 and 1.", value);
  }
  ASRelativeDimension dimension; dimension.type = type; dimension.value = value; return dimension;
}

ASRelativeDimension ASRelativeDimensionMakeWithPoints(CGFloat points)
{
  ASDisplayNodeCAssertPositiveReal(@"Points", points);
  return ASRelativeDimensionMake(ASRelativeDimensionTypePoints, points);
}

ASRelativeDimension ASRelativeDimensionMakeWithFraction(CGFloat fraction)
{
  // ASDisplayNodeCAssert( 0 <= fraction && fraction <= 1.0, @"ASRelativeDimension fraction value (%f) must be between 0 and 1.", fraction);
  return ASRelativeDimensionMake(ASRelativeDimensionTypeFraction, fraction);
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
    case ASRelativeDimensionTypeFraction:
      return [NSString stringWithFormat:@"%.0f%%", dimension.value * 100.0];
    case ASRelativeDimensionTypeAuto:
      return @"Auto";
  }
}

CGFloat ASRelativeDimensionResolve(ASRelativeDimension dimension, CGFloat autoSize, CGFloat parent)
{
  switch (dimension.type) {
    case ASRelativeDimensionTypeAuto:
      return autoSize;
    case ASRelativeDimensionTypePoints:
      return dimension.value;
    case ASRelativeDimensionTypeFraction:
      return dimension.value * parent;
  }
}

#pragma mark - ASRelativeSize

ASRelativeSize ASRelativeSizeMake(ASRelativeDimension width, ASRelativeDimension height)
{
  ASRelativeSize size; size.width = width; size.height = height; return size;
}

// ** Resolve this relative size relative to a parent size. */
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

#pragma mark - ASSize

ASSize ASSizeMake()
{
  return (ASSize){
    .width = ASRelativeDimensionAuto,
    .height = ASRelativeDimensionAuto,
    .minWidth = ASRelativeDimensionAuto,
    .maxWidth = ASRelativeDimensionAuto,
    .minHeight = ASRelativeDimensionAuto,
    .maxHeight = ASRelativeDimensionAuto
  };
}

ASSize ASSizeMakeFromCGSize(CGSize size)
{
  ASSize s = ASSizeMake();
  s.width = ASRelativeDimensionMakeWithPoints(size.width);
  s.height = ASRelativeDimensionMakeWithPoints(size.height);
  return s;
}

BOOL ASSizeEqualToSize(ASSize lhs, ASSize rhs)
{
  return ASRelativeDimensionEqualToRelativeDimension(lhs.width, rhs.width)
  && ASRelativeDimensionEqualToRelativeDimension(lhs.height, rhs.height)
  && ASRelativeDimensionEqualToRelativeDimension(lhs.minWidth, rhs.minWidth)
  && ASRelativeDimensionEqualToRelativeDimension(lhs.maxWidth, rhs.maxWidth)
  && ASRelativeDimensionEqualToRelativeDimension(lhs.minHeight, rhs.minHeight)
  && ASRelativeDimensionEqualToRelativeDimension(lhs.maxHeight, rhs.maxHeight);
}

NSString *NSStringFromASSize(ASSize size)
{
  return [NSString stringWithFormat:
          @"<ASSize: exact=%@, min=%@, max=%@>",
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.width, size.height)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.minWidth, size.minHeight)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.maxWidth, size.maxHeight))];
}

static inline void ASSizeConstrain(CGFloat minVal, CGFloat exactVal, CGFloat maxVal, CGFloat *outMin, CGFloat *outMax)
{
    NSCAssert(!isnan(minVal), @"minVal must not be NaN");
    NSCAssert(!isnan(maxVal), @"maxVal must not be NaN");
    // Avoid use of min/max primitives since they're harder to reason
    // about in the presence of NaN (in exactVal)
    // Follow CSS: min overrides max overrides exact.

    // Begin with the min/max range
    *outMin = minVal;
    *outMax = maxVal;
    if (maxVal <= minVal) {
        // min overrides max and exactVal is irrelevant
        *outMax = minVal;
        return;
    }
    if (isnan(exactVal)) {
        // no exact value, so leave as a min/max range
        return;
    }
    if (exactVal > maxVal) {
        // clip to max value
        *outMin = maxVal;
    } else if (exactVal < minVal) {
        // clip to min value
        *outMax = minVal;
    } else {
        // use exact value
        *outMin = *outMax = exactVal;
    }
}

ASSizeRange ASSizeResolveAutoSize(ASSize size, const CGSize parentSize, ASSizeRange autoASSizeRange)
{
  CGSize resolvedExact = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.width, size.height), parentSize, {NAN, NAN});
  CGSize resolvedMin = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.minWidth, size.minHeight), parentSize, autoASSizeRange.min);
  CGSize resolvedMax = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.maxWidth, size.maxHeight), parentSize, autoASSizeRange.max);
  
  CGSize rangeMin, rangeMax;
  ASSizeConstrain(resolvedMin.width, resolvedExact.width, resolvedMax.width, &rangeMin.width, &rangeMax.width);
  ASSizeConstrain(resolvedMin.height, resolvedExact.height, resolvedMax.height, &rangeMin.height, &rangeMax.height);
  return {rangeMin, rangeMax};
}

ASSizeRange ASSizeResolve(ASSize size, const CGSize parentSize)
{
  return ASSizeResolveAutoSize(size, parentSize, {{0, 0}, {INFINITY, INFINITY}});
}

#pragma mark - ASSizeRange

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

ASSizeRange ASSizeRangeMakeWithExactCGSize(CGSize size)
{
  return ASSizeRangeMake(size, size);
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

#pragma mark - Deprecated

ASSizeRange ASSizeRangeMakeExactSize(CGSize size)
{
  return ASSizeRangeMakeWithExactCGSize(size);
}

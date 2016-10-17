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
#import "CoreGraphics+ASConvenience.h"

#pragma mark - ASDimension

ASDimension const ASDimensionAuto = {ASDimensionUnitAuto, 0};

ASOVERLOADABLE ASDimension ASDimensionMake(NSString *dimension)
{
  if (dimension.length > 0) {
    
    // Handle points
    if ([dimension hasSuffix:@"pt"]) {
      return ASDimensionMake(ASDimensionUnitPoints, ASCGFloatFromString(dimension));
    }
    
    // Handle auto
    if ([dimension isEqualToString:@"auto"]) {
      return ASDimensionAuto;
    }
  
    // Handle percent
    if ([dimension hasSuffix:@"%"]) {
      return ASDimensionMake(ASDimensionUnitFraction, (ASCGFloatFromString(dimension) / 100.0));
    }
  }
  
  ASDisplayNodeCAssert(NO, @"Parsing dimension failed for: %@", dimension);
  return ASDimensionAuto;
}

NSString *NSStringFromASDimension(ASDimension dimension)
{
  switch (dimension.unit) {
    case ASDimensionUnitPoints:
      return [NSString stringWithFormat:@"%.0fpt", dimension.value];
    case ASDimensionUnitFraction:
      return [NSString stringWithFormat:@"%.0f%%", dimension.value * 100.0];
    case ASDimensionUnitAuto:
      return @"Auto";
  }
}


#pragma mark - NSNumber+ASDimension

@implementation NSNumber (ASDimension)

- (ASDimension)as_pointDimension
{
  return ASDimensionMake(ASDimensionUnitPoints, ASCGFloatFromNumber(self));
}

- (ASDimension)as_fractionDimension
{
  return ASDimensionMake(ASDimensionUnitFraction, ASCGFloatFromNumber(self));
}

@end


#pragma mark - ASLayoutSize

// ** Resolve this relative size relative to a parent size. */
ASDISPLAYNODE_INLINE CGSize ASLayoutSizeResolveSize(ASLayoutSize layoutSize, CGSize parentSize, CGSize autoSize)
{
  return CGSizeMake(ASDimensionResolve(layoutSize.width, parentSize.width, autoSize.width),
                    ASDimensionResolve(layoutSize.height, parentSize.height, autoSize.height));
}

// ** Returns a string formatted to contain the data from an ASLayoutSize. */
ASDISPLAYNODE_INLINE NSString *NSStringFromASLayoutSize(ASLayoutSize size)
{
  return [NSString stringWithFormat:@"{%@, %@}",
          NSStringFromASDimension(size.width),
          NSStringFromASDimension(size.height)];
}


#pragma mark - ASLayoutElementSize

NSString *NSStringFromASLayoutElementSize(ASLayoutElementSize size)
{
  return [NSString stringWithFormat:
          @"<ASLayoutElementSize: exact=%@, min=%@, max=%@>",
          NSStringFromASLayoutSize(ASLayoutSizeMake(size.width, size.height)),
          NSStringFromASLayoutSize(ASLayoutSizeMake(size.minWidth, size.minHeight)),
          NSStringFromASLayoutSize(ASLayoutSizeMake(size.maxWidth, size.maxHeight))];
}

ASDISPLAYNODE_INLINE void ASLayoutElementSizeConstrain(CGFloat minVal, CGFloat exactVal, CGFloat maxVal, CGFloat *outMin, CGFloat *outMax)
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

ASSizeRange ASLayoutElementSizeResolveAutoSize(ASLayoutElementSize size, const CGSize parentSize, ASSizeRange autoASSizeRange)
{
  CGSize resolvedExact = ASLayoutSizeResolveSize(ASLayoutSizeMake(size.width, size.height), parentSize, {NAN, NAN});
  CGSize resolvedMin = ASLayoutSizeResolveSize(ASLayoutSizeMake(size.minWidth, size.minHeight), parentSize, autoASSizeRange.min);
  CGSize resolvedMax = ASLayoutSizeResolveSize(ASLayoutSizeMake(size.maxWidth, size.maxHeight), parentSize, autoASSizeRange.max);
  
  CGSize rangeMin, rangeMax;
  ASLayoutElementSizeConstrain(resolvedMin.width, resolvedExact.width, resolvedMax.width, &rangeMin.width, &rangeMax.width);
  ASLayoutElementSizeConstrain(resolvedMin.height, resolvedExact.height, resolvedMax.height, &rangeMin.height, &rangeMax.height);
  return {rangeMin, rangeMax};
}


#pragma mark - ASSizeRange

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

NSString *NSStringFromASSizeRange(ASSizeRange sizeRange)
{
  return [NSString stringWithFormat:@"<ASSizeRange: min=%@, max=%@>",
          NSStringFromCGSize(sizeRange.min),
          NSStringFromCGSize(sizeRange.max)];
}


#pragma mark - Deprecated

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

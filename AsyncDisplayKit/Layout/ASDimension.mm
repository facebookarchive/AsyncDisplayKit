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

#pragma mark - ASDimension

ASDimension const ASDimensionAuto = {ASDimensionUnitAuto, 0};

ASOVERLOADABLE ASDimension ASDimensionMake(NSString *dimension)
{
  // Handle empty string
  if (dimension.length == 0) {
    return ASDimensionMake(ASDimensionUnitPoints, 0.0);
  }
  
  // Handle points
  NSUInteger pointsStringLocation = [dimension rangeOfString:@"pt"].location;
  if (pointsStringLocation != NSNotFound) {
    // Check if points is at the end and remove it
    if (pointsStringLocation == (dimension.length-2)) {
      dimension = [dimension substringToIndex:(dimension.length-2)];
      return ASDimensionMake(ASDimensionUnitPoints, dimension.floatValue);
    }
  }
  
  // Handle fraction
  NSUInteger percentStringLocation = [dimension rangeOfString:@"%"].location;
  if (percentStringLocation != NSNotFound) {
    // Check if percent is at the end and remove it
    if (percentStringLocation == (dimension.length-1)) {
      dimension = [dimension substringToIndex:(dimension.length-1)];
      return ASDimensionMake(ASDimensionUnitFraction, dimension.floatValue);
    }
  }

  // Assert as parsing went wrong
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
  return ASDimensionMake(ASDimensionUnitPoints, self.floatValue);
}

- (ASDimension)as_fractionDimension
{
  return ASDimensionMake(ASDimensionUnitFraction, self.floatValue);
}

@end


#pragma mark - ASRelativeSize

/**
 * Expresses a size with relative dimensions. Only used for calculations internally in ASDimension.h 
 */
typedef struct {
  ASDimension width;
  ASDimension height;
} ASRelativeSize;

ASDISPLAYNODE_INLINE ASRelativeSize ASRelativeSizeMake(ASDimension width, ASDimension height)
{
  ASRelativeSize size;
  size.width = width;
  size.height = height;
  return size;
}

// ** Resolve this relative size relative to a parent size. */
ASDISPLAYNODE_INLINE CGSize ASRelativeSizeResolveSize(ASRelativeSize relativeSize, CGSize parentSize, CGSize autoSize)
{
  return CGSizeMake(ASDimensionResolve(relativeSize.width, parentSize.width, autoSize.width),
                    ASDimensionResolve(relativeSize.height, parentSize.height, autoSize.height));
}

// ** Returns a string formatted to contain the data from an ASRelativeSize. */
ASDISPLAYNODE_INLINE NSString *NSStringFromASRelativeSize(ASRelativeSize size)
{
  return [NSString stringWithFormat:@"{%@, %@}",
          NSStringFromASDimension(size.width),
          NSStringFromASDimension(size.height)];
}


#pragma mark - ASLayoutableSize

NSString *NSStringFromASLayoutableSize(ASLayoutableSize size)
{
  return [NSString stringWithFormat:
          @"<ASLayoutableSize: exact=%@, min=%@, max=%@>",
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.width, size.height)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.minWidth, size.minHeight)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(size.maxWidth, size.maxHeight))];
}

ASDISPLAYNODE_INLINE void ASLayoutableSizeConstrain(CGFloat minVal, CGFloat exactVal, CGFloat maxVal, CGFloat *outMin, CGFloat *outMax)
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

ASSizeRange ASLayoutableSizeResolveAutoSize(ASLayoutableSize size, const CGSize parentSize, ASSizeRange autoASSizeRange)
{
  CGSize resolvedExact = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.width, size.height), parentSize, {NAN, NAN});
  CGSize resolvedMin = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.minWidth, size.minHeight), parentSize, autoASSizeRange.min);
  CGSize resolvedMax = ASRelativeSizeResolveSize(ASRelativeSizeMake(size.maxWidth, size.maxHeight), parentSize, autoASSizeRange.max);
  
  CGSize rangeMin, rangeMax;
  ASLayoutableSizeConstrain(resolvedMin.width, resolvedExact.width, resolvedMax.width, &rangeMin.width, &rangeMax.width);
  ASLayoutableSizeConstrain(resolvedMin.height, resolvedExact.height, resolvedMax.height, &rangeMin.height, &rangeMax.height);
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

ASSizeRange ASSizeRangeMakeExactSize(CGSize size)
{
  return ASSizeRangeMake(size);
}

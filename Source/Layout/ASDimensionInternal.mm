//
//  ASDimensionInternal.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDimensionInternal.h>

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

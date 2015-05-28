/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutNodeSize.h"
#import "ASAssert.h"

ASLayoutNodeSize const ASLayoutNodeSizeZero = {};

ASLayoutNodeSize ASLayoutNodeSizeMakeWithCGSize(CGSize size)
{
  return ASLayoutNodeSizeMake(size.width, size.height);
}

ASLayoutNodeSize ASLayoutNodeSizeMake(CGFloat width, CGFloat height)
{
  return {ASRelativeDimensionMakeWithPoints(width), ASRelativeDimensionMakeWithPoints(height)};
}

ASDISPLAYNODE_INLINE void ASLNSConstrain(CGFloat minVal, CGFloat exactVal, CGFloat maxVal, CGFloat *outMin, CGFloat *outMax)
{
  ASDisplayNodeCAssert(!isnan(minVal), @"minVal must not be NaN");
  ASDisplayNodeCAssert(!isnan(maxVal), @"maxVal must not be NaN");
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

ASSizeRange ASLayoutNodeSizeResolve(ASLayoutNodeSize nodeSize, CGSize parentSize)
{
  CGSize resolvedExact = ASRelativeSizeResolveSize(ASRelativeSizeMake(nodeSize.width, nodeSize.height), parentSize, {NAN, NAN});
  CGSize resolvedMin = ASRelativeSizeResolveSize(ASRelativeSizeMake(nodeSize.minWidth, nodeSize.minHeight), parentSize, {0, 0});
  CGSize resolvedMax = ASRelativeSizeResolveSize(ASRelativeSizeMake(nodeSize.maxWidth, nodeSize.maxHeight), parentSize, {INFINITY, INFINITY});
  
  CGSize rangeMin, rangeMax;
  ASLNSConstrain(resolvedMin.width, resolvedExact.width, resolvedMax.width, &rangeMin.width, &rangeMax.width);
  ASLNSConstrain(resolvedMin.height, resolvedExact.height, resolvedMax.height, &rangeMin.height, &rangeMax.height);
  return {rangeMin, rangeMax};
}

BOOL ASLayoutNodeSizeEqualToNodeSize(ASLayoutNodeSize lhs, ASLayoutNodeSize rhs)
{
  return ASRelativeDimensionEqualToDimension(lhs.width, rhs.width)
  && ASRelativeDimensionEqualToDimension(lhs.height, rhs.height)
  && ASRelativeDimensionEqualToDimension(lhs.minWidth, rhs.minWidth)
  && ASRelativeDimensionEqualToDimension(lhs.minHeight, rhs.minHeight)
  && ASRelativeDimensionEqualToDimension(lhs.maxWidth, rhs.maxWidth)
  && ASRelativeDimensionEqualToDimension(lhs.maxHeight, rhs.maxHeight);
}

NSString *NSStringFromASLayoutNodeSize(ASLayoutNodeSize nodeSize)
{
  return [NSString stringWithFormat:@"<ASLayoutNodeSize: exact=%@, min=%@, max=%@>",
          NSStringFromASRelativeSize(ASRelativeSizeMake(nodeSize.width, nodeSize.height)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(nodeSize.minWidth, nodeSize.minHeight)),
          NSStringFromASRelativeSize(ASRelativeSizeMake(nodeSize.maxWidth, nodeSize.maxHeight))];
}

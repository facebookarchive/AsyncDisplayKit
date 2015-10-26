/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASRatioLayoutSpec.h"

#import <algorithm>
#import <vector>

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@implementation ASRatioLayoutSpec
{
  CGFloat _ratio;
}

+ (instancetype)ratioLayoutSpecWithRatio:(CGFloat)ratio child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithRatio:ratio child:child];
}

- (instancetype)initWithRatio:(CGFloat)ratio child:(id<ASLayoutable>)child;
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  ASDisplayNodeAssert(ratio > 0, @"Ratio should be strictly positive, but received %f", ratio);
  _ratio = ratio;
  [self setChild:child];
  return self;
}

- (void)setRatio:(CGFloat)ratio
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _ratio = ratio;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  std::vector<CGSize> sizeOptions;
  if (!isinf(constrainedSize.max.width)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      constrainedSize.max.width,
      ASFloorPixelValue(_ratio * constrainedSize.max.width)
    }));
  }
  if (!isinf(constrainedSize.max.height)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      ASFloorPixelValue(constrainedSize.max.height / _ratio),
      constrainedSize.max.height
    }));
  }

  // Choose the size closest to the desired ratio.
  const auto &bestSize = std::max_element(sizeOptions.begin(), sizeOptions.end(), [&](const CGSize &a, const CGSize &b){
    return fabs((a.height / a.width) - _ratio) > fabs((b.height / b.width) - _ratio);
  });

  // If there is no max size in *either* dimension, we can't apply the ratio, so just pass our size range through.
  const ASSizeRange childRange = (bestSize == sizeOptions.end()) ? constrainedSize : ASSizeRangeMake(*bestSize, *bestSize);
  ASLayout *sublayout = [self.child measureWithSizeRange:childRange];
  sublayout.position = CGPointZero;
  return [ASLayout layoutWithLayoutableObject:self size:sublayout.size sublayouts:@[sublayout]];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
}

- (NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
  return nil;
}

@end

@implementation ASRatioLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)asciiArtName
{
  return [NSString stringWithFormat:@"%@ (%.1f)", NSStringFromClass([self class]), self.ratio];
}

@end

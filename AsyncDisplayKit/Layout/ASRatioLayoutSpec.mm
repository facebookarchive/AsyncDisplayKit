//
//  ASRatioLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASRatioLayoutSpec.h"

#import <tgmath.h>
#import <vector>

#import "ASAssert.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASThread.h"

#pragma mark - ASRatioLayoutSpecStyleDescription

@implementation ASRatioLayoutSpecStyleDescription

@end

#pragma mark - ASRatioLayoutSpec

@implementation ASRatioLayoutSpec {
  ASDN::RecursiveMutex __instanceLock__;
  ASRatioLayoutSpecStyleDescription *_style;
}

#pragma mark - Class

+ (instancetype)ratioLayoutSpecWithRatio:(CGFloat)ratio child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithRatio:ratio child:child];
}

#pragma mark - Lifecycle

- (instancetype)initWithRatio:(CGFloat)ratio child:(id<ASLayoutable>)child;
{
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  ASDisplayNodeAssert(ratio > 0, @"Ratio should be strictly positive, but received %f", ratio);
  
  if (!(self = [super init])) {
    return nil;
  }
  
  _style = [[ASRatioLayoutSpecStyleDescription alloc] init];
  _style.ratio = ratio;
  
  self.child = child;

  return self;
}

#pragma mark - Getter / Setter

- (ASRatioLayoutSpecStyleDescription *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}


#pragma mark - ASLayoutSpec

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  CGFloat ratio = _style.ratio;
  
  std::vector<CGSize> sizeOptions;
  // TODO: layout: isValidForLayout() call should not be necessary if INFINITY is used
  if (!isinf(constrainedSize.max.width) && ASPointsAreValidForLayout(constrainedSize.max.width)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      constrainedSize.max.width,
      ASFloorPixelValue(ratio * constrainedSize.max.width)
    }));
  }
  // TODO: layout: isValidForLayout() call should not be necessary if INFINITY is used
  if (!isinf(constrainedSize.max.height) && ASPointsAreValidForLayout(constrainedSize.max.width)) {
    sizeOptions.push_back(ASSizeRangeClamp(constrainedSize, {
      ASFloorPixelValue(constrainedSize.max.height / ratio),
      constrainedSize.max.height
    }));
  }

  // Choose the size closest to the desired ratio.
  const auto &bestSize = std::max_element(sizeOptions.begin(), sizeOptions.end(), [&](const CGSize &a, const CGSize &b){
    return std::fabs((a.height / a.width) - ratio) > std::fabs((b.height / b.width) - ratio);
  });

  // If there is no max size in *either* dimension, we can't apply the ratio, so just pass our size range through.
  const ASSizeRange childRange = (bestSize == sizeOptions.end()) ? constrainedSize : ASSizeRangeMake(*bestSize, *bestSize);
  const CGSize parentSize = (bestSize == sizeOptions.end()) ? ASLayoutableParentSizeUndefined : *bestSize;
  ASLayout *sublayout = [self.child layoutThatFits:childRange parentSize:parentSize];
  sublayout.position = CGPointZero;
  return [ASLayout layoutWithLayoutable:self size:sublayout.size sublayouts:@[sublayout]];
}

@end

@implementation ASRatioLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)asciiArtName
{
  return [NSString stringWithFormat:@"%@ (%.1f)", NSStringFromClass([self class]), self.style.ratio];
}

@end

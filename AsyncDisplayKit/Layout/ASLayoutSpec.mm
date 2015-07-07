/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutSpec.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@implementation ASLayoutSpec

@synthesize spacingBefore = _spacingBefore;
@synthesize spacingAfter = _spacingAfter;
@synthesize flexGrow = _flexGrow;
@synthesize flexShrink = _flexShrink;
@synthesize flexBasis = _flexBasis;
@synthesize alignSelf = _alignSelf;

+ (instancetype)new
{
  ASLayoutSpec *spec = [super new];
  if (spec) {
    spec->_flexBasis = ASRelativeDimensionUnconstrained;
  }
  return spec;
}

#pragma mark - Layout

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [ASLayout newWithLayoutableObject:self size:constrainedSize.min];
}

@end

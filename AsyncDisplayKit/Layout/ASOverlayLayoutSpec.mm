/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASOverlayLayoutSpec.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"
#import "ASLayout.h"

@implementation ASOverlayLayoutSpec
{
  id<ASLayoutable> _overlay;
  id<ASLayoutable> _child;
}

+ (instancetype)newWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  ASOverlayLayoutSpec *spec = [super new];
  if (spec) {
    ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
    spec->_overlay = overlay;
    spec->_child = child;
  }
  return spec;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 First layout the contents, then fit the overlay on top of it.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASLayout *contentsLayout = [_child measureWithSizeRange:constrainedSize];
  contentsLayout.position = CGPointZero;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithObject:contentsLayout];
  if (_overlay) {
    ASLayout *overlayLayout = [_overlay measureWithSizeRange:{contentsLayout.size, contentsLayout.size}];
    overlayLayout.position = CGPointZero;
    [sublayouts addObject:overlayLayout];
  }
  
  return [ASLayout newWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

@end

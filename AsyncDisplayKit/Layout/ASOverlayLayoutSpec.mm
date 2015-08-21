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

- (instancetype)initWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  self = [super init];
  if (self) {
    ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
    _overlay = overlay;
    _child = child;
  }
  return self;
}

+ (instancetype)overlayLayoutWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  return [[self alloc] initWithChild:child overlay:overlay];
}

- (void)setChild:(id<ASLayoutable>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _child = child;
}

- (void)setOverlay:(id<ASLayoutable>)overlay
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _overlay = overlay;
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
  
  return [ASLayout layoutWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

@end

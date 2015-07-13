/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASBackgroundLayoutSpec.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"
#import "ASLayout.h"

@interface ASBackgroundLayoutSpec ()
{
  id<ASLayoutable> _child;
  id<ASLayoutable> _background;
}
@end

@implementation ASBackgroundLayoutSpec

+ (instancetype)newWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background
{
  if (child == nil) {
    return nil;
  }
  ASBackgroundLayoutSpec *spec = [super new];
  spec->_child = child;
  spec->_background = background;
  return spec;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 First layout the contents, then fit the background image.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASLayout *contentsLayout = [_child measureWithSizeRange:constrainedSize];

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:2];
  if (_background) {
    // Size background to exactly the same size.
    ASLayout *backgroundLayout = [_background measureWithSizeRange:{contentsLayout.size, contentsLayout.size}];
    backgroundLayout.position = CGPointZero;
    [sublayouts addObject:backgroundLayout];
  }
  contentsLayout.position = CGPointZero;
  [sublayouts addObject:contentsLayout];

  return [ASLayout newWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

@end

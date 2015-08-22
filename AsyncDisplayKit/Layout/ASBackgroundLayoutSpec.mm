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

- (instancetype)initWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  _child = child;
  _background = background;
  return self;
}


+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background;
{
  return [[self alloc] initWithChild:child background:background];
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

  return [ASLayout layoutWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

- (void)setBackground:(id<ASLayoutable>)background
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _background = background;
}

- (void)setChild:(id<ASLayoutable>)child
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _child = child;
}

@end

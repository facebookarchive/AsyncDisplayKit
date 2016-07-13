//
//  ASBackgroundLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASBackgroundLayoutSpec.h"

#import "ASAssert.h"
#import "ASLayout.h"

static NSUInteger const kForegroundChildIndex = 0;
static NSUInteger const kBackgroundChildIndex = 1;

@interface ASBackgroundLayoutSpec ()
@end

@implementation ASBackgroundLayoutSpec

- (instancetype)initWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  [self setChild:child forIndex:kForegroundChildIndex];
  self.background = background;
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
  ASLayout *contentsLayout = [[self child] measureWithSizeRange:constrainedSize];

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:2];
  if (self.background) {
    // Size background to exactly the same size.
    ASLayout *backgroundLayout = [self.background measureWithSizeRange:{contentsLayout.size, contentsLayout.size}];
    backgroundLayout.position = CGPointZero;
    [sublayouts addObject:backgroundLayout];
  }
  contentsLayout.position = CGPointZero;
  [sublayouts addObject:contentsLayout];

  return [ASLayout layoutWithLayoutableObject:self
                         constrainedSizeRange:constrainedSize
                                         size:contentsLayout.size
                                   sublayouts:sublayouts];
}

- (void)setBackground:(id<ASLayoutable>)background
{
  [super setChild:background forIndex:kBackgroundChildIndex];
}

- (id<ASLayoutable>)background
{
  return [super childForIndex:kBackgroundChildIndex];
}

@end

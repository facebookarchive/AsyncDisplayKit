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

- (instancetype)initWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  [self setChild:child forIndex:kForegroundChildIndex];
  self.background = background;
  return self;
}

+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background;
{
  return [[self alloc] initWithChild:child background:background];
}

/**
 * First layout the contents, then fit the background image.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASLayout *contentsLayout = [self.child layoutThatFits:constrainedSize parentSize:parentSize];

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:2];
  if (self.background) {
    // Size background to exactly the same size.
    ASLayout *backgroundLayout = [self.background layoutThatFits:ASSizeRangeMake(contentsLayout.size)
                                                      parentSize:parentSize];
    backgroundLayout.position = CGPointZero;
    [sublayouts addObject:backgroundLayout];
  }
  contentsLayout.position = CGPointZero;
  [sublayouts addObject:contentsLayout];

  return [ASLayout layoutWithLayoutElement:self size:contentsLayout.size sublayouts:sublayouts];
}

- (void)setBackground:(id<ASLayoutElement>)background
{
  [super setChild:background forIndex:kBackgroundChildIndex];
}

- (id<ASLayoutElement>)background
{
  return [super childForIndex:kBackgroundChildIndex];
}

@end

//
//  ASBackgroundLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>

#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

#import <AsyncDisplayKit/ASAssert.h>

static NSUInteger const kForegroundChildIndex = 0;
static NSUInteger const kBackgroundChildIndex = 1;

@implementation ASBackgroundLayoutSpec

#pragma mark - Class

+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background;
{
  return [[self alloc] initWithChild:child background:background];
}

#pragma mark - Lifecycle

- (instancetype)initWithChild:(id<ASLayoutElement>)child background:(id<ASLayoutElement>)background
{
  if (!(self = [super init])) {
    return nil;
  }
  self.child = child;
  self.background = background;
  return self;
}

#pragma mark - ASLayoutSpec

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

#pragma mark - Background

- (void)setChild:(id<ASLayoutElement>)child
{
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  [super setChild:child atIndex:kForegroundChildIndex];
}

- (id<ASLayoutElement>)child
{
  return [super childAtIndex:kForegroundChildIndex];
}

- (void)setBackground:(id<ASLayoutElement>)background
{
  ASDisplayNodeAssertNotNil(background, @"Background cannot be nil");
  [super setChild:background atIndex:kBackgroundChildIndex];
}

- (id<ASLayoutElement>)background
{
  return [super childAtIndex:kBackgroundChildIndex];
}

@end

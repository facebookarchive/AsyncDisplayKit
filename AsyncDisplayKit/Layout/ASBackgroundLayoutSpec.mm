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
#import "ASTraitCollection.h"

static NSString * const kBackgroundChildKey = @"kBackgroundChildKey";

@interface ASBackgroundLayoutSpec ()
@end

@implementation ASBackgroundLayoutSpec

- (instancetype)initWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background traitCollection:(ASTraitCollection *)traitCollection
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
  self.environmentTraitCollection = [traitCollection environmentTraitCollection];
  [self setChild:child withTraitCollection:traitCollection];
  [self setBackground:background traitCollection:traitCollection];
  return self;
}

+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background;
{
  return [self backgroundLayoutSpecWithChild:child background:background traitCollect:nil];
}

+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutable>)child background:(nullable id<ASLayoutable>)background traitCollect:(nullable ASTraitCollection *)traitCollection
{
  return [[self alloc] initWithChild:child background:background traitCollection:traitCollection];
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

  return [ASLayout layoutWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

- (void)setBackground:(id<ASLayoutable>)background
{
  [self setBackground:background traitCollection:nil];
}

- (void)setBackground:(id<ASLayoutable>)background traitCollection:(ASTraitCollection *)traitCollection
{
  [super setChild:background forIdentifier:kBackgroundChildKey withTraitCollection:traitCollection];
}

- (id<ASLayoutable>)background
{
  return [super childForIdentifier:kBackgroundChildKey];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
}

@end

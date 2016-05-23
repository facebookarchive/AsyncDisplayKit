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
#import "ASTraitCollection.h"

static NSString * const kOverlayChildKey = @"kOverlayChildKey";

@implementation ASOverlayLayoutSpec

- (instancetype)initWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay traitCollection:(nullable ASTraitCollection *)traitCollection
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
  self.environmentTraitCollection = [traitCollection environmentTraitCollection];
  [self setOverlay:overlay traitCollection:traitCollection];
  [self setChild:child withTraitCollection:traitCollection];
  return self;
}

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  return [self overlayLayoutSpecWithChild:child overlay:overlay traitCollection:nil];
}

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutable>)child overlay:(nullable id<ASLayoutable>)overlay traitCollection:(nullable ASTraitCollection *)traitCollection
{
  return [[self alloc] initWithChild:child overlay:overlay traitCollection:traitCollection];
}

- (void)setOverlay:(id<ASLayoutable>)overlay
{
  [self setOverlay:overlay traitCollection:nil];
}

- (void)setOverlay:(id<ASLayoutable> _Nullable)overlay traitCollection:(nullable ASTraitCollection *)traitCollection
{
  return [super setChild:overlay forIdentifier:kOverlayChildKey withTraitCollection:traitCollection];
}

- (id<ASLayoutable>)overlay
{
  return [super childForIdentifier:kOverlayChildKey];
}

/**
 First layout the contents, then fit the overlay on top of it.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASLayout *contentsLayout = [self.child measureWithSizeRange:constrainedSize];
  contentsLayout.position = CGPointZero;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithObject:contentsLayout];
  if (self.overlay) {
    ASLayout *overlayLayout = [self.overlay measureWithSizeRange:{contentsLayout.size, contentsLayout.size}];
    overlayLayout.position = CGPointZero;
    [sublayouts addObject:overlayLayout];
  }
  
  return [ASLayout layoutWithLayoutableObject:self size:contentsLayout.size sublayouts:sublayouts];
}

- (void)setChildren:(NSArray *)children
{
  ASDisplayNodeAssert(NO, @"not supported by this layout spec");
}

@end

@implementation ASOverlayLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:@[self.overlay, self.child] parentName:[self asciiArtName]];
}

@end

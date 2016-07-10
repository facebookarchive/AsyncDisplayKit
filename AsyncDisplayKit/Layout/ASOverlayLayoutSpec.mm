//
//  ASOverlayLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASOverlayLayoutSpec.h"

#import "ASAssert.h"
#import "ASLayout.h"

static NSUInteger const kUnderlayChildIndex = 0;
static NSUInteger const kOverlayChildIndex = 1;

@implementation ASOverlayLayoutSpec

- (instancetype)initWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
  self.overlay = overlay;
  [self setChild:child forIndex:kUnderlayChildIndex];
  return self;
}

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay
{
  return [[self alloc] initWithChild:child overlay:overlay];
}

- (void)setOverlay:(id<ASLayoutable>)overlay
{
  [super setChild:overlay forIndex:kOverlayChildIndex];
}

- (id<ASLayoutable>)overlay
{
  return [super childForIndex:kOverlayChildIndex];
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
  
  return [ASLayout layoutWithLayoutableObject:self
                         constrainedSizeRange:constrainedSize
                                         size:contentsLayout.size
                                   sublayouts:sublayouts];
}

@end

@implementation ASOverlayLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:@[self.overlay, self.child] parentName:[self asciiArtName]];
}

@end

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
#import "ASLayoutSpec+Subclasses.h"

#import "ASAssert.h"
#import "ASLayoutSpec+Subclasses.h"

static NSUInteger const kUnderlayChildIndex = 0;
static NSUInteger const kOverlayChildIndex = 1;

@implementation ASOverlayLayoutSpec

#pragma mark - Class

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutElement>)child overlay:(id<ASLayoutElement>)overlay
{
  return [[self alloc] initWithChild:child overlay:overlay];
}

#pragma mark - Lifecycle

- (instancetype)initWithChild:(id<ASLayoutElement>)child overlay:(id<ASLayoutElement>)overlay
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssertNotNil(child, @"Child that will be overlayed on shouldn't be nil");
  [self setChild:child atIndex:kUnderlayChildIndex];
  self.overlay = overlay;
  return self;
}

#pragma mark - Setter / Getter

- (void)setOverlay:(id<ASLayoutElement>)overlay
{
  [super setChild:overlay atIndex:kOverlayChildIndex];
}

- (id<ASLayoutElement>)overlay
{
  return [super childAtIndex:kOverlayChildIndex];
}

#pragma mark - ASLayoutSpec

/**
 First layout the contents, then fit the overlay on top of it.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASLayout *contentsLayout = [[super childAtIndex:kUnderlayChildIndex] layoutThatFits:constrainedSize parentSize:parentSize];
  contentsLayout.position = CGPointZero;
  NSMutableArray *sublayouts = [NSMutableArray arrayWithObject:contentsLayout];
  if (self.overlay) {
    ASLayout *overlayLayout = [self.overlay layoutThatFits:ASSizeRangeMake(contentsLayout.size)
                                                parentSize:contentsLayout.size];
    overlayLayout.position = CGPointZero;
    [sublayouts addObject:overlayLayout];
  }
  
  return [ASLayout layoutWithLayoutElement:self size:contentsLayout.size sublayouts:sublayouts];
}

@end

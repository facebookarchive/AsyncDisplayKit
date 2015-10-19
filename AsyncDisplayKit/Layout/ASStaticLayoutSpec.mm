/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStaticLayoutSpec.h"

#import "ASLayoutSpecUtilities.h"
#import "ASLayoutOptions.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASStaticLayoutable.h"

@implementation ASStaticLayoutSpec

+ (instancetype)staticLayoutSpecWithChildren:(NSArray *)children
{
  return [[self alloc] initWithChildren:children];
}

- (instancetype)init
{
    return [self initWithChildren:@[]];
}

- (instancetype)initWithChildren:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  self.children = children;
  return self;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  CGSize size = {
    constrainedSize.max.width,
    constrainedSize.max.height
  };

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:self.children.count];
  for (id<ASLayoutable> child in self.children) {
    CGSize autoMaxSize = {
      constrainedSize.max.width - child.layoutPosition.x,
      constrainedSize.max.height - child.layoutPosition.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, child.sizeRange)
      ? ASSizeRangeMake({0, 0}, autoMaxSize)
      : ASRelativeSizeRangeResolve(child.sizeRange, size);
    ASLayout *sublayout = [child measureWithSizeRange:childConstraint];
    sublayout.position = child.layoutPosition;
    [sublayouts addObject:sublayout];
  }
  
  size.width = constrainedSize.min.width;
  for (ASLayout *sublayout in sublayouts) {
    size.width = MAX(size.width, sublayout.position.x + sublayout.size.width);
  }

  size.height = constrainedSize.min.height;
  for (ASLayout *sublayout in sublayouts) {
    size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
  }

  return [ASLayout layoutWithLayoutableObject:self
                                         size:ASSizeRangeClamp(constrainedSize, size)
                                   sublayouts:sublayouts];
}

- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(NO, @"ASStackLayoutSpec only supports setChildren");
}

- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier
{
  ASDisplayNodeAssert(NO, @"ASStackLayoutSpec only supports children");
  return nil;
}

@end

@implementation ASStaticLayoutSpec (Debugging)

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)debugBoxString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName]];
}

@end

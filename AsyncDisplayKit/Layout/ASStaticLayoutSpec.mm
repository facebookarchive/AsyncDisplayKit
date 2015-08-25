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

- (void)setChildren:(NSArray *)children
{
  [super setChildren:children];
  
#if DEBUG
  for (id<ASStaticLayoutable> child in children) {
    ASDisplayNodeAssert(([child finalLayoutable] == child && [child conformsToProtocol:@protocol(ASStaticLayoutable)]) || ([child finalLayoutable] != child && [[child finalLayoutable] conformsToProtocol:@protocol(ASStaticLayoutable)]), @"child must conform to ASStaticLayoutable");
  }
#endif
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  CGSize size = {
    constrainedSize.max.width,
    constrainedSize.max.height
  };

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:self.children.count];
  for (id<ASStaticLayoutable> child in self.children) {
    CGSize autoMaxSize = {
      constrainedSize.max.width - child.position.x,
      constrainedSize.max.height - child.position.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, child.sizeRange)
      ? ASSizeRangeMake({0, 0}, autoMaxSize)
      : ASRelativeSizeRangeResolve(child.sizeRange, size);
    ASLayout *sublayout = [child measureWithSizeRange:childConstraint];
    sublayout.position = child.position;
    [sublayouts addObject:sublayout];
  }
  
  if (isnan(size.width) || size.width >= FLT_MAX - FLT_EPSILON) {
    size.width = constrainedSize.min.width;
    for (ASLayout *sublayout in sublayouts) {
      size.width = MAX(size.width, sublayout.position.x + sublayout.size.width);
    }
  }

  if (isnan(size.height) || size.height >= FLT_MAX - FLT_EPSILON) {
    size.height = constrainedSize.min.height;
    for (ASLayout *sublayout in sublayouts) {
      size.height = MAX(size.height, sublayout.position.y + sublayout.size.height);
    }
  }

  return [ASLayout layoutWithLayoutableObject:self
                                         size:ASSizeRangeClamp(constrainedSize, size)
                                   sublayouts:sublayouts];
}

@end

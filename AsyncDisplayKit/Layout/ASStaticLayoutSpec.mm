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
#import "ASLayoutOptionsPrivate.h"
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
    ASLayoutOptions *layoutOptions = child.layoutOptions;
    CGSize autoMaxSize = {
      constrainedSize.max.width - layoutOptions.layoutPosition.x,
      constrainedSize.max.height - layoutOptions.layoutPosition.y
    };
    ASSizeRange childConstraint = ASRelativeSizeRangeEqualToRelativeSizeRange(ASRelativeSizeRangeUnconstrained, layoutOptions.sizeRange)
      ? ASSizeRangeMake({0, 0}, autoMaxSize)
      : ASRelativeSizeRangeResolve(layoutOptions.sizeRange, size);
    ASLayout *sublayout = [child measureWithSizeRange:childConstraint];
    sublayout.position = layoutOptions.layoutPosition;
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

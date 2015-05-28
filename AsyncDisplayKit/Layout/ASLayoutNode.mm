/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutNode.h"
#import "ASLayoutNodeSubclass.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

CGFloat const kASLayoutNodeParentDimensionUndefined = NAN;
CGSize const kASLayoutNodeParentSizeUndefined = {kASLayoutNodeParentDimensionUndefined, kASLayoutNodeParentDimensionUndefined};

@implementation ASLayoutNode
{
  ASLayoutNodeSize _size;
}

#if DEBUG
+ (void)initialize
{
  ASDisplayNodeConditionalAssert(self != [ASLayoutNode class],
                      !ASSubclassOverridesSelector([ASLayoutNode class], self, @selector(layoutThatFits:parentSize:)),
                      @"%@ overrides -layoutThatFits:parentSize: which is not allowed. Override -computeLayoutThatFits: "
                      "or -computeLayoutThatFits:restrictedToSize:relativeToParentSize: instead.",
                      NSStringFromClass(self));
}
#endif

+ (instancetype)newWithSize:(ASLayoutNodeSize)size
{
  return [[self alloc] initWithLayoutNodeSize:size];
}

+ (instancetype)new
{
  return [self newWithSize:{}];
}

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (instancetype)initWithLayoutNodeSize:(ASLayoutNodeSize)size
{
  if (self = [super init]) {
    _size = size;
  }
  return self;
}

#pragma mark - Layout

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  ASLayout *layout = [self computeLayoutThatFits:constrainedSize
                                        restrictedToSize:_size
                                    relativeToParentSize:parentSize];
  ASDisplayNodeAssert(layout.node == self, @"Layout computed by %@ should return self as node, but returned %@",
           [self class], [layout.node class]);
  ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutNodeSizeResolve(_size, parentSize));
  ASDisplayNodeAssert(layout.size.width <= resolvedRange.max.width
           && layout.size.width >= resolvedRange.min.width
           && layout.size.height <= resolvedRange.max.height
           && layout.size.height >= resolvedRange.min.height,
           @"Computed size %@ for %@ does not fall within constrained size %@",
           NSStringFromCGSize(layout.size), [self class], NSStringFromASSizeRange(resolvedRange));
  return layout;
}

- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
                          restrictedToSize:(ASLayoutNodeSize)size
                      relativeToParentSize:(CGSize)parentSize
{
  ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutNodeSizeResolve(_size, parentSize));
  return [self computeLayoutThatFits:resolvedRange];
}

- (ASLayout *)computeLayoutThatFits:(ASSizeRange)constrainedSize
{
  return [ASLayout newWithNode:self size:constrainedSize.min];
}

@end

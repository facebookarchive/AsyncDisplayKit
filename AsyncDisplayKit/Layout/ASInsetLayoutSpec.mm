//
//  ASInsetLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASInsetLayoutSpec.h"

#import "ASAssert.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASThread.h"

#pragma mark - Helper

/* Returns f if f is finite, substitute otherwise */
ASDISPLAYNODE_INLINE CGFloat finite(CGFloat f, CGFloat substitute)
{
  return isinf(f) ? substitute : f;
}

/* Returns f if f is finite, 0 otherwise */
ASDISPLAYNODE_INLINE CGFloat finiteOrZero(CGFloat f)
{
  return finite(f, 0);
}

/* Returns the inset required to center 'inner' in 'outer' */
ASDISPLAYNODE_INLINE CGFloat centerInset(CGFloat outer, CGFloat inner)
{
  return ASRoundPixelValue((outer - inner) / 2);
}


#pragma mark - ASInsetLayoutSpecStyleDescription

@implementation ASInsetLayoutSpecStyleDescription

@end


#pragma mark - ASInsetLayoutSpec

@implementation ASInsetLayoutSpec {
  ASDN::RecursiveMutex __instanceLock__;
  ASInsetLayoutSpecStyleDescription *_style;
}

#pragma mark - Class

+ (instancetype)insetLayoutSpecWithInsets:(UIEdgeInsets)insets child:(id<ASLayoutable>)child
{
  return [[self alloc] initWithInsets:insets child:child];
}

#pragma mark - Lifecycle

- (instancetype)initWithInsets:(UIEdgeInsets)insets child:(id<ASLayoutable>)child;
{
  ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");

  if (!(self = [super init])) {
    return nil;
  }
  
  _style.insets = insets;
  self.child = child;
  
  return self;
}

#pragma mark - Style

- (void)loadStyle
{
  _style = [[ASInsetLayoutSpecStyleDescription alloc] init];
}

- (ASInsetLayoutSpecStyleDescription *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  return _style;
}

#pragma mark - ASLayoutSpec

/**
 Inset will compute a new constrained size for it's child after applying insets and re-positioning
 the child to respect the inset.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutableSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  if (self.child == nil) {
    ASDisplayNodeAssert(NO, @"Inset spec measured without a child. The spec will do nothing.");
    return [ASLayout layoutWithLayoutable:self size:CGSizeZero];
  }
  
  UIEdgeInsets insets = _style.insets;
  
  const CGFloat insetsX = (finiteOrZero(insets.left) + finiteOrZero(insets.right));
  const CGFloat insetsY = (finiteOrZero(insets.top) + finiteOrZero(insets.bottom));

  // if either x-axis inset is infinite, let child be intrinsic width
  const CGFloat minWidth = (isinf(insets.left) || isinf(insets.right)) ? 0 : constrainedSize.min.width;
  // if either y-axis inset is infinite, let child be intrinsic height
  const CGFloat minHeight = (isinf(insets.top) || isinf(insets.bottom)) ? 0 : constrainedSize.min.height;

  const ASSizeRange insetConstrainedSize = {
    {
      MAX(0, minWidth - insetsX),
      MAX(0, minHeight - insetsY),
    },
    {
      MAX(0, constrainedSize.max.width - insetsX),
      MAX(0, constrainedSize.max.height - insetsY),
    }
  };
  
  const CGSize insetParentSize = {
    MAX(0, parentSize.width - insetsX),
    MAX(0, parentSize.height - insetsY)
  };
  
  ASLayout *sublayout = [self.child layoutThatFits:insetConstrainedSize parentSize:insetParentSize];

  const CGSize computedSize = ASSizeRangeClamp(constrainedSize, {
    finite(sublayout.size.width + insets.left + insets.right, constrainedSize.max.width),
    finite(sublayout.size.height + insets.top + insets.bottom, constrainedSize.max.height),
  });

  const CGFloat x = finite(insets.left, constrainedSize.max.width -
                           (finite(insets.right,
                                   centerInset(constrainedSize.max.width, sublayout.size.width)) + sublayout.size.width));

  const CGFloat y = finite(insets.top,
                           constrainedSize.max.height -
                           (finite(insets.bottom,
                                   centerInset(constrainedSize.max.height, sublayout.size.height)) + sublayout.size.height));
  
  sublayout.position = CGPointMake(x, y);
  
  return [ASLayout layoutWithLayoutable:self size:computedSize sublayouts:@[sublayout]];
}

@end

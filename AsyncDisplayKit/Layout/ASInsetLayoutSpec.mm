/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASInsetLayoutSpec.h"

#import "ASAssert.h"
#import "ASBaseDefines.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@interface ASInsetLayoutSpec ()
{
  UIEdgeInsets _insets;
  id<ASLayoutable> _child;
}
@end

/* Returns f if f is finite, substitute otherwise */
static CGFloat finite(CGFloat f, CGFloat substitute)
{
  return isinf(f) ? substitute : f;
}

/* Returns f if f is finite, 0 otherwise */
static CGFloat finiteOrZero(CGFloat f)
{
  return finite(f, 0);
}

/* Returns the inset required to center 'inner' in 'outer' */
static CGFloat centerInset(CGFloat outer, CGFloat inner)
{
  return ASRoundPixelValue((outer - inner) / 2);
}

@implementation ASInsetLayoutSpec

+ (instancetype)newWithInsets:(UIEdgeInsets)insets child:(id<ASLayoutable>)child
{
  if (child == nil) {
    return nil;
  }
  ASInsetLayoutSpec *spec = [super new];
  if (spec) {
    spec->_insets = insets;
    spec->_child = child;
  }
  return spec;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

/**
 Inset will compute a new constrained size for it's child after applying insets and re-positioning
 the child to respect the inset.
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  const CGFloat insetsX = (finiteOrZero(_insets.left) + finiteOrZero(_insets.right));
  const CGFloat insetsY = (finiteOrZero(_insets.top) + finiteOrZero(_insets.bottom));

  // if either x-axis inset is infinite, let child be intrinsic width
  const CGFloat minWidth = (isinf(_insets.left) || isinf(_insets.right)) ? 0 : constrainedSize.min.width;
  // if either y-axis inset is infinite, let child be intrinsic height
  const CGFloat minHeight = (isinf(_insets.top) || isinf(_insets.bottom)) ? 0 : constrainedSize.min.height;

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
  ASLayout *sublayout = [_child measureWithSizeRange:insetConstrainedSize];

  const CGSize computedSize = ASSizeRangeClamp(constrainedSize, {
    finite(sublayout.size.width + _insets.left + _insets.right, constrainedSize.max.width),
    finite(sublayout.size.height + _insets.top + _insets.bottom, constrainedSize.max.height),
  });

  const CGFloat x = finite(_insets.left, constrainedSize.max.width -
                           (finite(_insets.right,
                                   centerInset(constrainedSize.max.width, sublayout.size.width)) + sublayout.size.width));

  const CGFloat y = finite(_insets.top,
                           constrainedSize.max.height -
                           (finite(_insets.bottom,
                                   centerInset(constrainedSize.max.height, sublayout.size.height)) + sublayout.size.height));
  
  sublayout.position = CGPointMake(x, y);
  
  return [ASLayout newWithLayoutableObject:self size:computedSize sublayouts:@[sublayout]];
}

@end

/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackPositionedLayout.h"

#import "ASInternalHelpers.h"
#import "ASLayoutSpecUtilities.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASLayoutable.h"

static CGFloat crossOffset(const ASStackLayoutSpecStyle &style,
                           const ASStackUnpositionedItem &l,
                           const CGFloat crossSize)
{
  switch (alignment(l.child.alignSelf, style.alignItems)) {
    case ASStackLayoutAlignItemsEnd:
      return crossSize - crossDimension(style.direction, l.layout.size);
    case ASStackLayoutAlignItemsCenter:
      return ASFloorPixelValue((crossSize - crossDimension(style.direction, l.layout.size)) / 2);
    case ASStackLayoutAlignItemsStart:
    case ASStackLayoutAlignItemsStretch:
      return 0;
  }
}

static ASStackPositionedLayout stackedLayout(const ASStackLayoutSpecStyle &style,
                                             const CGFloat offset,
                                             const ASStackUnpositionedLayout &unpositionedLayout,
                                             const ASSizeRange &constrainedSize)
{
  // The cross dimension is the max of the childrens' cross dimensions (clamped to our constraint below).
  const auto it = std::max_element(unpositionedLayout.items.begin(), unpositionedLayout.items.end(),
                                   [&](const ASStackUnpositionedItem &a, const ASStackUnpositionedItem &b){
                                     return compareCrossDimension(style.direction, a.layout.size, b.layout.size);
                                   });
  const auto largestChildCrossSize = it == unpositionedLayout.items.end() ? 0 : crossDimension(style.direction, it->layout.size);
  const auto minCrossSize = crossDimension(style.direction, constrainedSize.min);
  const auto maxCrossSize = crossDimension(style.direction, constrainedSize.max);
  const CGFloat crossSize = MIN(MAX(minCrossSize, largestChildCrossSize), maxCrossSize);

  CGPoint p = directionPoint(style.direction, offset, 0);
  BOOL first = YES;
  auto stackedChildren = AS::map(unpositionedLayout.items, [&](const ASStackUnpositionedItem &l) -> ASLayout *{
    p = p + directionPoint(style.direction, l.child.spacingBefore, 0);
    if (!first) {
      p = p + directionPoint(style.direction, style.spacing, 0);
    }
    first = NO;
    l.layout.position = p + directionPoint(style.direction, 0, crossOffset(style, l, crossSize));
    p = p + directionPoint(style.direction, stackDimension(style.direction, l.layout.size) + l.child.spacingAfter, 0);
    return l.layout;
  });
  return {stackedChildren, crossSize};
}

ASStackPositionedLayout ASStackPositionedLayout::compute(const ASStackUnpositionedLayout &unpositionedLayout,
                                                         const ASStackLayoutSpecStyle &style,
                                                         const ASSizeRange &constrainedSize)
{
  switch (style.justifyContent) {
    case ASStackLayoutJustifyContentStart:
      return stackedLayout(style, 0, unpositionedLayout, constrainedSize);
    case ASStackLayoutJustifyContentCenter:
      return stackedLayout(style, floorf(unpositionedLayout.violation / 2), unpositionedLayout, constrainedSize);
    case ASStackLayoutJustifyContentEnd:
      return stackedLayout(style, unpositionedLayout.violation, unpositionedLayout, constrainedSize);
  }
}

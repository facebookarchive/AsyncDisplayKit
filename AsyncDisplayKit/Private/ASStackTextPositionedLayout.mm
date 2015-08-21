/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackTextPositionedLayout.h"

#import "ASLayoutSpecUtilities.h"
#import "ASStackLayoutSpecUtilities.h"

static CGFloat baselineForItem(const ASStackTextLayoutSpecStyle &style,
                               const ASLayout *layout) {
  
  __weak id<ASStackTextLayoutable> textChild = (id<ASStackTextLayoutable>) layout.layoutableObject;
  switch (style.baselineAlignment) {
    case ASStackTextLayoutBaselineAlignmentNone:
      return 0;
    case ASStackTextLayoutBaselineAlignmentFirst:
      return textChild.ascender;
    case ASStackTextLayoutBaselineAlignmentLast:
      return layout.size.height + textChild.descender;
  }
  
}

static CGFloat baselineOffset(const ASStackTextLayoutSpecStyle &style,
                              const ASLayout *l,
                              const CGFloat maxAscender,
                              const CGFloat maxBaseline)
{
  if (style.stackLayoutStyle.direction == ASStackLayoutDirectionHorizontal) {
    __weak id<ASStackTextLayoutable> textChild = (id<ASStackTextLayoutable>)l.layoutableObject;
    switch (style.baselineAlignment) {
      case ASStackTextLayoutBaselineAlignmentFirst:
        return maxAscender - textChild.ascender;
      case ASStackTextLayoutBaselineAlignmentLast:
        return maxBaseline - baselineForItem(style, l);
      case ASStackTextLayoutBaselineAlignmentNone:
        return 0;
    }
  }
  return 0;
}

static CGFloat maxDimensionForLayout(const ASLayout *l,
                                     const ASStackLayoutSpecStyle &style)
{
  CGFloat maxDimension = crossDimension(style.direction, l.size);
  style.direction == ASStackLayoutDirectionVertical ? maxDimension += l.position.x : maxDimension += l.position.y;
  return maxDimension;
}

ASStackTextPositionedLayout ASStackTextPositionedLayout::compute(const ASStackPositionedLayout &positionedLayout,
                                                                 const ASStackTextLayoutSpecStyle &textStyle,
                                                                 const ASSizeRange &constrainedSize)
{
  ASStackLayoutSpecStyle stackStyle = textStyle.stackLayoutStyle;
  
  
  // Get the largest distance from the top of the stack to a baseline. This is the baseline we will align to.
  const auto baselineIt = std::max_element(positionedLayout.sublayouts.begin(), positionedLayout.sublayouts.end(), [&](const ASLayout *a, const ASLayout *b){
    return baselineForItem(textStyle, a) < baselineForItem(textStyle, b);
  });
  const CGFloat maxBaseline = baselineIt == positionedLayout.sublayouts.end() ? 0 : baselineForItem(textStyle, *baselineIt);
  
  // find the largest ascender for all children. This value will be used in offset computation as well as sent back to the ASStackTextLayoutSpec as its ascender.
  const auto ascenderIt = std::max_element(positionedLayout.sublayouts.begin(), positionedLayout.sublayouts.end(), [&](const ASLayout *a, const ASLayout *b){
    return ((id<ASStackTextLayoutable>)a.layoutableObject).ascender < ((id<ASStackTextLayoutable>)b.layoutableObject).ascender;
  });
  const CGFloat maxAscender = baselineIt == positionedLayout.sublayouts.end() ? 0 : ((id<ASStackTextLayoutable>)(*ascenderIt).layoutableObject).ascender;
  
  CGPoint p = CGPointZero;
  BOOL first = YES;
  auto stackedChildren = AS::map(positionedLayout.sublayouts, [&](ASLayout *l) -> ASLayout *{
    __weak id<ASStackTextLayoutable> textChild = (id<ASStackTextLayoutable>) l.layoutableObject;
    p = p + directionPoint(stackStyle.direction, textChild.spacingBefore, 0);
    if (first) {
      // if this is the first item use the previously computed start point
      p = l.position;
    } else {
      // otherwise add the stack spacing
      p = p + directionPoint(stackStyle.direction, stackStyle.spacing, 0);
    }
    first = NO;
    
    // add the baseline offset. baselineOffset is only valid in the horizontal direction, so we always add to y
    l.position = p + CGPointMake(0, baselineOffset(textStyle, l, maxAscender, maxBaseline));
    
    // If we are a vertical stack, add the item's descender (it is negative) to the spacing after. This will alter the stack spacing to be on baselines instead of bounding boxes
    CGFloat spacingAfterBaseline = (stackStyle.direction == ASStackLayoutDirectionVertical) ? textChild.descender : 0;
    p = p + directionPoint(stackStyle.direction, stackDimension(stackStyle.direction, l.size) + textChild.spacingAfter + spacingAfterBaseline, 0);
    
    return l;
  });
  
  // The cross dimension is the max of the childrens' cross dimensions (clamped to our constraint below).
  const auto it = std::max_element(stackedChildren.begin(), stackedChildren.end(),
                                   [&](ASLayout *a, ASLayout *b) {
                                     return maxDimensionForLayout(a, stackStyle) < maxDimensionForLayout(b, stackStyle);
                                   });
  const auto largestChildCrossSize = it == stackedChildren.end() ? 0 : maxDimensionForLayout(*it, stackStyle);
  const auto minCrossSize = crossDimension(stackStyle.direction, constrainedSize.min);
  const auto maxCrossSize = crossDimension(stackStyle.direction, constrainedSize.max);
  const CGFloat crossSize = MIN(MAX(minCrossSize, largestChildCrossSize), maxCrossSize);
  
  // find the child with the largest height. Use that child's descender as the descender to pass back to the ASStackTextLayoutSpec.
  const auto descenderIt = std::max_element(stackedChildren.begin(), stackedChildren.end(), [&](const ASLayout *a, const ASLayout *b){
    return  a.position.y + a.size.height <  b.position.y + b.size.height;
  });
  const CGFloat minDescender = descenderIt == stackedChildren.end() ? 0 : ((id<ASStackTextLayoutable>)(*descenderIt).layoutableObject).descender;

  return {stackedChildren, crossSize, maxAscender, minDescender};
}

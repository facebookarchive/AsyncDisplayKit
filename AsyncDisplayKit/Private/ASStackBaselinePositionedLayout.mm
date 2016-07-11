//
//  ASStackBaselinePositionedLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASStackBaselinePositionedLayout.h"

#import "ASLayoutSpecUtilities.h"

static CGFloat baselineForItem(const ASStackLayoutSpecStyle &style,
                               const ASLayout *layout) {
  
  __weak id<ASLayoutable> child = layout.layoutableObject;
  switch (style.alignItems) {
    case ASStackLayoutAlignItemsBaselineFirst:
      return child.ascender;
    case ASStackLayoutAlignItemsBaselineLast:
      return layout.size.height + child.descender;
    default:
      return 0;
  }
  
}

static CGFloat baselineOffset(const ASStackLayoutSpecStyle &style,
                              const ASLayout *l,
                              const CGFloat maxAscender,
                              const CGFloat maxBaseline)
{
  if (style.direction == ASStackLayoutDirectionHorizontal) {
    __weak id<ASLayoutable> child = l.layoutableObject;
    switch (style.alignItems) {
      case ASStackLayoutAlignItemsBaselineFirst:
        return maxAscender - child.ascender;
      case ASStackLayoutAlignItemsBaselineLast:
        return maxBaseline - baselineForItem(style, l);
        
      default:
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

ASStackBaselinePositionedLayout ASStackBaselinePositionedLayout::compute(const ASStackPositionedLayout &positionedLayout,
                                                                         const ASStackLayoutSpecStyle &style,
                                                                         const ASSizeRange &constrainedSize)
{
  /* Step 1: Look at each child and determine the distance from the top of the child node it's baseline.
     For  example, let's say we have the following two text nodes and want to align them to the first baseline:
   
     Hello!    Why, hello there! How
               are you today?
   
     The first node has a font of size 14, the second a font of size 12. The first node will have a baseline offset of 
     the ascender of a font of size 14, the second will have a baseline of the ascender of a font of size 12. The first 
     baseline will be larger so we will keep that as the max baseline.
   
     However, if were to align from the last baseline we'd find the max baseline by taking the height of node and adding
     the font's descender (it's negative). In the case of the first node, which is only 1 line, this should be the same value as the ascender.
     The second node, however, has a larger height and there will have a larger baseline offset.
   */
  const auto baselineIt = std::max_element(positionedLayout.sublayouts.begin(), positionedLayout.sublayouts.end(), [&](const ASLayout *a, const ASLayout *b){
    return baselineForItem(style, a) < baselineForItem(style, b);
  });
  const CGFloat maxBaseline = baselineIt == positionedLayout.sublayouts.end() ? 0 : baselineForItem(style, *baselineIt);
  
  /*
    Step 2: Find the max ascender for all of the children.
    Imagine 3 nodes aligned horizontally, all with the same text but with font sizes of 12, 14, 16. Because it is has the largest
    ascender node with font size of 16 will not need to move, the other two nodes will align to this node's baseline. The offset we will use
    for each node is our computed maxAscender - node.ascender. If the 16pt node had an ascender of 10 and the 14pt node
    had an ascender of 8, that means we will offset the 14pt node by 2 pts.
   
    Note: if we are aligning to the last baseline, then we don't need this value in our computation. However, we do want
    our layoutSpec to have it so that it can be baseline aligned with another text node or baseline layout spec.
   */
  const auto ascenderIt = std::max_element(positionedLayout.sublayouts.begin(), positionedLayout.sublayouts.end(), [&](const ASLayout *a, const ASLayout *b){
    return a.layoutableObject.ascender < b.layoutableObject.ascender;
  });
  const CGFloat maxAscender = ascenderIt == positionedLayout.sublayouts.end() ? 0 : (*ascenderIt).layoutableObject.ascender;
  
  /*
    Step 3: Take each child and update its layout position based on the baseline offset.
   
    If this is a horizontal stack, we take a positioned child and add to its y offset to align it to the maxBaseline of the children.
    If this is a vertical stack, we add the child's descender to the location of the next child to position. This will ensure the
    spacing between the two nodes is from the baseline, not the bounding box.
   
  */
  std::vector<ASLayout *> stackedChildren;
  // Only change positions of layouts this stackSpec is aligning to a baseline. Otherwise we are only here to
  // compute the min/max descender/ascender for this stack spec.
  if (style.baselineRelativeArrangement || style.alignItems == ASStackLayoutAlignItemsBaselineFirst || style.alignItems == ASStackLayoutAlignItemsBaselineLast) {
    CGPoint p = CGPointZero;
    BOOL first = YES;
    stackedChildren = AS::map(positionedLayout.sublayouts, [&](ASLayout *l) -> ASLayout *{
      __weak id<ASLayoutable> child = l.layoutableObject;
      p = p + directionPoint(style.direction, child.spacingBefore, 0);
      if (first) {
        // if this is the first item use the previously computed start point
        p = l.position;
      } else {
        // otherwise add the stack spacing
        p = p + directionPoint(style.direction, style.spacing, 0);
      }
      first = NO;
      
      // Find the difference between this node's baseline and the max baseline of all the children. Add this difference to the child's y position.
      l.position = p + CGPointMake(0, baselineOffset(style, l, maxAscender, maxBaseline));
      
      // If we are a vertical stack, add the item's descender (it is negative) to the offset for the next node. This will ensure we are spacing
      // node from baselines and not bounding boxes.
      CGFloat spacingAfterBaseline = 0;
      if (style.direction == ASStackLayoutDirectionVertical) {
        spacingAfterBaseline = child.descender;
      }
      p = p + directionPoint(style.direction, stackDimension(style.direction, l.size) + child.spacingAfter + spacingAfterBaseline, 0);
      
      return l;
    });
  } else {
    stackedChildren = positionedLayout.sublayouts;
  }
  
  /*
    Step 4: Since we have been mucking with positions, there is a chance that our cross size has changed. Imagine a node with a font size of 40
    and another node with a font size of 12 but with multiple lines. We align these nodes to the first baseline, which will be the baseline of the node with
    font size of 40 (max ascender). Now, we have to move the node with multiple lines down to the other node's baseline. This node with multiple lines will
    extend below the first node farther than it did before aligning the baselines thus increasing the cross size.
   
    After finding the new cross size, we need to clamp it so that it fits within the constrained size.
   
   */
  const auto it = std::max_element(stackedChildren.begin(), stackedChildren.end(),
                                   [&](ASLayout *a, ASLayout *b) {
                                     return maxDimensionForLayout(a, style) < maxDimensionForLayout(b, style);
                                   });
  const auto largestChildCrossSize = it == stackedChildren.end() ? 0 : maxDimensionForLayout(*it, style);
  const auto minCrossSize = crossDimension(style.direction, constrainedSize.min);
  const auto maxCrossSize = crossDimension(style.direction, constrainedSize.max);
  const CGFloat crossSize = MIN(MAX(minCrossSize, largestChildCrossSize), maxCrossSize);
  
  /*
     Step 5: finally, we must find the smallest descender (descender is negative). This is since ASBaselineLayoutSpec implements
     ASLayoutable and needs an ascender and descender to lay itself out properly.
   */
  const auto descenderIt = std::max_element(stackedChildren.begin(), stackedChildren.end(), [&](const ASLayout *a, const ASLayout *b){
    return  a.position.y + a.size.height <  b.position.y + b.size.height;
  });
  const CGFloat minDescender = descenderIt == stackedChildren.end() ? 0 : (*descenderIt).layoutableObject.descender;

  return {stackedChildren, crossSize, maxAscender, minDescender};
}

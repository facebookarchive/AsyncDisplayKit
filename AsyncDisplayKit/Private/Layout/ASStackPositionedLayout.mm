//
//  ASStackPositionedLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASStackPositionedLayout.h>

#import <tgmath.h>
#import <numeric>

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>

static CGFloat crossOffsetForItem(const ASStackLayoutSpecItem &item,
                                  const ASStackLayoutSpecStyle &style,
                                  const CGFloat crossSize,
                                  const CGFloat baseline)
{
  switch (alignment(item.child.style.alignSelf, style.alignItems)) {
    case ASStackLayoutAlignItemsEnd:
      return crossSize - crossDimension(style.direction, item.layout.size);
    case ASStackLayoutAlignItemsCenter:
      return ASFloorPixelValue((crossSize - crossDimension(style.direction, item.layout.size)) / 2);
    case ASStackLayoutAlignItemsBaselineFirst:
    case ASStackLayoutAlignItemsBaselineLast:
      return baseline - ASStackUnpositionedLayout::baselineForItem(style, item);
    case ASStackLayoutAlignItemsStart:
    case ASStackLayoutAlignItemsStretch:
    case ASStackLayoutAlignItemsNotSet:
      return 0;
  }
}

static void crossOffsetAndSpacingForEachLine(const std::size_t numOfLines,
                                             const CGFloat crossViolation,
                                             ASStackLayoutAlignContent alignContent,
                                             CGFloat &offset,
                                             CGFloat &spacing)
{
  ASDisplayNodeCAssertTrue(numOfLines > 0);
  
  // Handle edge cases
  if (alignContent == ASStackLayoutAlignContentSpaceBetween && (crossViolation < kViolationEpsilon || numOfLines == 1)) {
    alignContent = ASStackLayoutAlignContentStart;
  } else if (alignContent == ASStackLayoutAlignContentSpaceAround && (crossViolation < kViolationEpsilon || numOfLines == 1)) {
    alignContent = ASStackLayoutAlignContentCenter;
  }
  
  offset = 0;
  spacing = 0;
  
  switch (alignContent) {
    case ASStackLayoutAlignContentCenter:
      offset = crossViolation / 2;
      break;
    case ASStackLayoutAlignContentEnd:
      offset = crossViolation;
      break;
    case ASStackLayoutAlignContentSpaceBetween:
      // Spacing between the items, no spaces at the edges, evenly distributed
      spacing = crossViolation / (numOfLines - 1);
      break;
    case ASStackLayoutAlignContentSpaceAround: {
      // Spacing between items are twice the spacing on the edges
      CGFloat spacingUnit = crossViolation / (numOfLines * 2);
      offset = spacingUnit;
      spacing = spacingUnit * 2;
      break;
    }
    case ASStackLayoutAlignContentStart:
    case ASStackLayoutAlignContentStretch:
      break;
  }
}

static void stackOffsetAndSpacingForEachItem(const std::size_t numOfItems,
                                             const CGFloat stackViolation,
                                             ASStackLayoutJustifyContent justifyContent,
                                             CGFloat &offset,
                                             CGFloat &spacing)
{
  ASDisplayNodeCAssertTrue(numOfItems > 0);
  
  // Handle edge cases
  if (justifyContent == ASStackLayoutJustifyContentSpaceBetween && (stackViolation < kViolationEpsilon || numOfItems == 1)) {
    justifyContent = ASStackLayoutJustifyContentStart;
  } else if (justifyContent == ASStackLayoutJustifyContentSpaceAround && (stackViolation < kViolationEpsilon || numOfItems == 1)) {
    justifyContent = ASStackLayoutJustifyContentCenter;
  }
  
  offset = 0;
  spacing = 0;
  
  switch (justifyContent) {
    case ASStackLayoutJustifyContentCenter:
      offset = stackViolation / 2;
      break;
    case ASStackLayoutJustifyContentEnd:
      offset = stackViolation;
      break;
    case ASStackLayoutJustifyContentSpaceBetween:
      // Spacing between the items, no spaces at the edges, evenly distributed
      spacing = stackViolation / (numOfItems - 1);
      break;
    case ASStackLayoutJustifyContentSpaceAround: {
      // Spacing between items are twice the spacing on the edges
      CGFloat spacingUnit = stackViolation / (numOfItems * 2);
      offset = spacingUnit;
      spacing = spacingUnit * 2;
      break;
    }
    case ASStackLayoutJustifyContentStart:
      break;
  }
}

static void positionItemsInLine(const ASStackUnpositionedLine &line,
                                const ASStackLayoutSpecStyle &style,
                                const CGPoint &startingPoint,
                                const CGFloat stackSpacing)
{
  CGPoint p = startingPoint;
  BOOL first = YES;
  
  for (const auto &item : line.items) {
    p = p + directionPoint(style.direction, item.child.style.spacingBefore, 0);
    if (!first) {
      p = p + directionPoint(style.direction, style.spacing + stackSpacing, 0);
    }
    first = NO;
    item.layout.position = p + directionPoint(style.direction, 0, crossOffsetForItem(item, style, line.crossSize, line.baseline));
    
    p = p + directionPoint(style.direction, stackDimension(style.direction, item.layout.size) + item.child.style.spacingAfter, 0);
  }
}

ASStackPositionedLayout ASStackPositionedLayout::compute(const ASStackUnpositionedLayout &layout,
                                                         const ASStackLayoutSpecStyle &style,
                                                         const ASSizeRange &sizeRange)
{
  const auto &lines = layout.lines;
  if (lines.empty()) {
    return {};
  }
  
  const auto numOfLines = lines.size();
  const auto direction = style.direction;
  const auto alignContent = style.alignContent;
  const auto justifyContent = style.justifyContent;
  const auto crossViolation = ASStackUnpositionedLayout::computeCrossViolation(layout.crossDimensionSum, style, sizeRange);
  CGFloat crossOffset;
  CGFloat crossSpacing;
  crossOffsetAndSpacingForEachLine(numOfLines, crossViolation, alignContent, crossOffset, crossSpacing);
  
  std::vector<ASStackLayoutSpecItem> positionedItems;
  CGPoint p = directionPoint(direction, 0, crossOffset);
  BOOL first = YES;
  for (const auto &line : lines) {
    if (!first) {
      p = p + directionPoint(direction, 0, crossSpacing);
    }
    first = NO;
    
    const auto &items = line.items;
    const auto stackViolation = ASStackUnpositionedLayout::computeStackViolation(line.stackDimensionSum, style, sizeRange);
    CGFloat stackOffset;
    CGFloat stackSpacing;
    stackOffsetAndSpacingForEachItem(items.size(), stackViolation, justifyContent, stackOffset, stackSpacing);
    
    setStackValueToPoint(direction, stackOffset, p);
    positionItemsInLine(line, style, p, stackSpacing);
    std::move(items.begin(), items.end(), std::back_inserter(positionedItems));
    
    p = p + directionPoint(direction, -stackOffset, line.crossSize);
  }

  const CGSize finalSize = directionSize(direction, layout.stackDimensionSum, layout.crossDimensionSum);
  return {std::move(positionedItems), ASSizeRangeClamp(sizeRange, finalSize)};
}

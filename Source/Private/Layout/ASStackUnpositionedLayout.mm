//
//  ASStackUnpositionedLayout.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASStackUnpositionedLayout.h>

#import <tgmath.h>
#import <numeric>

#import <AsyncDisplayKit/ASDispatch.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>

CGFloat const kViolationEpsilon = 0.01;

static CGFloat resolveCrossDimensionMaxForStretchChild(const ASStackLayoutSpecStyle &style,
                                                       const ASStackLayoutSpecChild &child,
                                                       const CGFloat stackMax,
                                                       const CGFloat crossMax)
{
  // stretched children may have a cross direction max that is smaller than the minimum size constraint of the parent.
  const CGFloat computedMax = (style.direction == ASStackLayoutDirectionVertical ?
                               ASLayoutElementSizeResolve(child.style.size, ASLayoutElementParentSizeUndefined).max.width :
                               ASLayoutElementSizeResolve(child.style.size, ASLayoutElementParentSizeUndefined).max.height);
  return computedMax == INFINITY ? crossMax : computedMax;
}

static CGFloat resolveCrossDimensionMinForStretchChild(const ASStackLayoutSpecStyle &style,
                                                       const ASStackLayoutSpecChild &child,
                                                       const CGFloat stackMax,
                                                       const CGFloat crossMin)
{
  // stretched children will have a cross dimension of at least crossMin, unless they explicitly define a child size
  // that is smaller than the constraint of the parent.
  return (style.direction == ASStackLayoutDirectionVertical ?
          ASLayoutElementSizeResolve(child.style.size, ASLayoutElementParentSizeUndefined).min.width :
          ASLayoutElementSizeResolve(child.style.size, ASLayoutElementParentSizeUndefined).min.height) ?: crossMin;
}

/**
 Sizes the child given the parameters specified, and returns the computed layout.
 */
static ASLayout *crossChildLayout(const ASStackLayoutSpecChild &child,
                                  const ASStackLayoutSpecStyle &style,
                                  const CGFloat stackMin,
                                  const CGFloat stackMax,
                                  const CGFloat crossMin,
                                  const CGFloat crossMax,
                                  const CGSize parentSize)
{
  const ASStackLayoutAlignItems alignItems = alignment(child.style.alignSelf, style.alignItems);
  // stretched children will have a cross dimension of at least crossMin
  const CGFloat childCrossMin = (alignItems == ASStackLayoutAlignItemsStretch ?
                                 resolveCrossDimensionMinForStretchChild(style, child, stackMax, crossMin) :
                                 0);
  const CGFloat childCrossMax = (alignItems == ASStackLayoutAlignItemsStretch ?
                                 resolveCrossDimensionMaxForStretchChild(style, child, stackMax, crossMax) :
                                 crossMax);
  const ASSizeRange childSizeRange = directionSizeRange(style.direction, stackMin, stackMax, childCrossMin, childCrossMax);
  ASLayout *layout = [child.element layoutThatFits:childSizeRange parentSize:parentSize];
  ASDisplayNodeCAssertNotNil(layout, @"ASLayout returned from measureWithSizeRange: must not be nil: %@", child.element);
  return layout ? : [ASLayout layoutWithLayoutElement:child.element size:{0, 0}];
}

static void dispatchApplyIfNeeded(size_t iterationCount, BOOL forced, void(^work)(size_t i))
{
  if (iterationCount == 0) {
    return;
  }
  
  if (iterationCount == 1) {
    work(0);
    return;
  }
  
  // TODO Once the locking situation in ASDisplayNode has improved, always dispatch if on main
  if (forced == NO) {
    for (size_t i = 0; i < iterationCount; i++) {
      work(i);
    }
    return;
  }
  
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  ASDispatchApply(iterationCount, queue, 0, work);
}

/**
 Computes the consumed cross dimension length for the given vector of lines and stacking style.
 
          Cross Dimension
          +--------------------->
          +--------+ +--------+ +--------+ +---------+
 Vertical |Vertical| |Vertical| |Vertical| |Vertical |
 Stack    | Line 1 | | Line 2 | | Line 3 | | Line 4  |
          |        | |        | |        | |         |
          +--------+ +--------+ +--------+ +---------+
                      crossDimensionSum
          |------------------------------------------|

 @param lines unpositioned lines
 */
static CGFloat computeLinesCrossDimensionSum(const std::vector<ASStackUnpositionedLine> &lines)
{
  return std::accumulate(lines.begin(), lines.end(), 0.0,
                         [&](CGFloat x, const ASStackUnpositionedLine &l) {
                           return x + l.crossSize;
                         });
}


/**
 Computes the violation by comparing a cross dimension sum with the overall allowable size range for the stack.
 
 Violation is the distance you would have to add to the unbounded cross-direction length of the stack spec's
 lines in order to bring the stack within its allowed sizeRange.  The diagram below shows 3 vertical stacks, each contains 3-5 vertical lines,
 with the different types of violation.
 
          Cross Dimension
          +--------------------->
                                              cross size range
                                              |------------|
          +--------+ +--------+ +--------+ +---------+  -  -  -  -  -  -  -  -
 Vertical |Vertical| |Vertical| |Vertical| |Vertical |     |                 ^
 Stack 1  | Line 1 | | Line 2 | | Line 3 | | Line 4  | (zero violation)      | stack size range
          |        | |        | |        | |  |      |     |                 v
          +--------+ +--------+ +--------+ +---------+  -  -  -  -  -  -  -  -
                                              |            |
          +--------+ +--------+ +--------+  -  -  -  -  -  -  -  -  -  -  -  -
 Vertical |        | |        | |        |    |            |                 ^
 Stack 2  |        | |        | |        |<--> (positive violation)          | stack size range
          |        | |        | |        |    |            |                 v
          +--------+ +--------+ +--------+  -  -  -  -  -  -  -  -  -  -  -  -
                                              |            |<------> (negative violation)
          +--------+ +--------+ +--------+ +---------+ +-----------+  -  -   -
 Vertical |        | |        | |        | |  |      | |   |       |         ^
 Stack 3  |        | |        | |        | |         | |           |         |  stack size range
          |        | |        | |        | |  |      | |   |       |         v
          +--------+ +--------+ +--------+ +---------+ +-----------+  -  -   -
 
 @param crossDimensionSum the consumed length of the lines in the stack along the cross dimension
 @param style layout style to be applied to all children
 @param sizeRange the range of allowable sizes for the stack layout spec
 */
CGFloat ASStackUnpositionedLayout::computeCrossViolation(const CGFloat crossDimensionSum,
                                                         const ASStackLayoutSpecStyle &style,
                                                         const ASSizeRange &sizeRange)
{
  const CGFloat minCrossDimension = crossDimension(style.direction, sizeRange.min);
  const CGFloat maxCrossDimension = crossDimension(style.direction, sizeRange.max);
  if (crossDimensionSum < minCrossDimension) {
    return minCrossDimension - crossDimensionSum;
  } else if (crossDimensionSum > maxCrossDimension) {
    return maxCrossDimension - crossDimensionSum;
  }
  return 0;
}

/**
 Stretches children to lay out along the cross axis according to the alignment stretch settings of the children
 (child.alignSelf), and the stack layout's alignment settings (style.alignItems).  This does not do the actual alignment
 of the items once stretched though; ASStackPositionedLayout will do centering etc.

 Finds the maximum cross dimension among child layouts.  If that dimension exceeds the minimum cross layout size then
 we must stretch any children whose alignItems specify ASStackLayoutAlignItemsStretch.

 The diagram below shows 3 children in a horizontal stack.  The second child is larger than the minCrossDimension, so
 its height is used as the childCrossMax.  Any children that are stretchable (which may be all children if
 style.alignItems specifies stretch) like the first child must be stretched to match that maximum.  All children must be
 at least minCrossDimension in cross dimension size, which is shown by the sizing of the third child.

                 Stack Dimension
                 +--------------------->
              +  +-+-------------+-+-------------+--+---------------+  + + +
              |    | child.      | |             |  |               |  | | |
              |    | alignSelf   | |             |  |               |  | | |
 Cross        |    | = stretch   | |             |  +-------+-------+  | | |
 Dimension    |    +-----+-------+ |             |  |       |       |  | | |
              |    |     |       | |             |          |          | | |
              |          |         |             |  |       v       |  | | |
              v  +-+- - - - - - -+-+ - - - - - - +--+- - - - - - - -+  | | + minCrossDimension
                         |         |             |                     | |
                   |     v       | |             |                     | |
                   +- - - - - - -+ +-------------+                     | + childCrossMax
                                                                       |
                 +--------------------------------------------------+  + crossMax

 @param items pre-computed items; modified in-place as needed
 @param style the layout style of the overall stack layout
 */
static void stretchItemsAlongCrossDimension(std::vector<ASStackLayoutSpecItem> &items,
                                            const ASStackLayoutSpecStyle &style,
                                            const BOOL concurrent,
                                            const CGSize parentSize,
                                            const CGFloat crossSize)
{
  dispatchApplyIfNeeded(items.size(), concurrent, ^(size_t i) {
    auto &item = items[i];
    const ASStackLayoutAlignItems alignItems = alignment(item.child.style.alignSelf, style.alignItems);
    if (alignItems == ASStackLayoutAlignItemsStretch) {
      const CGFloat cross = crossDimension(style.direction, item.layout.size);
      const CGFloat stack = stackDimension(style.direction, item.layout.size);
      const CGFloat violation = crossSize - cross;
      
      // Only stretch if violation is positive. Compare against kViolationEpsilon here to avoid stretching against a tiny violation.
      if (violation > kViolationEpsilon) {
        item.layout = crossChildLayout(item.child, style, stack, stack, crossSize, crossSize, parentSize);
      }
    }
  });
}

/**
 * Stretch lines and their items according to alignContent, alignItems and alignSelf.
 * https://www.w3.org/TR/css-flexbox-1/#algo-line-stretch
 * https://www.w3.org/TR/css-flexbox-1/#algo-stretch
 */
static void stretchLinesAlongCrossDimension(std::vector<ASStackUnpositionedLine> &lines,
                                            const ASStackLayoutSpecStyle &style,
                                            const BOOL concurrent,
                                            const ASSizeRange &sizeRange,
                                            const CGSize parentSize)
{
  ASDisplayNodeCAssertFalse(lines.empty());
  const std::size_t numOfLines = lines.size();
  const CGFloat violation = ASStackUnpositionedLayout::computeCrossViolation(computeLinesCrossDimensionSum(lines), style, sizeRange);
  // Don't stretch if the stack is single line, because the line's cross size was clamped against the stack's constrained size.
  const BOOL shouldStretchLines = (numOfLines > 1
                                   && style.alignContent == ASStackLayoutAlignContentStretch
                                   && violation > kViolationEpsilon);
  
  CGFloat extraCrossSizePerLine = violation / numOfLines;
  for (auto &line : lines) {
    if (shouldStretchLines) {
      line.crossSize += extraCrossSizePerLine;
    }
    
    stretchItemsAlongCrossDimension(line.items, style, concurrent, parentSize, line.crossSize);
  }
}

static BOOL itemIsBaselineAligned(const ASStackLayoutSpecStyle &style,
                                  const ASStackLayoutSpecItem &l)
{
  ASStackLayoutAlignItems alignItems = alignment(l.child.style.alignSelf, style.alignItems);
  return alignItems == ASStackLayoutAlignItemsBaselineFirst || alignItems == ASStackLayoutAlignItemsBaselineLast;
}

CGFloat ASStackUnpositionedLayout::baselineForItem(const ASStackLayoutSpecStyle &style,
                                                   const ASStackLayoutSpecItem &item)
{
  switch (alignment(item.child.style.alignSelf, style.alignItems)) {
    case ASStackLayoutAlignItemsBaselineFirst:
      return item.child.style.ascender;
    case ASStackLayoutAlignItemsBaselineLast:
      return crossDimension(style.direction, item.layout.size) + item.child.style.descender;
    default:
      return 0;
  }
}

/**
 * Computes cross size and baseline of each line.
 * https://www.w3.org/TR/css-flexbox-1/#algo-cross-line
 *
 * @param lines All items to lay out
 * @param style the layout style of the overall stack layout
 * @param sizeRange the range of allowable sizes for the stack layout component
 */
static void computeLinesCrossSizeAndBaseline(std::vector<ASStackUnpositionedLine> &lines,
                                             const ASStackLayoutSpecStyle &style,
                                             const ASSizeRange &sizeRange)
{
  ASDisplayNodeCAssertFalse(lines.empty());
  const BOOL isSingleLine = (lines.size() == 1);
  
  const auto minCrossSize = crossDimension(style.direction, sizeRange.min);
  const auto maxCrossSize = crossDimension(style.direction, sizeRange.max);
  const BOOL definiteCrossSize = (minCrossSize == maxCrossSize);
  
  // If the stack is single-line and has a definite cross size, the cross size of the line is the stack's definite cross size.
  if (isSingleLine && definiteCrossSize) {
    auto &line = lines[0];
    line.crossSize = minCrossSize;
    
    // We still need to determine the line's baseline
    //TODO unit test
    for (const auto &item : line.items) {
      if (itemIsBaselineAligned(style, item)) {
        CGFloat baseline = ASStackUnpositionedLayout::baselineForItem(style, item);
        line.baseline = MAX(line.baseline, baseline);
      }
    }
    
    return;
  }
  
  for (auto &line : lines) {
    const auto &items = line.items;
    CGFloat maxStartToBaselineDistance = 0;
    CGFloat maxBaselineToEndDistance = 0;
    CGFloat maxItemCrossSize = 0;
    
    for (const auto &item : items) {
      if (itemIsBaselineAligned(style, item)) {
        // Step 1. Collect all the items whose align-self is baseline. Find the largest of the distances
        // between each item’s baseline and its hypothetical outer cross-start edge (aka. its baseline value),
        // and the largest of the distances between each item’s baseline and its hypothetical outer cross-end edge,
        // and sum these two values.
        CGFloat baseline = ASStackUnpositionedLayout::baselineForItem(style, item);
        maxStartToBaselineDistance = MAX(maxStartToBaselineDistance, baseline);
        maxBaselineToEndDistance = MAX(maxBaselineToEndDistance, crossDimension(style.direction, item.layout.size) - baseline);
      } else {
        // Step 2. Among all the items not collected by the previous step, find the largest outer hypothetical cross size.
        maxItemCrossSize = MAX(maxItemCrossSize, crossDimension(style.direction, item.layout.size));
      }
    }
    
    // Step 3. The used cross-size of the flex line is the largest of the numbers found in the previous two steps and zero.
    line.crossSize = MAX(maxStartToBaselineDistance + maxBaselineToEndDistance, maxItemCrossSize);
    if (isSingleLine) {
      // If the stack is single-line, then clamp the line’s cross-size to be within the stack's min and max cross-size properties.
      line.crossSize = MIN(MAX(minCrossSize, line.crossSize), maxCrossSize);
    }
    
    line.baseline = maxStartToBaselineDistance;
  }
}

/**
 Returns a lambda that computes the relevant flex factor based on the given violation.
 @param violation The amount that the stack layout violates its size range.  See header for sign interpretation.
 */
static std::function<CGFloat(const ASStackLayoutSpecItem &)> flexFactorInViolationDirection(const CGFloat violation)
{
  if (std::fabs(violation) < kViolationEpsilon) {
    return [](const ASStackLayoutSpecItem &item) { return 0.0; };
  } else if (violation > 0) {
    return [](const ASStackLayoutSpecItem &item) { return item.child.style.flexGrow; };
  } else {
    return [](const ASStackLayoutSpecItem &item) { return item.child.style.flexShrink; };
  }
}

static inline CGFloat scaledFlexShrinkFactor(const ASStackLayoutSpecItem &item,
                                             const ASStackLayoutSpecStyle &style,
                                             const CGFloat flexFactorSum)
{
  return stackDimension(style.direction, item.layout.size) * (item.child.style.flexShrink / flexFactorSum);
}

/**
 Returns a lambda that computes a flex shrink adjustment for a given item based on the provided violation.
 @param items The unpositioned items from the original unconstrained layout pass.
 @param style The layout style to be applied to all children.
 @param violation The amount that the stack layout violates its size range.
 @param flexFactorSum The sum of each item's flex factor as determined by the provided violation.
 @return A lambda capable of computing the flex shrink adjustment, if any, for a particular item.
 */
static std::function<CGFloat(const ASStackLayoutSpecItem &)> flexShrinkAdjustment(const std::vector<ASStackLayoutSpecItem> &items,
                                                                                  const ASStackLayoutSpecStyle &style,
                                                                                  const CGFloat violation,
                                                                                  const CGFloat flexFactorSum)
{
  const CGFloat scaledFlexShrinkFactorSum = std::accumulate(items.begin(), items.end(), 0.0, [&](CGFloat x, const ASStackLayoutSpecItem &item) {
    return x + scaledFlexShrinkFactor(item, style, flexFactorSum);
  });
  return [style, scaledFlexShrinkFactorSum, violation, flexFactorSum](const ASStackLayoutSpecItem &item) {
    if (scaledFlexShrinkFactorSum == 0.0) {
      return (CGFloat)0.0;
    }
    
    const CGFloat scaledFlexShrinkFactorRatio = scaledFlexShrinkFactor(item, style, flexFactorSum) / scaledFlexShrinkFactorSum;
    // The item should shrink proportionally to the scaled flex shrink factor ratio computed above.
    // Unlike the flex grow adjustment the flex shrink adjustment needs to take the size of each item into account.
    return -std::fabs(scaledFlexShrinkFactorRatio * violation);
  };
}

/**
 Returns a lambda that computes a flex grow adjustment for a given item based on the provided violation.
 @param items The unpositioned items from the original unconstrained layout pass.
 @param violation The amount that the stack layout violates its size range.
 @param flexFactorSum The sum of each item's flex factor as determined by the provided violation.
 @return A lambda capable of computing the flex grow adjustment, if any, for a particular item.
 */
static std::function<CGFloat(const ASStackLayoutSpecItem &)> flexGrowAdjustment(const std::vector<ASStackLayoutSpecItem> &items,
                                                                                const CGFloat violation,
                                                                                const CGFloat flexFactorSum)
{
  // To compute the flex grow adjustment distribute the violation proportionally based on each item's flex grow factor.
  return [violation, flexFactorSum](const ASStackLayoutSpecItem &item) {
    return std::floor(violation * (item.child.style.flexGrow / flexFactorSum));
  };
}

/**
 Returns a lambda that computes a flex adjustment for a given item based on the provided violation.
 @param items The unpositioned items from the original unconstrained layout pass.
 @param style The layout style to be applied to all children.
 @param violation The amount that the stack layout violates its size range.
 @param flexFactorSum The sum of each item's flex factor as determined by the provided violation.
 @return A lambda capable of computing the flex adjustment for a particular item.
 */
static std::function<CGFloat(const ASStackLayoutSpecItem &)> flexAdjustmentInViolationDirection(const std::vector<ASStackLayoutSpecItem> &items,
                                                                                                const ASStackLayoutSpecStyle &style,
                                                                                                const CGFloat violation,
                                                                                                const CGFloat flexFactorSum)
{
  if (violation > 0) {
    return flexGrowAdjustment(items, violation, flexFactorSum);
  } else {
    return flexShrinkAdjustment(items, style, violation, flexFactorSum);
  }
}

ASDISPLAYNODE_INLINE BOOL isFlexibleInBothDirections(const ASStackLayoutSpecChild &child)
{
    return child.style.flexGrow > 0 && child.style.flexShrink > 0;
}

/**
 The flexible children may have been left not laid out in the initial layout pass, so we may have to go through and size
 these children at zero size so that the children layouts are at least present.
 */
static void layoutFlexibleChildrenAtZeroSize(std::vector<ASStackLayoutSpecItem> &items,
                                             const ASStackLayoutSpecStyle &style,
                                             const BOOL concurrent,
                                             const ASSizeRange &sizeRange,
                                             const CGSize parentSize)
{
  dispatchApplyIfNeeded(items.size(), concurrent, ^(size_t i) {
    auto &item = items[i];
    if (isFlexibleInBothDirections(item.child)) {
      item.layout = crossChildLayout(item.child,
                                     style,
                                     0,
                                     0,
                                     crossDimension(style.direction, sizeRange.min),
                                     crossDimension(style.direction, sizeRange.max),
                                     parentSize);
    }
  });
}

/**
 Computes the consumed stack dimension length for the given vector of items and stacking style.

              stackDimensionSum
          <----------------------->
          +-----+  +-------+  +---+
          |     |  |       |  |   |
          |     |  |       |  |   |
          +-----+  |       |  +---+
                   +-------+

 @param items unpositioned layouts for items
 @param style the layout style of the overall stack layout
 */
static CGFloat computeItemsStackDimensionSum(const std::vector<ASStackLayoutSpecItem> &items,
                                             const ASStackLayoutSpecStyle &style)
{
  // Sum up the childrens' spacing
  const CGFloat childSpacingSum = std::accumulate(items.begin(), items.end(),
                                                  // Start from default spacing between each child:
                                                  items.empty() ? 0 : style.spacing * (items.size() - 1),
                                                  [&](CGFloat x, const ASStackLayoutSpecItem &l) {
                                                    return x + l.child.style.spacingBefore + l.child.style.spacingAfter;
                                                  });

  // Sum up the childrens' dimensions (including spacing) in the stack direction.
  const CGFloat childStackDimensionSum = std::accumulate(items.begin(), items.end(), childSpacingSum,
                                                         [&](CGFloat x, const ASStackLayoutSpecItem &l) {
                                                           return x + stackDimension(style.direction, l.layout.size);
                                                         });
  return childStackDimensionSum;
}

//TODO move this up near computeCrossViolation and make both methods share the same code path, to make sure they share the same concept of "negative" and "positive" violations.
/**
 Computes the violation by comparing a stack dimension sum with the overall allowable size range for the stack.

 Violation is the distance you would have to add to the unbounded stack-direction length of the stack spec's
 children in order to bring the stack within its allowed sizeRange.  The diagram below shows 3 horizontal stacks with
 the different types of violation.

                                          sizeRange
                                       |------------|
       +------+ +-------+ +-------+ +---------+
       |      | |       | |       | |  |      |     |
       |      | |       | |       | |         | (zero violation)
       |      | |       | |       | |  |      |     |
       +------+ +-------+ +-------+ +---------+
                                       |            |
       +------+ +-------+ +-------+
       |      | |       | |       |    |            |
       |      | |       | |       |<--> (positive violation)
       |      | |       | |       |    |            |
       +------+ +-------+ +-------+
                                       |            |<------> (negative violation)
       +------+ +-------+ +-------+ +---------+ +-----------+
       |      | |       | |       | |  |      | |   |       |
       |      | |       | |       | |         | |           |
       |      | |       | |       | |  |      | |   |       |
       +------+ +-------+ +-------+ +---------+ +-----------+

 @param stackDimensionSum the consumed length of the children in the stack along the stack dimension
 @param style layout style to be applied to all children
 @param sizeRange the range of allowable sizes for the stack layout spec
 */
CGFloat ASStackUnpositionedLayout::computeStackViolation(const CGFloat stackDimensionSum,
                                                         const ASStackLayoutSpecStyle &style,
                                                         const ASSizeRange &sizeRange)
{
  const CGFloat minStackDimension = stackDimension(style.direction, sizeRange.min);
  const CGFloat maxStackDimension = stackDimension(style.direction, sizeRange.max);
  if (stackDimensionSum < minStackDimension) {
    return minStackDimension - stackDimensionSum;
  } else if (stackDimensionSum > maxStackDimension) {
    return maxStackDimension - stackDimensionSum;
  }
  return 0;
}

/**
 If we have a single flexible (both shrinkable and growable) child, and our allowed size range is set to a specific
 number then we may avoid the first "intrinsic" size calculation.
 */
ASDISPLAYNODE_INLINE BOOL useOptimizedFlexing(const std::vector<ASStackLayoutSpecChild> &children,
                                              const ASStackLayoutSpecStyle &style,
                                              const ASSizeRange &sizeRange)
{
  const NSUInteger flexibleChildren = std::count_if(children.begin(), children.end(), isFlexibleInBothDirections);
  return ((flexibleChildren == 1)
          && (stackDimension(style.direction, sizeRange.min) ==
              stackDimension(style.direction, sizeRange.max)));
}

/**
 Flexes children in the stack axis to resolve a min or max stack size violation. First, determines which children are
 flexible (see computeStackViolation and isFlexibleInViolationDirection). Then computes how much to flex each flexible child
 and performs re-layout. Note that there may still be a non-zero violation even after flexing.

 The actual CSS flexbox spec describes an iterative looping algorithm here, which may be adopted in t5837937:
 http://www.w3.org/TR/css3-flexbox/#resolve-flexible-lengths

 @param lines reference to unpositioned lines and items from the original, unconstrained layout pass; modified in-place
 @param style layout style to be applied to all children
 @param sizeRange the range of allowable sizes for the stack layout component
 @param parentSize Size of the stack layout component. May be undefined in either or both directions.
 */
static void flexLinesAlongStackDimension(std::vector<ASStackUnpositionedLine> &lines,
                                         const ASStackLayoutSpecStyle &style,
                                         const BOOL concurrent,
                                         const ASSizeRange &sizeRange,
                                         const CGSize parentSize,
                                         const BOOL useOptimizedFlexing)
{
  for (auto &line : lines) {
    auto &items = line.items;
    const CGFloat violation = ASStackUnpositionedLayout::computeStackViolation(computeItemsStackDimensionSum(items, style), style, sizeRange);
    std::function<CGFloat(const ASStackLayoutSpecItem &)> flexFactor = flexFactorInViolationDirection(violation);
    // The flex factor sum is needed to determine if flexing is necessary.
    // This value is also needed if the violation is positive and flexible items need to grow, so keep it around.
    const CGFloat flexFactorSum = std::accumulate(items.begin(), items.end(), 0.0, [&](CGFloat x, const ASStackLayoutSpecItem &item) {
      return x + flexFactor(item);
    });
    
    // If no items are able to flex then there is nothing left to do with this line. Bail.
    if (flexFactorSum == 0) {
      // If optimized flexing was used then we have to clean up the unsized items and lay them out at zero size.
      if (useOptimizedFlexing) {
        layoutFlexibleChildrenAtZeroSize(items, style, concurrent, sizeRange, parentSize);
      }
      continue;
    }
    
    std::function<CGFloat(const ASStackLayoutSpecItem &)> flexAdjustment = flexAdjustmentInViolationDirection(items,
                                                                                                              style,
                                                                                                              violation,
                                                                                                              flexFactorSum);
    // Compute any remaining violation to the first flexible item.
    const CGFloat remainingViolation = std::accumulate(items.begin(), items.end(), violation, [&](CGFloat x, const ASStackLayoutSpecItem &item) {
      return x - flexAdjustment(item);
    });
    
    size_t firstFlexItem = -1;
    for(size_t i = 0; i < items.size(); i++) {
      // Items are consider inflexible if they do not need to make a flex adjustment.
      if (flexAdjustment(items[i]) != 0) {
        firstFlexItem = i;
        break;
      }
    }
    if (firstFlexItem == -1) {
      continue;
    }
    
    dispatchApplyIfNeeded(items.size(), concurrent, ^(size_t i) {
      auto &item = items[i];
      const CGFloat currentFlexAdjustment = flexAdjustment(item);
      // Items are consider inflexible if they do not need to make a flex adjustment.
      if (currentFlexAdjustment != 0) {
        const CGFloat originalStackSize = stackDimension(style.direction, item.layout.size);
        // Only apply the remaining violation for the first flexible item that has a flex grow factor.
        const CGFloat flexedStackSize = originalStackSize + currentFlexAdjustment + (i == firstFlexItem && item.child.style.flexGrow > 0 ? remainingViolation : 0);
        item.layout = crossChildLayout(item.child,
                                       style,
                                       MAX(flexedStackSize, 0),
                                       MAX(flexedStackSize, 0),
                                       crossDimension(style.direction, sizeRange.min),
                                       crossDimension(style.direction, sizeRange.max),
                                       parentSize);
      }
    });
  }
}

/**
 https://www.w3.org/TR/css-flexbox-1/#algo-line-break
 */
static std::vector<ASStackUnpositionedLine> collectChildrenIntoLines(const std::vector<ASStackLayoutSpecItem> &items,
                                                                     const ASStackLayoutSpecStyle &style,
                                                                     const ASSizeRange &sizeRange)
{
  //TODO if infinite max stack size, fast path
  if (style.flexWrap == ASStackLayoutFlexWrapNoWrap) {
    return std::vector<ASStackUnpositionedLine> (1, {.items = std::move(items)});
  }
  
  std::vector<ASStackUnpositionedLine> lines;
  std::vector<ASStackLayoutSpecItem> lineItems;
  CGFloat lineStackDimensionSum = 0;

  for(auto it = items.begin(); it != items.end(); ++it) {
    const auto &item = *it;
    const CGFloat itemStackDimension = stackDimension(style.direction, item.layout.size);
    const BOOL negativeViolationIfAddItem = (ASStackUnpositionedLayout::computeStackViolation(lineStackDimensionSum + itemStackDimension, style, sizeRange) < 0);
    const BOOL breakCurrentLine = negativeViolationIfAddItem && !lineItems.empty();
    
    if (breakCurrentLine) {
      lines.push_back({.items = std::vector<ASStackLayoutSpecItem> (lineItems)});
      lineItems.clear();
      lineStackDimensionSum = 0;
    }
    
    lineItems.push_back(std::move(item));
    lineStackDimensionSum += itemStackDimension;
  }
  
  // Handle last line
  lines.push_back({.items = std::vector<ASStackLayoutSpecItem> (lineItems)});
  
  return lines;
}

/**
 Performs the first unconstrained layout of the children, generating the unpositioned items that are then flexed and
 stretched.
 */
static void layoutItemsAlongUnconstrainedStackDimension(std::vector<ASStackLayoutSpecItem> &items,
                                                        const ASStackLayoutSpecStyle &style,
                                                        const BOOL concurrent,
                                                        const ASSizeRange &sizeRange,
                                                        const CGSize parentSize,
                                                        const BOOL useOptimizedFlexing)
{
  const CGFloat minCrossDimension = crossDimension(style.direction, sizeRange.min);
  const CGFloat maxCrossDimension = crossDimension(style.direction, sizeRange.max);
  
  dispatchApplyIfNeeded(items.size(), concurrent, ^(size_t i) {
    auto &item = items[i];
    if (useOptimizedFlexing && isFlexibleInBothDirections(item.child)) {
      item.layout = [ASLayout layoutWithLayoutElement:item.child.element size:{0, 0}];
    } else {
      item.layout = crossChildLayout(item.child,
                                     style,
                                     ASDimensionResolve(item.child.style.flexBasis, stackDimension(style.direction, parentSize), 0),
                                     ASDimensionResolve(item.child.style.flexBasis, stackDimension(style.direction, parentSize), INFINITY),
                                     minCrossDimension,
                                     maxCrossDimension,
                                     parentSize);
    }
  });
}

ASStackUnpositionedLayout ASStackUnpositionedLayout::compute(const std::vector<ASStackLayoutSpecChild> &children,
                                                             const ASStackLayoutSpecStyle &style,
                                                             const ASSizeRange &sizeRange,
                                                             const BOOL concurrent)
{
  if (children.empty()) {
    return {};
  }
  
  // If we have a fixed size in either dimension, pass it to children so they can resolve percentages against it.
  // Otherwise, we pass ASLayoutElementParentDimensionUndefined since it will depend on the content.
  const CGSize parentSize = {
    (sizeRange.min.width == sizeRange.max.width) ? sizeRange.min.width : ASLayoutElementParentDimensionUndefined,
    (sizeRange.min.height == sizeRange.max.height) ? sizeRange.min.height : ASLayoutElementParentDimensionUndefined,
  };

  // We may be able to avoid some redundant layout passes
  const BOOL optimizedFlexing = useOptimizedFlexing(children, style, sizeRange);

  std::vector<ASStackLayoutSpecItem> items = AS::map(children, [&](const ASStackLayoutSpecChild &child) -> ASStackLayoutSpecItem {
    return {child, nil};
  });
  
  // We do a first pass of all the children, generating an unpositioned layout for each with an unbounded range along
  // the stack dimension.  This allows us to compute the "intrinsic" size of each child and find the available violation
  // which determines whether we must grow or shrink the flexible children.
  layoutItemsAlongUnconstrainedStackDimension(items,
                                              style,
                                              concurrent,
                                              sizeRange,
                                              parentSize,
                                              optimizedFlexing);
  
  // Collect items into lines (https://www.w3.org/TR/css-flexbox-1/#algo-line-break)
  std::vector<ASStackUnpositionedLine> lines = collectChildrenIntoLines(items, style, sizeRange);
  
  // Resolve the flexible lengths (https://www.w3.org/TR/css-flexbox-1/#resolve-flexible-lengths)
  flexLinesAlongStackDimension(lines, style, concurrent, sizeRange, parentSize, optimizedFlexing);
  
  // Calculate the cross size of each flex line (https://www.w3.org/TR/css-flexbox-1/#algo-cross-line)
  computeLinesCrossSizeAndBaseline(lines, style, sizeRange);
  
  // Handle 'align-content: stretch' (https://www.w3.org/TR/css-flexbox-1/#algo-line-stretch)
  // Determine the used cross size of each item (https://www.w3.org/TR/css-flexbox-1/#algo-stretch)
  stretchLinesAlongCrossDimension(lines, style, concurrent, sizeRange, parentSize);
  
  // Compute stack dimension sum of each line and the whole stack
  CGFloat layoutStackDimensionSum = 0;
  for (auto &line : lines) {
    line.stackDimensionSum = computeItemsStackDimensionSum(line.items, style);
    // layoutStackDimensionSum is the max stackDimensionSum among all lines
    layoutStackDimensionSum = MAX(line.stackDimensionSum, layoutStackDimensionSum);
  }
  // Compute cross dimension sum of the stack.
  // This should be done before `lines` are moved to a new ASStackUnpositionedLayout struct (i.e `std::move(lines)`)
  CGFloat layoutCrossDimensionSum = computeLinesCrossDimensionSum(lines);
  
  return {.lines = std::move(lines), .stackDimensionSum = layoutStackDimensionSum, .crossDimensionSum = layoutCrossDimensionSum};
}

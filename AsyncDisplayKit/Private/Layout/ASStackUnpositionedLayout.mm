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

#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>

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

/** The threshold that determines if a violation has actually occurred. */
static const CGFloat kViolationEpsilon = 0.01;

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

 @param items pre-computed child layouts; modified in-place as needed
 @param style the layout style of the overall stack layout
 */
static void stretchChildrenAlongCrossDimension(std::vector<ASStackLayoutSpecItem> &items,
                                               const ASStackLayoutSpecStyle &style,
                                               const CGSize parentSize,
                                               const CGFloat crossSize)
{
  for (auto &item : items) {
    const ASStackLayoutAlignItems alignItems = alignment(item.child.style.alignSelf, style.alignItems);
    if (alignItems != ASStackLayoutAlignItemsStretch) {
      continue;
    }
    
    const CGFloat cross = crossDimension(style.direction, item.layout.size);
    const CGFloat stack = stackDimension(style.direction, item.layout.size);
    const CGFloat violation = crossSize - cross;
    
    // Only stretch if violation is positive. Compare against kViolationEpsilon here to avoid stretching against a tiny violation.
    if (violation > kViolationEpsilon) {
      item.layout = crossChildLayout(item.child, style, stack, stack, crossSize, crossSize, parentSize);
    }
  }
}


static BOOL itemIsBaselineAligned(const ASStackLayoutSpecStyle &style,
                                  const ASStackLayoutSpecItem &l)
{
  ASStackLayoutAlignItems alignItems = alignment(l.child.style.alignSelf, style.alignItems);
  return alignItems == ASStackLayoutAlignItemsBaselineFirst || alignItems == ASStackLayoutAlignItemsBaselineLast;
}

CGFloat ASStackUnpositionedLayout::baselineForItem(const ASStackLayoutSpecStyle &style,
                                                   const ASStackLayoutSpecItem &l)
{
  switch (alignment(l.child.style.alignSelf, style.alignItems)) {
    case ASStackLayoutAlignItemsBaselineFirst:
      return l.child.style.ascender;
    case ASStackLayoutAlignItemsBaselineLast:
      return crossDimension(style.direction, l.layout.size) + l.child.style.descender;
    default:
      return 0;
  }
}

/**
 * Finds cross dimension size and baseline of the stack.
 * https://www.w3.org/TR/css-flexbox-1/#algo-cross-line
 *
 * @param items All items to lay out
 * @param style the layout style of the overall stack layout
 * @param sizeRange the range of allowable sizes for the stack layout component
 * @param crossSize result of the cross size
 * @param baseline result of the stack baseline
 */
static void computeCrossSizeAndBaseline(const std::vector<ASStackLayoutSpecItem> &items,
                                        const ASStackLayoutSpecStyle &style,
                                        const ASSizeRange &sizeRange,
                                        CGFloat &crossSize,
                                        CGFloat &baseline)
{
  const auto minCrossSize = crossDimension(style.direction, sizeRange.min);
  const auto maxCrossSize = crossDimension(style.direction, sizeRange.max);
  
  // Step 1. Collect all the flex items whose align-self is baseline. Find the largest of the distances
  // between each item’s baseline and its hypothetical outer cross-start edge (aka. its ascender value),
  // and the largest of the distances between each item’s baseline and its hypothetical outer cross-end edge
  // (aka. the opposite of its descender value, because a negative descender means the item extends below its baseline),
  // and sum these two values.
  //
  // Step 2. Find the maximum cross dimension size among child layouts.
  CGFloat maxStartToBaselineDistance = 0;
  CGFloat maxBaselineToEndDistance = 0;
  CGFloat maxItemCrossSize = 0;
  for (const auto &item : items) {
    if (itemIsBaselineAligned(style, item)) {
      CGFloat baseline = ASStackUnpositionedLayout::baselineForItem(style, item);
      maxStartToBaselineDistance = MAX(maxStartToBaselineDistance, baseline);
      maxBaselineToEndDistance = MAX(maxBaselineToEndDistance, crossDimension(style.direction, item.layout.size) - baseline);
    } else {
      maxItemCrossSize = MAX(maxItemCrossSize, crossDimension(style.direction, item.layout.size));
    }
  }
  
  // Step 3. The used cross-size of the flex line is the largest of the numbers found in the previous two steps and zero.
  crossSize = MAX(maxStartToBaselineDistance + maxBaselineToEndDistance, maxItemCrossSize);;
  // Clamp the cross-size to be within the stack's min and max cross-size properties.
  crossSize = MIN(MAX(minCrossSize, crossSize), maxCrossSize);
  
  baseline = maxStartToBaselineDistance;
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
                                             const ASSizeRange &sizeRange,
                                             const CGSize parentSize)
{
  for (ASStackLayoutSpecItem &item : items) {
    if (isFlexibleInBothDirections(item.child)) {
      item.layout = crossChildLayout(item.child,
                                     style,
                                     0,
                                     0,
                                     crossDimension(style.direction, sizeRange.min),
                                     crossDimension(style.direction, sizeRange.max),
                                     parentSize);
    }
  }
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
static CGFloat computeStackDimensionSum(const std::vector<ASStackLayoutSpecItem> &items,
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
static CGFloat computeViolation(const CGFloat stackDimensionSum,
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
 flexible (see computeViolation and isFlexibleInViolationDirection). Then computes how much to flex each flexible child
 and performs re-layout. Note that there may still be a non-zero violation even after flexing.

 The actual CSS flexbox spec describes an iterative looping algorithm here, which may be adopted in t5837937:
 http://www.w3.org/TR/css3-flexbox/#resolve-flexible-lengths

 @param items Reference to unpositioned items from the original, unconstrained layout pass; modified in-place
 @param style layout style to be applied to all children
 @param sizeRange the range of allowable sizes for the stack layout component
 @param parentSize Size of the stack layout component. May be undefined in either or both directions.
 */
static void flexChildrenAlongStackDimension(std::vector<ASStackLayoutSpecItem> &items,
                                            const ASStackLayoutSpecStyle &style,
                                            const ASSizeRange &sizeRange,
                                            const CGSize parentSize,
                                            const BOOL useOptimizedFlexing)
{
  const CGFloat violation = computeViolation(computeStackDimensionSum(items, style), style, sizeRange);
  std::function<CGFloat(const ASStackLayoutSpecItem &)> flexFactor = flexFactorInViolationDirection(violation);
  // The flex factor sum is needed to determine if flexing is necessary.
  // This value is also needed if the violation is positive and flexible children need to grow, so keep it around.
  const CGFloat flexFactorSum = std::accumulate(items.begin(), items.end(), 0.0, [&](CGFloat x, const ASStackLayoutSpecItem &item) {
    return x + flexFactor(item);
  });
  // If no children are able to flex then there is nothing left to do. Bail.
  if (flexFactorSum == 0) {
    // If optimized flexing was used then we have to clean up the unsized children and lay them out at zero size.
    if (useOptimizedFlexing) {
      layoutFlexibleChildrenAtZeroSize(items, style, sizeRange, parentSize);
    }
    return;
  }
  std::function<CGFloat(const ASStackLayoutSpecItem &)> flexAdjustment = flexAdjustmentInViolationDirection(items,
                                                                                                            style,
                                                                                                            violation,
                                                                                                            flexFactorSum);

  // Compute any remaining violation to the first flexible child.
  const CGFloat remainingViolation = std::accumulate(items.begin(), items.end(), violation, [&](CGFloat x, const ASStackLayoutSpecItem &item) {
    return x - flexAdjustment(item);
  });
  BOOL isFirstFlex = YES;
  for (ASStackLayoutSpecItem &item : items) {
    const CGFloat currentFlexAdjustment = flexAdjustment(item);
    // Children are consider inflexible if they do not need to make a flex adjustment.
    if (currentFlexAdjustment != 0) {
      const CGFloat originalStackSize = stackDimension(style.direction, item.layout.size);
      // Only apply the remaining violation for the first flexible child that has a flex grow factor.
      const CGFloat flexedStackSize = originalStackSize + currentFlexAdjustment + (isFirstFlex && item.child.style.flexGrow > 0 ? remainingViolation : 0);
      item.layout = crossChildLayout(item.child,
                                     style,
                                     MAX(flexedStackSize, 0),
                                     MAX(flexedStackSize, 0),
                                     crossDimension(style.direction, sizeRange.min),
                                     crossDimension(style.direction, sizeRange.max),
                                     parentSize);
      isFirstFlex = NO;
    }
  }
}

/**
 Performs the first unconstrained layout of the children, generating the unpositioned items that are then flexed and
 stretched.
 */
static std::vector<ASStackLayoutSpecItem> layoutChildrenAlongUnconstrainedStackDimension(const std::vector<ASStackLayoutSpecChild> &children,
                                                                                         const ASStackLayoutSpecStyle &style,
                                                                                         const ASSizeRange &sizeRange,
                                                                                         const CGSize parentSize,
                                                                                         const BOOL useOptimizedFlexing)
{
  const CGFloat minCrossDimension = crossDimension(style.direction, sizeRange.min);
  const CGFloat maxCrossDimension = crossDimension(style.direction, sizeRange.max);
  return AS::map(children, [&](const ASStackLayoutSpecChild &child) -> ASStackLayoutSpecItem {
    if (useOptimizedFlexing && isFlexibleInBothDirections(child)) {
      return {child, [ASLayout layoutWithLayoutElement:child.element size:{0, 0}]};
    } else {
      return {
        child,
        crossChildLayout(child,
                         style,
                         ASDimensionResolve(child.style.flexBasis, stackDimension(style.direction, parentSize), 0),
                         ASDimensionResolve(child.style.flexBasis, stackDimension(style.direction, parentSize), INFINITY),
                         minCrossDimension,
                         maxCrossDimension,
                         parentSize)
      };
    }
  });
}

ASStackUnpositionedLayout ASStackUnpositionedLayout::compute(const std::vector<ASStackLayoutSpecChild> &children,
                                                             const ASStackLayoutSpecStyle &style,
                                                             const ASSizeRange &sizeRange)
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

  // We do a first pass of all the children, generating an unpositioned layout for each with an unbounded range along
  // the stack dimension.  This allows us to compute the "intrinsic" size of each child and find the available violation
  // which determines whether we must grow or shrink the flexible children.
  std::vector<ASStackLayoutSpecItem> items = layoutChildrenAlongUnconstrainedStackDimension(children,
                                                                                               style,
                                                                                               sizeRange,
                                                                                               parentSize,
                                                                                               optimizedFlexing);
  
  // Resolve the flexible lengths (https://www.w3.org/TR/css-flexbox-1/#algo-flex)
  // Determine the hypothetical cross size of each item (https://www.w3.org/TR/css-flexbox-1/#algo-cross-item)
  flexChildrenAlongStackDimension(items, style, sizeRange, parentSize, optimizedFlexing);
  
  // Step 4. Cross Size Determination (https://www.w3.org/TR/css-flexbox-1/#cross-sizing)
  //
  // Calculate the cross size of the stack (https://www.w3.org/TR/css-flexbox-1/#algo-cross-line)
  CGFloat crossSize;
  CGFloat baseline;
  computeCrossSizeAndBaseline(items, style, sizeRange, crossSize, baseline);
  // Determine the used cross size of each item (https://www.w3.org/TR/css-flexbox-1/#algo-stretch)
  // If the flex item has stretch alignment, redo layout
  stretchChildrenAlongCrossDimension(items, style, parentSize, crossSize);
  
  const CGFloat stackDimensionSum = computeStackDimensionSum(items, style);
  return {std::move(items), stackDimensionSum, computeViolation(stackDimensionSum, style, sizeRange), crossSize, baseline};
}

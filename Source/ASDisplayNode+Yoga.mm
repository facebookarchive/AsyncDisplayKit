//
//  ASDisplayNode+Yoga.mm
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 2/8/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if YOGA /* YOGA */

#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASLayout.h>

#define YOGA_LAYOUT_LOGGING 0

extern void ASDisplayNodePerformBlockOnEveryYogaChild(ASDisplayNode * _Nullable node, void(^block)(ASDisplayNode *node))
{
  if (node == nil) {
    return;
  }
  block(node);
  for (ASDisplayNode *child in [node yogaChildren]) {
    ASDisplayNodePerformBlockOnEveryYogaChild(child, block);
  }
}

#pragma mark - Yoga Type Conversion Helpers

YGAlign yogaAlignItems(ASStackLayoutAlignItems alignItems);
YGJustify yogaJustifyContent(ASStackLayoutJustifyContent justifyContent);
YGAlign yogaAlignSelf(ASStackLayoutAlignSelf alignSelf);
YGFlexDirection yogaFlexDirection(ASStackLayoutDirection direction);
float yogaFloatForCGFloat(CGFloat value);
float yogaDimensionToPoints(ASDimension dimension);
float yogaDimensionToPercent(ASDimension dimension);
ASDimension dimensionForEdgeWithEdgeInsets(YGEdge edge, ASEdgeInsets insets);
YGSize ASLayoutElementYogaMeasureFunc(YGNodeRef yogaNode,
                                      float width, YGMeasureMode widthMode,
                                      float height, YGMeasureMode heightMode);

#define YGNODE_STYLE_SET_DIMENSION(yogaNode, property, dimension) \
  if (dimension.unit == ASDimensionUnitPoints) { \
    YGNodeStyleSet##property(yogaNode, yogaDimensionToPoints(dimension)); \
  } else if (dimension.unit == ASDimensionUnitFraction) { \
    YGNodeStyleSet##property##Percent(yogaNode, yogaDimensionToPercent(dimension)); \
  } else { \
    YGNodeStyleSet##property(yogaNode, YGUndefined); \
  }\

#define YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, property, dimension, edge) \
  if (dimension.unit == ASDimensionUnitPoints) { \
    YGNodeStyleSet##property(yogaNode, edge, yogaDimensionToPoints(dimension)); \
  } else if (dimension.unit == ASDimensionUnitFraction) { \
    YGNodeStyleSet##property##Percent(yogaNode, edge, yogaDimensionToPercent(dimension)); \
  } else { \
    YGNodeStyleSet##property(yogaNode, edge, YGUndefined); \
  } \

#define YGNODE_STYLE_SET_FLOAT_WITH_EDGE(yogaNode, property, dimension, edge) \
  if (dimension.unit == ASDimensionUnitPoints) { \
    YGNodeStyleSet##property(yogaNode, edge, yogaDimensionToPoints(dimension)); \
  } else if (dimension.unit == ASDimensionUnitFraction) { \
    ASDisplayNodeAssert(NO, @"Unexpected Fraction value in applying ##property## values to YGNode"); \
  } else { \
    YGNodeStyleSet##property(yogaNode, edge, YGUndefined); \
  } \

YGAlign yogaAlignItems(ASStackLayoutAlignItems alignItems)
{
  switch (alignItems) {
    case ASStackLayoutAlignItemsNotSet:         return YGAlignAuto;
    case ASStackLayoutAlignItemsStart:          return YGAlignFlexStart;
    case ASStackLayoutAlignItemsEnd:            return YGAlignFlexEnd;
    case ASStackLayoutAlignItemsCenter:         return YGAlignCenter;
    case ASStackLayoutAlignItemsStretch:        return YGAlignStretch;
    case ASStackLayoutAlignItemsBaselineFirst:  return YGAlignBaseline;
      // FIXME: WARNING, Yoga does not currently support last-baseline item alignment.
    case ASStackLayoutAlignItemsBaselineLast:   return YGAlignBaseline;
  }
}

YGJustify yogaJustifyContent(ASStackLayoutJustifyContent justifyContent)
{
  switch (justifyContent) {
    case ASStackLayoutJustifyContentStart:        return YGJustifyFlexStart;
    case ASStackLayoutJustifyContentCenter:       return YGJustifyCenter;
    case ASStackLayoutJustifyContentEnd:          return YGJustifyFlexEnd;
    case ASStackLayoutJustifyContentSpaceBetween: return YGJustifySpaceBetween;
    case ASStackLayoutJustifyContentSpaceAround:  return YGJustifySpaceAround;
  }
}

YGAlign yogaAlignSelf(ASStackLayoutAlignSelf alignSelf)
{
  switch (alignSelf) {
    case ASStackLayoutAlignSelfStart:   return YGAlignFlexStart;
    case ASStackLayoutAlignSelfCenter:  return YGAlignCenter;
    case ASStackLayoutAlignSelfEnd:     return YGAlignFlexEnd;
    case ASStackLayoutAlignSelfStretch: return YGAlignStretch;
    case ASStackLayoutAlignSelfAuto:    return YGAlignAuto;
  }
}

YGFlexDirection yogaFlexDirection(ASStackLayoutDirection direction)
{
  return direction == ASStackLayoutDirectionVertical ? YGFlexDirectionColumn : YGFlexDirectionRow;
}

float yogaFloatForCGFloat(CGFloat value)
{
  if (value < CGFLOAT_MAX / 2) {
    return value;
  } else {
    return YGUndefined;
  }
}

float yogaDimensionToPoints(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.unit == ASDimensionUnitPoints,
                       @"Dimensions should not be type Fraction for this method: %f", dimension.value);
  return yogaFloatForCGFloat(dimension.value);
}

float yogaDimensionToPercent(ASDimension dimension)
{
  ASDisplayNodeCAssert(dimension.unit == ASDimensionUnitFraction,
                       @"Dimensions should not be type Points for this method: %f", dimension.value);
  return 100.0 * yogaFloatForCGFloat(dimension.value);

}

ASDimension dimensionForEdgeWithEdgeInsets(YGEdge edge, ASEdgeInsets insets)
{
  switch (edge) {
    case YGEdgeLeft:   return insets.left;
    case YGEdgeTop:    return insets.top;
    case YGEdgeRight:  return insets.right;
    case YGEdgeBottom: return insets.bottom;
    default: ASDisplayNodeCAssert(NO, @"YGEdge other than ASEdgeInsets is not supported.");
      return ASDimensionAuto;
  }
}

YGSize ASLayoutElementYogaMeasureFunc(YGNodeRef yogaNode, float width, YGMeasureMode widthMode,
                                      float height, YGMeasureMode heightMode)
{
  id <ASLayoutElement> layoutElement = (__bridge id <ASLayoutElement>)YGNodeGetContext(yogaNode);
  ASSizeRange sizeRange;
  sizeRange.max = CGSizeMake(width, height);
  sizeRange.min = sizeRange.max;
  if (widthMode == YGMeasureModeAtMost) {
    sizeRange.min.width = 0.0;
  }
  if (heightMode == YGMeasureModeAtMost) {
    sizeRange.min.height = 0.0;
  }
  CGSize size = [[layoutElement layoutThatFits:sizeRange] size];
  return (YGSize){ .width = (float)size.width, .height = (float)size.height };
}

#pragma mark - ASDisplayNode+Yoga

@interface ASDisplayNode (YogaInternal)
@property (nonatomic, weak) ASDisplayNode *yogaParent;
@property (nonatomic, assign) YGNodeRef yogaNode;
@end

@implementation ASDisplayNode (Yoga)

- (void)setYogaNode:(YGNodeRef)yogaNode
{
  _yogaNode = yogaNode;
}

- (YGNodeRef)yogaNode
{
  if (_yogaNode == NULL) {
    _yogaNode = YGNodeNew();
  }
  return _yogaNode;
}

- (void)setYogaParent:(ASDisplayNode *)yogaParent
{
  if (_yogaParent == yogaParent) {
    return;
  }

  YGNodeRef yogaNode = self.yogaNode; // Use property to assign Ref if needed.
  YGNodeRef oldParentRef = YGNodeGetParent(yogaNode);
  if (oldParentRef != NULL) {
    YGNodeRemoveChild(oldParentRef, yogaNode);
  }

  _yogaParent = yogaParent;
  if (yogaParent) {
    self.hierarchyState |= ASHierarchyStateYogaLayoutEnabled;
    YGNodeRef newParentRef = yogaParent.yogaNode;
    YGNodeInsertChild(newParentRef, yogaNode, YGNodeGetChildCount(newParentRef));
  } else {
    self.hierarchyState &= ~ASHierarchyStateYogaLayoutEnabled;
  }
}

- (ASDisplayNode *)yogaParent
{
  return _yogaParent;
}

- (void)setYogaChildren:(NSArray *)yogaChildren
{
  for (ASDisplayNode *child in _yogaChildren) {
    // Make sure to un-associate the YGNodeRef tree before replacing _yogaChildren
    // If this becomes a performance bottleneck, it can be optimized by not doing the NSArray removals here.
    [self removeYogaChild:child];
  }
  _yogaChildren = nil;
  for (ASDisplayNode *child in yogaChildren) {
    [self addYogaChild:child];
  }
}

- (NSArray *)yogaChildren
{
  return _yogaChildren;
}

- (void)addYogaChild:(ASDisplayNode *)child
{
  if (child == nil) {
    return;
  }
  if (_yogaChildren == nil) {
    _yogaChildren = [NSMutableArray array];
  }

  // Clean up state in case this child had another parent.
  [self removeYogaChild:child];

  // YGNodeRef insertion is done in setParent:
  child.yogaParent = self;
  [_yogaChildren addObject:child];

  self.hierarchyState |= ASHierarchyStateYogaLayoutEnabled;
}

- (void)removeYogaChild:(ASDisplayNode *)child
{
  if (child == nil) {
    return;
  }
  // YGNodeRef removal is done in setParent:
  child.yogaParent = nil;
  [_yogaChildren removeObjectIdenticalTo:child];

  if (_yogaChildren.count == 0 && self.yogaParent == nil) {
    self.hierarchyState &= ~ASHierarchyStateYogaLayoutEnabled;
  }
}

- (void)setYogaCalculatedLayout:(ASLayout *)yogaCalculatedLayout
{
  _yogaCalculatedLayout = yogaCalculatedLayout;
}

- (ASLayout *)yogaCalculatedLayout
{
  return _yogaCalculatedLayout;
}

- (ASLayout *)layoutForYogaNode
{
  YGNodeRef yogaNode = self.yogaNode;

  CGSize  size     = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));
  CGPoint position = CGPointMake(YGNodeLayoutGetLeft(yogaNode), YGNodeLayoutGetTop(yogaNode));

  // TODO: If it were possible to set .flattened = YES, it would be valid to do so here.
  return [ASLayout layoutWithLayoutElement:self size:size position:position sublayouts:nil];
}

- (void)setupYogaCalculatedLayout
{
  YGNodeRef yogaNode = self.yogaNode; // Use property to assign Ref if needed.
  uint32_t childCount = YGNodeGetChildCount(yogaNode);
  ASDisplayNodeAssert(childCount == self.yogaChildren.count,
                      @"Yoga tree should always be in sync with .yogaNodes array! %@", self.yogaChildren);

  NSMutableArray *sublayouts = [NSMutableArray arrayWithCapacity:childCount];
  for (ASDisplayNode *subnode in self.yogaChildren) {
    [sublayouts addObject:[subnode layoutForYogaNode]];
  }

  // The layout for self should have position CGPointNull, but include the calculated size.
  CGSize size = CGSizeMake(YGNodeLayoutGetWidth(yogaNode), YGNodeLayoutGetHeight(yogaNode));
  ASLayout *layout = [ASLayout layoutWithLayoutElement:self size:size sublayouts:sublayouts];
  self.yogaCalculatedLayout = layout;
}

- (void)setYogaMeasureFuncIfNeeded
{
  // Manual size calculation via calculateSizeThatFits:
  // This will be used for ASTextNode, as well as any other leaf node that has no layout spec.
  if ((self.methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) == NO
      && self.layoutSpecBlock == NULL &&  self.yogaChildren.count == 0) {
    YGNodeRef yogaNode = self.yogaNode; // Use property to assign Ref if needed.
    YGNodeSetContext(yogaNode, (__bridge void *)self);
    YGNodeSetMeasureFunc(yogaNode, &ASLayoutElementYogaMeasureFunc);
  }
}

- (void)invalidateCalculatedYogaLayout
{
  // Yoga internally asserts that this method may only be called on nodes with a measurement function.
  YGNodeRef yogaNode = self.yogaNode;
  if (YGNodeGetMeasureFunc(yogaNode)) {
    YGNodeMarkDirty(yogaNode);
  }
}

- (void)calculateLayoutFromYogaRoot:(ASSizeRange)rootConstrainedSize
{
  if (ASHierarchyStateIncludesYogaLayoutMeasuring(self.hierarchyState)) {
    ASDisplayNodeAssert(NO, @"A Yoga layout is being performed by a parent; children must not perform their own until it is done! %@", [self displayNodeRecursiveDescription]);
    return;
  }

  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
    node.hierarchyState |= ASHierarchyStateYogaLayoutMeasuring;
  });

  YGNodeRef rootYogaNode = self.yogaNode;

  // Apply the constrainedSize as a base, known frame of reference.
  // If the root node also has style.*Size set, these will be overridden below.
  // YGNodeCalculateLayout currently doesn't offer the ability to pass a minimum size (max is passed there).
  YGNodeStyleSetMinWidth (rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.width));
  YGNodeStyleSetMinHeight(rootYogaNode, yogaFloatForCGFloat(rootConstrainedSize.min.height));

  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
    ASLayoutElementStyle *style = node.style;
    YGNodeRef yogaNode = node.yogaNode;

    YGNodeStyleSetDirection     (yogaNode, YGDirectionInherit);

    YGNodeStyleSetFlexWrap      (yogaNode, style.flexWrap);
    YGNodeStyleSetFlexGrow      (yogaNode, style.flexGrow);
    YGNodeStyleSetFlexShrink    (yogaNode, style.flexShrink);
    YGNODE_STYLE_SET_DIMENSION  (yogaNode, FlexBasis, style.flexBasis);

    YGNodeStyleSetFlexDirection (yogaNode, yogaFlexDirection(style.direction));
    YGNodeStyleSetJustifyContent(yogaNode, yogaJustifyContent(style.justifyContent));
    YGNodeStyleSetAlignSelf     (yogaNode, yogaAlignSelf(style.alignSelf));
    ASStackLayoutAlignItems alignItems = style.alignItems;
    if (alignItems != ASStackLayoutAlignItemsNotSet) {
      YGNodeStyleSetAlignItems(yogaNode, yogaAlignItems(alignItems));
    }

    YGNodeStyleSetPositionType  (yogaNode, style.positionType);
    ASEdgeInsets position = style.position;
    ASEdgeInsets margin   = style.margin;
    ASEdgeInsets padding  = style.padding;
    ASEdgeInsets border   = style.border;

    YGEdge edge = YGEdgeLeft;
    for (int i = 0; i < 4; i++) {
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Position, dimensionForEdgeWithEdgeInsets(edge, position), edge);
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Margin, dimensionForEdgeWithEdgeInsets(edge, margin), edge);
      YGNODE_STYLE_SET_DIMENSION_WITH_EDGE(yogaNode, Padding, dimensionForEdgeWithEdgeInsets(edge, padding), edge);
      YGNODE_STYLE_SET_FLOAT_WITH_EDGE(yogaNode, Border, dimensionForEdgeWithEdgeInsets(edge, border), edge);
      edge = (edge == YGEdgeLeft ? YGEdgeTop : (edge == YGEdgeTop ? YGEdgeRight : YGEdgeBottom));
    }

    CGFloat aspectRatio = style.aspectRatio;
    if (aspectRatio > FLT_EPSILON && aspectRatio < CGFLOAT_MAX / 2.0) {
      YGNodeStyleSetAspectRatio(yogaNode, aspectRatio);
    }

    // For the root node, we use rootConstrainedSize above. For children, consult the style for their size.
    if (node != self) {
      YGNODE_STYLE_SET_DIMENSION(yogaNode, Width, style.width);
      YGNODE_STYLE_SET_DIMENSION(yogaNode, Height, style.height);

      YGNODE_STYLE_SET_DIMENSION(yogaNode, MinWidth, style.minWidth);
      YGNODE_STYLE_SET_DIMENSION(yogaNode, MinHeight, style.minHeight);

      YGNODE_STYLE_SET_DIMENSION(yogaNode, MaxWidth, style.maxWidth);
      YGNODE_STYLE_SET_DIMENSION(yogaNode, MaxHeight, style.maxHeight);
    }

    [node setYogaMeasureFuncIfNeeded];

    /* TODO(appleguy): STYLE SETTER METHODS LEFT TO IMPLEMENT
     void YGNodeStyleSetFlexDirection(YGNodeRef node, YGFlexDirection flexDirection);
     void YGNodeStyleSetOverflow(YGNodeRef node, YGOverflow overflow);
     void YGNodeStyleSetFlex(YGNodeRef node, float flex);
     */
  });

  // It is crucial to use yogaFloat... to convert CGFLOAT_MAX into YGUndefined here.
  YGNodeCalculateLayout(rootYogaNode,
                        yogaFloatForCGFloat(rootConstrainedSize.max.width),
                        yogaFloatForCGFloat(rootConstrainedSize.max.height),
                        YGDirectionInherit);

  ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
    [node setupYogaCalculatedLayout];
    node.hierarchyState &= ~ASHierarchyStateYogaLayoutMeasuring;
  });

#if YOGA_LAYOUT_LOGGING
  // Concurrent layouts will interleave the NSLog messages unless we serialize.
  // Use @synchornize rather than trampolining to the main thread so the tree state isn't changed.
  @synchronized ([ASDisplayNode class]) {
    NSLog(@"****************************************************************************");
    NSLog(@"******************** STARTING YOGA -> ASLAYOUT CREATION ********************");
    NSLog(@"****************************************************************************");
    ASDisplayNodePerformBlockOnEveryYogaChild(self, ^(ASDisplayNode * _Nonnull node) {
      NSLog(@" "); // Newline
      NSLog(@"node = %@", node);
      NSLog(@"style = %@", node.style);
      NSLog(@"layout = %@", node.yogaCalculatedLayout);
      YGNodePrint(node.yogaNode, (YGPrintOptions)(YGPrintOptionsStyle | YGPrintOptionsLayout));
    });
  }
#endif
}

@end

#endif /* YOGA */

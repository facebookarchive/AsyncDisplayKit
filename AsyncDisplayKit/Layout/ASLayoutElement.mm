//
//  ASLayoutElement.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/27/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDisplayNode+FrameworkPrivate.h"
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

#import <map>
#import <atomic>

extern void ASLayoutElementPerformBlockOnEveryElement(id<ASLayoutElement> element, void(^block)(id<ASLayoutElement> element))
{
  if (element) {
    block(element);
  }

  for (id<ASLayoutElement> subelement in element.sublayoutElements) {
    ASLayoutElementPerformBlockOnEveryElement(subelement, block);
  }
}

#pragma mark - ASLayoutElementContext

CGFloat const ASLayoutElementParentDimensionUndefined = NAN;
CGSize const ASLayoutElementParentSizeUndefined = {ASLayoutElementParentDimensionUndefined, ASLayoutElementParentDimensionUndefined};

int32_t const ASLayoutElementContextInvalidTransitionID = 0;
int32_t const ASLayoutElementContextDefaultTransitionID = ASLayoutElementContextInvalidTransitionID + 1;

static inline ASLayoutElementContext _ASLayoutElementContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  struct ASLayoutElementContext context;
  context.transitionID = transitionID;
  context.needsVisualizeNode = needsVisualizeNode;
  return context;
}

static inline BOOL _IsValidTransitionID(int32_t transitionID)
{
  return transitionID > ASLayoutElementContextInvalidTransitionID;
}

struct ASLayoutElementContext const ASLayoutElementContextNull = _ASLayoutElementContextMake(ASLayoutElementContextInvalidTransitionID, NO);

BOOL ASLayoutElementContextIsNull(struct ASLayoutElementContext context)
{
  return !_IsValidTransitionID(context.transitionID);
}

ASLayoutElementContext ASLayoutElementContextMake(int32_t transitionID, BOOL needsVisualizeNode)
{
  NSCAssert(_IsValidTransitionID(transitionID), @"Invalid transition ID");
  return _ASLayoutElementContextMake(transitionID, needsVisualizeNode);
}

// Note: This is a non-recursive static lock. If it needs to be recursive, use ASDISPLAYNODE_MUTEX_RECURSIVE_INITIALIZER
static ASDN::StaticMutex _layoutElementContextLock = ASDISPLAYNODE_MUTEX_INITIALIZER;
static std::map<mach_port_t, ASLayoutElementContext> layoutElementContextMap;

static inline mach_port_t ASLayoutElementGetCurrentContextKey()
{
  return pthread_mach_thread_np(pthread_self());
}

void ASLayoutElementSetCurrentContext(struct ASLayoutElementContext context)
{
  const mach_port_t key = ASLayoutElementGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutElementContextLock);
  layoutElementContextMap[key] = context;
}

struct ASLayoutElementContext ASLayoutElementGetCurrentContext()
{
  const mach_port_t key = ASLayoutElementGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutElementContextLock);
  const auto it = layoutElementContextMap.find(key);
  if (it != layoutElementContextMap.end()) {
    // Found an interator with above key. "it->first" is the key itself, "it->second" is the context value.
    return it->second;
  }
  return ASLayoutElementContextNull;
}

void ASLayoutElementClearCurrentContext()
{
  const mach_port_t key = ASLayoutElementGetCurrentContextKey();
  ASDN::StaticMutexLocker l(_layoutElementContextLock);
  layoutElementContextMap.erase(key);
}

#pragma mark - ASLayoutElementStyle

NSString * const ASLayoutElementStyleWidthProperty = @"ASLayoutElementStyleWidthProperty";
NSString * const ASLayoutElementStyleMinWidthProperty = @"ASLayoutElementStyleMinWidthProperty";
NSString * const ASLayoutElementStyleMaxWidthProperty = @"ASLayoutElementStyleMaxWidthProperty";

NSString * const ASLayoutElementStyleHeightProperty = @"ASLayoutElementStyleHeightProperty";
NSString * const ASLayoutElementStyleMinHeightProperty = @"ASLayoutElementStyleMinHeightProperty";
NSString * const ASLayoutElementStyleMaxHeightProperty = @"ASLayoutElementStyleMaxHeightProperty";

NSString * const ASLayoutElementStyleSpacingBeforeProperty = @"ASLayoutElementStyleSpacingBeforeProperty";
NSString * const ASLayoutElementStyleSpacingAfterProperty = @"ASLayoutElementStyleSpacingAfterProperty";
NSString * const ASLayoutElementStyleFlexGrowProperty = @"ASLayoutElementStyleFlexGrowProperty";
NSString * const ASLayoutElementStyleFlexShrinkProperty = @"ASLayoutElementStyleFlexShrinkProperty";
NSString * const ASLayoutElementStyleFlexBasisProperty = @"ASLayoutElementStyleFlexBasisProperty";
NSString * const ASLayoutElementStyleAlignSelfProperty = @"ASLayoutElementStyleAlignSelfProperty";
NSString * const ASLayoutElementStyleAscenderProperty = @"ASLayoutElementStyleAscenderProperty";
NSString * const ASLayoutElementStyleDescenderProperty = @"ASLayoutElementStyleDescenderProperty";

NSString * const ASLayoutElementStyleLayoutPositionProperty = @"ASLayoutElementStyleLayoutPositionProperty";

#define ASLayoutElementStyleCallDelegate(propertyName)\
do {\
  [_delegate style:self propertyDidChange:propertyName];\
} while(0)

@implementation ASLayoutElementStyle {
  ASDN::RecursiveMutex __instanceLock__;
  ASLayoutElementSize _size;
  ASLayoutElementStyleExtensions _extensions;
  
  std::atomic<CGFloat> _spacingBefore;
  std::atomic<CGFloat> _spacingAfter;
  std::atomic<CGFloat> _flexGrow;
  std::atomic<CGFloat> _flexShrink;
  std::atomic<ASDimension> _flexBasis;
  std::atomic<ASStackLayoutAlignSelf> _alignSelf;
  std::atomic<CGFloat> _ascender;
  std::atomic<CGFloat> _descender;
  std::atomic<CGPoint> _layoutPosition;

#if YOGA
  std::atomic<ASStackLayoutDirection> _direction;
  std::atomic<CGFloat> _spacing;
  std::atomic<ASStackLayoutJustifyContent> _justifyContent;
  std::atomic<ASStackLayoutAlignItems> _alignItems;
  std::atomic<YGPositionType> _positionType;
  std::atomic<ASEdgeInsets> _position;
  std::atomic<ASEdgeInsets> _margin;
  std::atomic<ASEdgeInsets> _padding;
  std::atomic<ASEdgeInsets> _border;

  std::atomic<CGFloat> _aspectRatio;
  std::atomic<YGWrap> _flexWrap;
#endif
}

@dynamic width, height, minWidth, maxWidth, minHeight, maxHeight;
@dynamic preferredSize, minSize, maxSize, preferredLayoutSize, minLayoutSize, maxLayoutSize;

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(id<ASLayoutElementStyleDelegate>)delegate
{
  self = [self init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _size = ASLayoutElementSizeMake();
  }
  return self;
}

#pragma mark - ASLayoutElementStyleSize

- (ASLayoutElementSize)size
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size;
}

- (void)setSize:(ASLayoutElementSize)size
{
  ASDN::MutexLocker l(__instanceLock__);
  _size = size;
}

#pragma mark - ASLayoutElementStyleSizeForwarding

- (ASDimension)width
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.width;
}

- (void)setWidth:(ASDimension)width
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.width = width;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
}

- (ASDimension)height
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.height;
}

- (void)setHeight:(ASDimension)height
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.height = height;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (ASDimension)minWidth
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.minWidth;
}

- (void)setMinWidth:(ASDimension)minWidth
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.minWidth = minWidth;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
}

- (ASDimension)maxWidth
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.maxWidth;
}

- (void)setMaxWidth:(ASDimension)maxWidth
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.maxWidth = maxWidth;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
}

- (ASDimension)minHeight
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.minHeight;
}

- (void)setMinHeight:(ASDimension)minHeight
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.minHeight = minHeight;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (ASDimension)maxHeight
{
  ASDN::MutexLocker l(__instanceLock__);
  return _size.maxHeight;
}

- (void)setMaxHeight:(ASDimension)maxHeight
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.maxHeight = maxHeight;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}


#pragma mark - ASLayoutElementStyleSizeHelpers

// We explicitly not call the setter for (max/min) width and height to avoid locking overhead

- (void)setPreferredSize:(CGSize)preferredSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.width = ASDimensionMakeWithPoints(preferredSize.width);
  _size.height = ASDimensionMakeWithPoints(preferredSize.height);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (CGSize)preferredSize
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_size.width.unit == ASDimensionUnitFraction) {
    NSCAssert(NO, @"Cannot get preferredSize of element with fractional width. Width: %@.", NSStringFromASDimension(_size.width));
    return CGSizeZero;
  }
  
  if (_size.height.unit == ASDimensionUnitFraction) {
    NSCAssert(NO, @"Cannot get preferredSize of element with fractional height. Height: %@.", NSStringFromASDimension(_size.height));
    return CGSizeZero;
  }
  
  return CGSizeMake(_size.width.value, _size.height.value);
}

- (void)setMinSize:(CGSize)minSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.minWidth = ASDimensionMakeWithPoints(minSize.width);
  _size.minHeight = ASDimensionMakeWithPoints(minSize.height);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (void)setMaxSize:(CGSize)maxSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.maxWidth = ASDimensionMakeWithPoints(maxSize.width);
  _size.maxHeight = ASDimensionMakeWithPoints(maxSize.height);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}

- (ASLayoutSize)preferredLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.width, _size.height);
}

- (void)setPreferredLayoutSize:(ASLayoutSize)preferredLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.width = preferredLayoutSize.width;
  _size.height = preferredLayoutSize.height;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleHeightProperty);
}

- (ASLayoutSize)minLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.minWidth, _size.minHeight);
}

- (void)setMinLayoutSize:(ASLayoutSize)minLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.minWidth = minLayoutSize.width;
  _size.minHeight = minLayoutSize.height;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMinHeightProperty);
}

- (ASLayoutSize)maxLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.maxWidth, _size.maxHeight);
}

- (void)setMaxLayoutSize:(ASLayoutSize)maxLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  _size.maxWidth = maxLayoutSize.width;
  _size.maxHeight = maxLayoutSize.height;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxWidthProperty);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleMaxHeightProperty);
}

#pragma mark - ASStackLayoutElement

- (void)setSpacingBefore:(CGFloat)spacingBefore
{
  _spacingBefore.store(spacingBefore);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingBeforeProperty);
}

- (CGFloat)spacingBefore
{
  return _spacingBefore.load();
}

- (void)setSpacingAfter:(CGFloat)spacingAfter
{
  _spacingAfter.store(spacingAfter);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingAfterProperty);
}

- (CGFloat)spacingAfter
{
  return _spacingAfter.load();
}

- (void)setFlexGrow:(CGFloat)flexGrow
{
  _flexGrow.store(flexGrow);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexGrowProperty);
}

- (CGFloat)flexGrow
{
  return _flexGrow.load();
}

- (void)setFlexShrink:(CGFloat)flexShrink
{
  _flexShrink.store(flexShrink);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexShrinkProperty);
}

- (CGFloat)flexShrink
{
  return _flexShrink.load();
}

- (void)setFlexBasis:(ASDimension)flexBasis
{
  _flexBasis.store(flexBasis);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexBasisProperty);
}

- (ASDimension)flexBasis
{
  return _flexBasis.load();
}

- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf
{
  _alignSelf.store(alignSelf);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAlignSelfProperty);
}

- (ASStackLayoutAlignSelf)alignSelf
{
  return _alignSelf.load();
}

- (void)setAscender:(CGFloat)ascender
{
  _ascender.store(ascender);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAscenderProperty);
}

- (CGFloat)ascender
{
  return _ascender.load();
}

- (void)setDescender:(CGFloat)descender
{
  _descender.store(descender);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleDescenderProperty);
}

- (CGFloat)descender
{
  return _descender.load();
}

#pragma mark - ASAbsoluteLayoutElement

- (void)setLayoutPosition:(CGPoint)layoutPosition
{
  _layoutPosition.store(layoutPosition);
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleLayoutPositionProperty);
}

- (CGPoint)layoutPosition
{
  return _layoutPosition.load();
}

#pragma mark - Yoga Flexbox Properties

#if YOGA

- (void)setDirection:(ASStackLayoutDirection)direction
{
  _direction.store(direction);
}

- (ASStackLayoutDirection)direction
{
  return _direction.load();
}

- (void)setSpacing:(CGFloat)spacing
{
  _spacing.store(spacing);
}

- (CGFloat)spacing
{
  return _spacing.load();
}

- (void)setJustifyContent:(ASStackLayoutJustifyContent)justifyContent
{
  _justifyContent.store(justifyContent);
}

- (ASStackLayoutJustifyContent)justifyContent
{
  return _justifyContent.load();
}

- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems
{
  _alignItems.store(alignItems);
}

- (ASStackLayoutAlignItems)alignItems
{
  return _alignItems.load();
}

- (YGPositionType)positionType
{
  return _positionType.load();
}

- (void)setPositionType:(YGPositionType)positionType
{
  _positionType.store(positionType);
}

- (ASEdgeInsets)position
{
  return _position.load();
}

- (void)setPosition:(ASEdgeInsets)position
{
  _position.store(position);
}

- (ASEdgeInsets)margin
{
  return _margin.load();
}

- (void)setMargin:(ASEdgeInsets)margin
{
  _margin.store(margin);
}

- (ASEdgeInsets)padding
{
  return _padding.load();
}

- (void)setPadding:(ASEdgeInsets)padding
{
  _padding.store(padding);
}

- (ASEdgeInsets)border
{
  return _border.load();
}

- (void)setBorder:(ASEdgeInsets)border
{
  _border.store(border);
}

- (CGFloat)aspectRatio
{
  return _aspectRatio.load();
}

- (void)setAspectRatio:(CGFloat)aspectRatio
{
  _aspectRatio.store(aspectRatio);
}

- (YGWrap)flexWrap
{
  return _flexWrap.load();
}

- (void)setFlexWrap:(YGWrap)flexWrap
{
  _flexWrap.store(flexWrap);
}

#endif

#pragma mark - Extensions

- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementBoolExtensions, @"Setting index outside of max bool extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  _extensions.boolExtensions[idx] = value;
}

- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx\
{
  NSCAssert(idx < kMaxLayoutElementBoolExtensions, @"Accessing index outside of max bool extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  return _extensions.boolExtensions[idx];
}

- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateIntegerExtensions, @"Setting index outside of max integer extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  _extensions.integerExtensions[idx] = value;
}

- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateIntegerExtensions, @"Accessing index outside of max integer extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  return _extensions.integerExtensions[idx];
}

- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateEdgeInsetExtensions, @"Setting index outside of max edge insets extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  _extensions.edgeInsetsExtensions[idx] = value;
}

- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx
{
  NSCAssert(idx < kMaxLayoutElementStateEdgeInsetExtensions, @"Accessing index outside of max edge insets extensions space");
  
  ASDN::MutexLocker l(__instanceLock__);
  return _extensions.edgeInsetsExtensions[idx];
}

#pragma mark - Debugging

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  
  if ((self.minLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.minLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"minLayoutSize" : NSStringFromASLayoutSize(self.minLayoutSize) }];
  }
  
  if ((self.preferredLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.preferredLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"preferredSize" : NSStringFromASLayoutSize(self.preferredLayoutSize) }];
  }
  
  if ((self.maxLayoutSize.width.unit != ASDimensionUnitAuto ||
    self.maxLayoutSize.height.unit != ASDimensionUnitAuto)) {
    [result addObject:@{ @"maxLayoutSize" : NSStringFromASLayoutSize(self.maxLayoutSize) }];
  }
  
  if (self.alignSelf != ASStackLayoutAlignSelfAuto) {
    [result addObject:@{ @"alignSelf" : [@[@"ASStackLayoutAlignSelfAuto",
                                          @"ASStackLayoutAlignSelfStart",
                                          @"ASStackLayoutAlignSelfEnd",
                                          @"ASStackLayoutAlignSelfCenter",
                                          @"ASStackLayoutAlignSelfStretch"] objectAtIndex:self.alignSelf] }];
  }
  
  if (self.ascender != 0) {
    [result addObject:@{ @"ascender" : @(self.ascender) }];
  }
  
  if (self.descender != 0) {
    [result addObject:@{ @"descender" : @(self.descender) }];
  }
  
  if (ASDimensionEqualToDimension(self.flexBasis, ASDimensionAuto) == NO) {
    [result addObject:@{ @"flexBasis" : NSStringFromASDimension(self.flexBasis) }];
  }
  
  if (self.flexGrow != 0) {
    [result addObject:@{ @"flexGrow" : @(self.flexGrow) }];
  }
  
  if (self.flexShrink != 0) {
    [result addObject:@{ @"flexShrink" : @(self.flexShrink) }];
  }
  
  if (self.spacingAfter != 0) {
    [result addObject:@{ @"spacingAfter" : @(self.spacingAfter) }];
  }
  
  if (self.spacingBefore != 0) {
    [result addObject:@{ @"spacingBefore" : @(self.spacingBefore) }];
  }
  
  if (CGPointEqualToPoint(self.layoutPosition, CGPointZero) == NO) {
    [result addObject:@{ @"layoutPosition" : [NSValue valueWithCGPoint:self.layoutPosition] }];
  }

  return result;
}

#pragma mark Deprecated

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (ASRelativeSizeRange)sizeRange
{
  return ASRelativeSizeRangeMake(self.minLayoutSize, self.maxLayoutSize);
}

- (void)setSizeRange:(ASRelativeSizeRange)sizeRange
{
  self.minLayoutSize = sizeRange.min;
  self.maxLayoutSize = sizeRange.max;
}

#pragma clang diagnostic pop

@end

#pragma mark - Yoga Type Conversion Helpers

#if YOGA

YGAlign yogaAlignItems(ASStackLayoutAlignItems alignItems)
{
  switch (alignItems) {
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

#endif

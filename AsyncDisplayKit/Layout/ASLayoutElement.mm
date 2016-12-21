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

#import <map>
#import <atomic>

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
  
  std::atomic<CGFloat> _spacingBefore;
  std::atomic<CGFloat> _spacingAfter;
  std::atomic<CGFloat> _flexGrow;
  std::atomic<CGFloat> _flexShrink;
  std::atomic<ASDimension> _flexBasis;
  std::atomic<ASStackLayoutAlignSelf> _alignSelf;
  std::atomic<CGFloat> _ascender;
  std::atomic<CGFloat> _descender;
  std::atomic<CGPoint> _layoutPosition;
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
  
  const ASEnvironmentLayoutOptionsState defaultState = ASEnvironmentLayoutOptionsStateMakeDefault();
  
  if (self.alignSelf != defaultState.alignSelf) {
    [result addObject:@{ @"alignSelf" : [@[@"ASStackLayoutAlignSelfAuto",
                                          @"ASStackLayoutAlignSelfStart",
                                          @"ASStackLayoutAlignSelfEnd",
                                          @"ASStackLayoutAlignSelfCenter",
                                          @"ASStackLayoutAlignSelfStretch"] objectAtIndex:self.alignSelf] }];
  }
  
  if (self.ascender != defaultState.ascender) {
    [result addObject:@{ @"ascender" : @(self.ascender) }];
  }
  
  if (self.descender != defaultState.descender) {
    [result addObject:@{ @"descender" : @(self.descender) }];
  }
  
  if (ASDimensionEqualToDimension(self.flexBasis, defaultState.flexBasis) == NO) {
    [result addObject:@{ @"flexBasis" : NSStringFromASDimension(self.flexBasis) }];
  }
  
  if (self.flexGrow != defaultState.flexGrow) {
    [result addObject:@{ @"flexGrow" : @(self.flexGrow) }];
  }
  
  if (self.flexShrink != defaultState.flexShrink) {
    [result addObject:@{ @"flexShrink" : @(self.flexShrink) }];
  }
  
  if (self.spacingAfter != defaultState.spacingAfter) {
    [result addObject:@{ @"spacingAfter" : @(self.spacingAfter) }];
  }
  
  if (self.spacingBefore != defaultState.spacingBefore) {
    [result addObject:@{ @"spacingBefore" : @(self.spacingBefore) }];
  }
  
  if (CGPointEqualToPoint(self.layoutPosition, defaultState.layoutPosition) == NO) {
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


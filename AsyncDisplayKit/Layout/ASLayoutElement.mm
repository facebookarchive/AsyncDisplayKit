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

#import "ASDisplayNodeInternal.h"

#import <map>

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

- (void)setPreferredSize:(CGSize)preferredSize
{
  self.width = ASDimensionMakeWithPoints(preferredSize.width);
  self.height = ASDimensionMakeWithPoints(preferredSize.height);
}

- (void)setMinSize:(CGSize)minSize
{
  self.minWidth = ASDimensionMakeWithPoints(minSize.width);
  self.minHeight = ASDimensionMakeWithPoints(minSize.height);
}

- (void)setMaxSize:(CGSize)maxSize
{
  self.maxWidth = ASDimensionMakeWithPoints(maxSize.width);
  self.maxHeight = ASDimensionMakeWithPoints(maxSize.height);
}

- (ASLayoutSize)preferredLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.width, _size.height);
}

- (void)setPreferredLayoutSize:(ASLayoutSize)preferredLayoutSize
{
  self.width = preferredLayoutSize.width;
  self.height = preferredLayoutSize.height;
}

- (ASLayoutSize)minLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.minWidth, _size.minHeight);
}

- (void)setMinLayoutSize:(ASLayoutSize)minLayoutSize
{
  self.minWidth = minLayoutSize.width;
  self.minHeight = minLayoutSize.height;
}

- (ASLayoutSize)maxLayoutSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASLayoutSizeMake(_size.maxWidth, _size.maxHeight);
}

- (void)setMaxLayoutSize:(ASLayoutSize)maxLayoutSize
{
  self.maxWidth = maxLayoutSize.width;
  self.maxHeight = maxLayoutSize.height;
}


#pragma mark - ASStackLayoutElement

- (void)setSpacingBefore:(CGFloat)spacingBefore
{
  ASDN::MutexLocker l(__instanceLock__);
  _spacingBefore = spacingBefore;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingBeforeProperty);
}

- (void)setSpacingAfter:(CGFloat)spacingAfter
{
  ASDN::MutexLocker l(__instanceLock__);
  _spacingAfter = spacingAfter;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleSpacingAfterProperty);
}

- (void)setFlexGrow:(CGFloat)flexGrow
{
  ASDN::MutexLocker l(__instanceLock__);
  _flexGrow = flexGrow;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexGrowProperty);
}

- (void)setFlexShrink:(CGFloat)flexShrink
{
  ASDN::MutexLocker l(__instanceLock__);
  _flexShrink = flexShrink;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexShrinkProperty);
}

- (void)setFlexBasis:(ASDimension)flexBasis
{
  ASDN::MutexLocker l(__instanceLock__);
  _flexBasis = flexBasis;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleFlexBasisProperty);
}

- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf
{
  ASDN::MutexLocker l(__instanceLock__);
  _alignSelf = alignSelf;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAlignSelfProperty);
}

- (void)setAscender:(CGFloat)ascender
{
  ASDN::MutexLocker l(__instanceLock__);
  _ascender = ascender;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleAscenderProperty);
}

- (void)setDescender:(CGFloat)descender
{
  ASDN::MutexLocker l(__instanceLock__);
  _descender = descender;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleDescenderProperty);
}

#pragma mark - ASAbsoluteLayoutElement

- (void)setLayoutPosition:(CGPoint)layoutPosition
{
  ASDN::MutexLocker l(__instanceLock__);
  _layoutPosition = layoutPosition;
  ASLayoutElementStyleCallDelegate(ASLayoutElementStyleLayoutPositionProperty);
}

@end


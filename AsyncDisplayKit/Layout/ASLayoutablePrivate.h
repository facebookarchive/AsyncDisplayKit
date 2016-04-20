/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <Foundation/Foundation.h>

@class ASLayoutSpec;
@protocol ASLayoutable;

struct ASLayoutableContext {
  int32_t transitionID;
  BOOL needsVisualizeNode;
};

extern int32_t const ASLayoutableContextInvalidTransitionID;

extern int32_t const ASLayoutableContextDefaultTransitionID;

extern struct ASLayoutableContext const ASLayoutableContextNull;

extern BOOL ASLayoutableContextIsNull(struct ASLayoutableContext context);

extern struct ASLayoutableContext ASLayoutableContextMake(int32_t transitionID, BOOL needsVisualizeNode);

extern void ASLayoutableSetCurrentContext(struct ASLayoutableContext context);

extern struct ASLayoutableContext ASLayoutableGetCurrentContext();

extern void ASLayoutableClearCurrentContext();

/**
 *  The base protocol for ASLayoutable. Generally the methods/properties in this class do not need to be
 *  called by the end user and are only called internally. However, there may be a case where the methods are useful.
 */
@protocol ASLayoutablePrivate <NSObject>

/**
 *  @abstract This method can be used to give the user a chance to wrap an ASLayoutable in an ASLayoutSpec 
 *  just before it is added to a parent ASLayoutSpec. For example, if you wanted an ASTextNode that was always 
 *  inside of an ASInsetLayoutSpec, you could subclass ASTextNode and implement finalLayoutable so that it wraps
 *  itself in an inset spec.
 *
 *  Note that any ASLayoutable other than self that is returned MUST set isFinalLayoutable to YES. Make sure
 *  to do this BEFORE adding a child to the ASLayoutable.
 *
 *  @return The layoutable that will be added to the parent layout spec. Defaults to self.
 */
- (id<ASLayoutable>)finalLayoutable;

/**
 *  A flag to indicate that this ASLayoutable was created in finalLayoutable. This MUST be set to YES
 *  before adding a child to this layoutable.
 */
@property (nonatomic, assign) BOOL isFinalLayoutable;

@end


#pragma mark - ASLayoutOptionsForwarding

/**
 *  Both an ASDisplayNode and an ASLayoutSpec conform to ASLayoutable. There are several properties
 *  in ASLayoutable that are used when a node or spec is used in a layout spec.
 *  These properties are provided for convenience, as they are forwards to the node or spec's
 *  properties. Instead of duplicating the property forwarding in both classes, we
 *  create a define that allows us to easily implement the forwards in one place.
 *
 *  If you create a custom layout spec, we recommend this stragety if you decide to extend
 *  ASDisplayNode and ASLayoutSpec to provide convenience properties for any options that your
 *  layoutSpec may require.
 */

#define ASEnvironmentLayoutOptionsForwarding \
- (void)propagateUpLayoutOptionsState\
{\
  if (!ASEnvironmentStatePropagationEnabled()) {\
    return;\
  }\
  id<ASEnvironment> parent = [self parent];\
  if ([parent supportsUpwardPropagation]) {\
    ASEnvironmentStatePropagateUp(parent, _environmentState.layoutOptionsState);\
  }\
}\
\
- (CGFloat)spacingAfter\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.spacingAfter;\
}\
\
- (void)setSpacingAfter:(CGFloat)spacingAfter\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.spacingAfter = spacingAfter;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (CGFloat)spacingBefore\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.spacingBefore;\
}\
\
- (void)setSpacingBefore:(CGFloat)spacingBefore\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.spacingBefore = spacingBefore;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (BOOL)flexGrow\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.flexGrow;\
}\
\
- (void)setFlexGrow:(BOOL)flexGrow\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.flexGrow = flexGrow;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (BOOL)flexShrink\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.flexShrink;\
}\
\
- (void)setFlexShrink:(BOOL)flexShrink\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.flexShrink = flexShrink;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (ASRelativeDimension)flexBasis\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.flexBasis;\
}\
\
- (void)setFlexBasis:(ASRelativeDimension)flexBasis\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.flexBasis = flexBasis;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (ASStackLayoutAlignSelf)alignSelf\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.alignSelf;\
}\
\
- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.alignSelf = alignSelf;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (CGFloat)ascender\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.ascender;\
}\
\
- (void)setAscender:(CGFloat)ascender\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.ascender = ascender;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (CGFloat)descender\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.descender;\
}\
\
- (void)setDescender:(CGFloat)descender\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.descender = descender;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (ASRelativeSizeRange)sizeRange\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.sizeRange;\
}\
\
- (void)setSizeRange:(ASRelativeSizeRange)sizeRange\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.sizeRange = sizeRange;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\
\
- (CGPoint)layoutPosition\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _environmentState.layoutOptionsState.layoutPosition;\
}\
\
- (void)setLayoutPosition:(CGPoint)layoutPosition\
{\
  _propertyLock.lock();\
  _environmentState.layoutOptionsState.layoutPosition = layoutPosition;\
  [self propagateUpLayoutOptionsState];\
  _propertyLock.unlock();\
}\


#pragma mark - ASLayoutableExtensibility

#define ASEnvironmentLayoutExtensibilityForwarding \
- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx\
{\
  _propertyLock.lock();\
  _ASEnvironmentLayoutOptionsExtensionSetBoolAtIndex(self, idx, value);\
  _propertyLock.unlock();\
}\
\
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _ASEnvironmentLayoutOptionsExtensionGetBoolAtIndex(self, idx);\
}\
\
- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx\
{\
  _propertyLock.lock();\
  _ASEnvironmentLayoutOptionsExtensionSetIntegerAtIndex(self, idx, value);\
  _propertyLock.unlock();\
}\
\
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _ASEnvironmentLayoutOptionsExtensionGetIntegerAtIndex(self, idx);\
}\
\
- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx\
{\
  _propertyLock.lock();\
  _ASEnvironmentLayoutOptionsExtensionSetEdgeInsetsAtIndex(self, idx, value);\
  _propertyLock.unlock();\
}\
\
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx\
{\
  ASDN::MutexLocker l(_propertyLock);\
  return _ASEnvironmentLayoutOptionsExtensionGetEdgeInsetsAtIndex(self, idx);\
}\

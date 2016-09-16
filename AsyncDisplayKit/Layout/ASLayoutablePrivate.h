//
//  ASLayoutablePrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDimension.h"

@protocol ASLayoutable;
@class ASLayoutableStyleDeclaration;

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

#pragma mark - ASLayoutableExtensibility

#define ASEnvironmentLayoutExtensibilityForwarding \
- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx\
{\
  _ASEnvironmentLayoutOptionsExtensionSetBoolAtIndex(self, idx, value);\
}\
\
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx\
{\
  return _ASEnvironmentLayoutOptionsExtensionGetBoolAtIndex(self, idx);\
}\
\
- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx\
{\
  _ASEnvironmentLayoutOptionsExtensionSetIntegerAtIndex(self, idx, value);\
}\
\
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx\
{\
  return _ASEnvironmentLayoutOptionsExtensionGetIntegerAtIndex(self, idx);\
}\
\
- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx\
{\
  _ASEnvironmentLayoutOptionsExtensionSetEdgeInsetsAtIndex(self, idx, value);\
}\
\
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx\
{\
  return _ASEnvironmentLayoutOptionsExtensionGetEdgeInsetsAtIndex(self, idx);\
}\

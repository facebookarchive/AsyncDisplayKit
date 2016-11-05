//
//  ASLayoutElementPrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDimension.h"

@protocol ASLayoutElement;
@class ASLayoutElementStyle;

struct ASLayoutElementContext {
  int32_t transitionID;
  BOOL needsVisualizeNode;
};

extern int32_t const ASLayoutElementContextInvalidTransitionID;

extern int32_t const ASLayoutElementContextDefaultTransitionID;

extern struct ASLayoutElementContext const ASLayoutElementContextNull;

extern BOOL ASLayoutElementContextIsNull(struct ASLayoutElementContext context);

extern struct ASLayoutElementContext ASLayoutElementContextMake(int32_t transitionID, BOOL needsVisualizeNode);

extern void ASLayoutElementSetCurrentContext(struct ASLayoutElementContext context);

extern struct ASLayoutElementContext ASLayoutElementGetCurrentContext();

extern void ASLayoutElementClearCurrentContext();

/**
 *  The base protocol for ASLayoutElement. Generally the methods/properties in this class do not need to be
 *  called by the end user and are only called internally. However, there may be a case where the methods are useful.
 */
@protocol ASLayoutElementPrivate <NSObject>

/**
 *  @abstract This method can be used to give the user a chance to wrap an ASLayoutElement in an ASLayoutSpec 
 *  just before it is added to a parent ASLayoutSpec. For example, if you wanted an ASTextNode that was always 
 *  inside of an ASInsetLayoutSpec, you could subclass ASTextNode and implement finalLayoutElement so that it wraps
 *  itself in an inset spec.
 *
 *  Note that any ASLayoutElement other than self that is returned MUST set isFinalLayoutElement to YES. Make sure
 *  to do this BEFORE adding a child to the ASLayoutElement.
 *
 *  @return The layoutElement that will be added to the parent layout spec. Defaults to self.
 */
- (id<ASLayoutElement>)finalLayoutElement;

/**
 *  A flag to indicate that this ASLayoutElement was created in finalLayoutElement. This MUST be set to YES
 *  before adding a child to this layoutElement.
 */
@property (nonatomic, assign) BOOL isFinalLayoutElement;

@end

#pragma mark - ASLayoutElementExtensibility

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


#pragma mark ASLayoutElementStyleForwardingDeclaration (Deprecated)

#define ASLayoutElementStyleForwardingDeclaration \
@property (nonatomic, readwrite) CGFloat spacingBefore ASDISPLAYNODE_DEPRECATED_MSG("Use style.spacingBefore"); \
@property (nonatomic, readwrite) CGFloat spacingAfter ASDISPLAYNODE_DEPRECATED_MSG("Use style.spacingAfter"); \
@property (nonatomic, readwrite) CGFloat flexGrow ASDISPLAYNODE_DEPRECATED_MSG("Use style.flexGrow"); \
@property (nonatomic, readwrite) CGFloat flexShrink ASDISPLAYNODE_DEPRECATED_MSG("Use style.flexShrink"); \
@property (nonatomic, readwrite) ASDimension flexBasis ASDISPLAYNODE_DEPRECATED_MSG("Use style.flexBasis"); \
@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf ASDISPLAYNODE_DEPRECATED_MSG("Use style.alignSelf"); \
@property (nonatomic, readwrite) CGFloat ascender ASDISPLAYNODE_DEPRECATED_MSG("Use style.ascender"); \
@property (nonatomic, readwrite) CGFloat descender ASDISPLAYNODE_DEPRECATED_MSG("Use style.descender"); \
@property (nonatomic, assign) ASRelativeSizeRange sizeRange ASDISPLAYNODE_DEPRECATED_MSG("Don't use sizeRange anymore instead set style.width or style.height"); \
@property (nonatomic, assign) CGPoint layoutPosition ASDISPLAYNODE_DEPRECATED_MSG("Use style.layoutPosition"); \


#pragma mark - ASLayoutElementStyleForwarding (Deprecated)

// For the time beeing we are forwading all style related properties on ASDisplayNode and ASLayoutSpec. This define
// help us to not have duplicate code while moving from 1.x to 2.0s
#define ASLayoutElementStyleForwarding \
\
@dynamic spacingBefore, spacingAfter, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender, sizeRange, layoutPosition;\
\
_Pragma("mark - ASStackLayoutElement")\
\
- (void)setSpacingBefore:(CGFloat)spacingBefore\
{\
  self.style.spacingBefore = spacingBefore;\
}\
\
- (CGFloat)spacingBefore\
{\
  return self.style.spacingBefore;\
}\
\
- (void)setSpacingAfter:(CGFloat)spacingAfter\
{\
  self.style.spacingAfter = spacingAfter;\
}\
\
- (CGFloat)spacingAfter\
{\
  return self.style.spacingAfter;\
}\
\
- (void)setFlexGrow:(CGFloat)flexGrow\
{\
  self.style.flexGrow = flexGrow;\
}\
\
- (CGFloat)flexGrow\
{\
  return self.style.flexGrow;\
}\
\
- (void)setFlexShrink:(CGFloat)flexShrink\
{\
  self.style.flexShrink = flexShrink;\
}\
\
- (CGFloat)flexShrink\
{\
  return self.style.flexShrink;\
}\
\
- (void)setFlexBasis:(ASDimension)flexBasis\
{\
  self.style.flexBasis = flexBasis;\
}\
\
- (ASDimension)flexBasis\
{\
  return self.style.flexBasis;\
}\
\
- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf\
{\
  self.style.alignSelf = alignSelf;\
}\
\
- (ASStackLayoutAlignSelf)alignSelf\
{\
  return self.style.alignSelf;\
}\
\
- (void)setAscender:(CGFloat)ascender\
{\
  self.style.ascender = ascender;\
}\
\
- (CGFloat)ascender\
{\
  return self.style.ascender;\
}\
\
- (void)setDescender:(CGFloat)descender\
{\
  self.style.descender = descender;\
}\
\
- (CGFloat)descender\
{\
  return self.style.descender;\
}\
\
_Pragma("mark - ASAbsoluteLayoutElement")\
\
- (void)setLayoutPosition:(CGPoint)layoutPosition\
{\
  self.style.layoutPosition = layoutPosition;\
}\
\
- (CGPoint)layoutPosition\
{\
  return self.style.layoutPosition;\
}\
\
_Pragma("clang diagnostic push")\
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")\
\
- (void)setSizeRange:(ASRelativeSizeRange)sizeRange\
{\
  self.style.sizeRange = sizeRange;\
}\
\
- (ASRelativeSizeRange)sizeRange\
{\
  return self.style.sizeRange;\
}\
\
_Pragma("clang diagnostic pop")\

//
//  ASLayoutablePrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import "ASDimension.h"

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
 * @abstract A size constraint that should apply to this ASLayoutable.
 */
@property (nonatomic, assign, readwrite) ASSize size;

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

#pragma mark - ASLayoutableForwarding
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

#pragma mark - ASLayoutableSizeForwarding

#define ASLayoutableSizeForwarding \
\
- (ASRelativeDimension)width\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.width;\
}\
\
- (void)setWidth:(ASRelativeDimension)width\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.width = width;\
}\
\
- (ASRelativeDimension)height\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.height;\
}\
\
- (void)setHeight:(ASRelativeDimension)height\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.height = height;\
}\
\
- (ASRelativeDimension)minWidth\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.minWidth;\
}\
\
- (void)setMinWidth:(ASRelativeDimension)minWidth\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minWidth = minWidth;\
}\
\
- (ASRelativeDimension)maxWidth\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.maxWidth;\
}\
\
- (void)setMaxWidth:(ASRelativeDimension)maxWidth\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxWidth = maxWidth;\
}\
\
- (ASRelativeDimension)minHeight\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.minHeight;\
}\
\
- (void)setMinHeight:(ASRelativeDimension)minHeight\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minHeight = minHeight;\
}\
\
- (ASRelativeDimension)maxHeight\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  return _size.maxHeight;\
}\
\
- (void)setMaxHeight:(ASRelativeDimension)maxHeight\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxHeight = maxHeight;\
}\


#pragma mark - ASLayoutableSizeHelperForwarding

#define ASLayoutableSizeHelperForwarding \
- (void)setWidthAsPoints:(CGFloat)widthAsPoints\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.width = {ASRelativeDimensionTypePoints, widthAsPoints};\
}\
\
- (void)setWidthAsFraction:(CGFloat)widthAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.width = {ASRelativeDimensionTypeFraction, widthAsFraction};\
}\
\
- (void)setMinWidthAsPoints:(CGFloat)minWidthAsPoints\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minWidth = {ASRelativeDimensionTypePoints, minWidthAsPoints};\
}\
\
- (void)setMinWidthAsFraction:(CGFloat)minWidthAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minWidth = {ASRelativeDimensionTypeFraction, minWidthAsFraction};\
}\
\
- (void)setMaxWidthAsPoints:(CGFloat)maxWidthAsPoints\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxWidth = {ASRelativeDimensionTypePoints, maxWidthAsPoints};\
}\
\
- (void)setMaxWidthAsFraction:(CGFloat)maxWidthAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxWidth = {ASRelativeDimensionTypeFraction, maxWidthAsFraction};\
}\
\
- (void)setHeightAsPoints:(CGFloat)points\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.height = {ASRelativeDimensionTypePoints, points};\
}\
\
- (void)setHeightAsFraction:(CGFloat)heightAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.height = {ASRelativeDimensionTypeFraction, heightAsFraction};\
}\
\
- (void)setMinHeightAsPoints:(CGFloat)minHeightAsPoints\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minHeight = {ASRelativeDimensionTypePoints, minHeightAsPoints};\
}\
\
- (void)setMinHeightAsFraction:(CGFloat)minHeightAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.minHeight = {ASRelativeDimensionTypeFraction, minHeightAsFraction};\
}\
\
- (void)setMaxHeightAsPoints:(CGFloat)maxHeightAsPoints\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxHeight = {ASRelativeDimensionTypePoints, maxHeightAsPoints};\
}\
\
- (void)setMaxHeightAsFraction:(CGFloat)maxHeightAsFraction\
{\
  ASDN::MutexLocker l(__instanceLock__);\
  _size.maxHeight = {ASRelativeDimensionTypeFraction, maxHeightAsFraction};\
}\
\
- (void)setSizeFromCGSize:(CGSize)size\
{\
  self.width = ASRelativeDimensionMakeWithPoints(size.width);\
  self.height = ASRelativeDimensionMakeWithPoints(size.height);\
}\
\
- (void)setExactSizeFromCGSize:(CGSize)size\
{\
  self.minWidth = ASRelativeDimensionMakeWithPoints(size.width);\
  self.minHeight = ASRelativeDimensionMakeWithPoints(size.height);\
  self.maxWidth = ASRelativeDimensionMakeWithPoints(size.width);\
  self.maxHeight = ASRelativeDimensionMakeWithPoints(size.height);\
}\


#pragma mark - ASLayoutOptionsForwarding

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
  return _environmentState.layoutOptionsState.spacingAfter;\
}\
\
- (void)setSpacingAfter:(CGFloat)spacingAfter\
{\
  _environmentState.layoutOptionsState.spacingAfter = spacingAfter;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)spacingBefore\
{\
  return _environmentState.layoutOptionsState.spacingBefore;\
}\
\
- (void)setSpacingBefore:(CGFloat)spacingBefore\
{\
  _environmentState.layoutOptionsState.spacingBefore = spacingBefore;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (BOOL)flexGrow\
{\
  return _environmentState.layoutOptionsState.flexGrow;\
}\
\
- (void)setFlexGrow:(BOOL)flexGrow\
{\
  _environmentState.layoutOptionsState.flexGrow = flexGrow;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (BOOL)flexShrink\
{\
  return _environmentState.layoutOptionsState.flexShrink;\
}\
\
- (void)setFlexShrink:(BOOL)flexShrink\
{\
  _environmentState.layoutOptionsState.flexShrink = flexShrink;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (ASRelativeDimension)flexBasis\
{\
  return _environmentState.layoutOptionsState.flexBasis;\
}\
\
- (void)setFlexBasis:(ASRelativeDimension)flexBasis\
{\
  _environmentState.layoutOptionsState.flexBasis = flexBasis;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (ASStackLayoutAlignSelf)alignSelf\
{\
  return _environmentState.layoutOptionsState.alignSelf;\
}\
\
- (void)setAlignSelf:(ASStackLayoutAlignSelf)alignSelf\
{\
  _environmentState.layoutOptionsState.alignSelf = alignSelf;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)ascender\
{\
  return _environmentState.layoutOptionsState.ascender;\
}\
\
- (void)setAscender:(CGFloat)ascender\
{\
  _environmentState.layoutOptionsState.ascender = ascender;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGFloat)descender\
{\
  return _environmentState.layoutOptionsState.descender;\
}\
\
- (void)setDescender:(CGFloat)descender\
{\
  _environmentState.layoutOptionsState.descender = descender;\
  [self propagateUpLayoutOptionsState];\
}\
\
- (CGPoint)layoutPosition\
{\
  return _environmentState.layoutOptionsState.layoutPosition;\
}\
\
- (void)setLayoutPosition:(CGPoint)layoutPosition\
{\
  _environmentState.layoutOptionsState.layoutPosition = layoutPosition;\
  [self propagateUpLayoutOptionsState];\
}\


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

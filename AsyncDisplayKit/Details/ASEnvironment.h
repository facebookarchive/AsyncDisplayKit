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

#import "ASDimension.h"
#import "ASStackLayoutDefines.h"
#import "ASRelativeSize.h"


ASDISPLAYNODE_EXTERN_C_BEGIN
NS_ASSUME_NONNULL_BEGIN

static const int kMaxEnvironmentStateBoolExtensions = 1;
static const int kMaxEnvironmentStateIntegerExtensions = 4;
static const int kMaxEnvironmentStateEdgeInsetExtensions = 1;

#pragma mark -

typedef struct ASEnvironmentStateExtensions {
  // Values to store extensions
  BOOL boolExtensions[kMaxEnvironmentStateBoolExtensions];
  NSInteger integerExtensions[kMaxEnvironmentStateIntegerExtensions];
  UIEdgeInsets edgeInsetsExtensions[kMaxEnvironmentStateEdgeInsetExtensions];
} ASEnvironmentStateExtensions;

#pragma mark - ASEnvironmentLayoutOptionsState

typedef struct ASEnvironmentLayoutOptionsState {
  CGFloat spacingBefore;// = 0;
  CGFloat spacingAfter;// = 0;
  BOOL flexGrow;// = NO;
  BOOL flexShrink;// = NO;
  ASRelativeDimension flexBasis;// = ASRelativeDimensionUnconstrained;
  ASStackLayoutAlignSelf alignSelf;// = ASStackLayoutAlignSelfAuto;
  CGFloat ascender;// = 0;
  CGFloat descender;// = 0;
  
  ASRelativeSizeRange sizeRange;// = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero));;
  CGPoint layoutPosition;// = CGPointZero;
  
  ASEnvironmentStateExtensions _extensions;
} ASEnvironmentLayoutOptionsState;
extern ASEnvironmentLayoutOptionsState ASEnvironmentLayoutOptionsStateCreate();


#pragma mark - ASEnvironmentHierarchyState

typedef struct ASEnvironmentHierarchyState {
  unsigned rasterized:1; // = NO
  unsigned rangeManaged:1; // = NO
  unsigned transitioningSupernodes:1; // = NO
  unsigned layoutPending:1; // = NO
} ASEnvironmentHierarchyState;
extern ASEnvironmentHierarchyState ASEnvironmentHierarchyStateCreate();


#pragma mark - ASEnvironmentCollection

typedef struct ASEnvironmentCollection {
  struct ASEnvironmentHierarchyState hierarchyState;
  struct ASEnvironmentLayoutOptionsState layoutOptionsState;
} ASEnvironmentCollection;
extern ASEnvironmentCollection ASEnvironmentCollectionCreate();

ASDISPLAYNODE_EXTERN_C_END


#pragma mark - ASEnvironment

/**
 * ASEnvironment allows objects that conform to the ASEnvironment protocol to be able to propagate specific States
 * defined in an ASEnvironmentCollection up and down the ASEnvironment tree. To be able to define how merges of
 * States should happen, specific merge functions can be provided
 */
@protocol ASEnvironment <NSObject>

/// The environment collection of an object which class conforms to the ASEnvironment protocol
- (ASEnvironmentCollection *)environmentCollection;

/// Returns the parent of an object which class conforms to the ASEnvironment protocol
- (id<ASEnvironment>)parent;

/// Set the parent of an object which class conforms to the ASEnvironment protocol
- (void)setParent:(id<ASEnvironment>)parent;

/// Returns all children of an object which class conforms to the ASEnvironment protocol
- (NSArray<id<ASEnvironment>> *)children;

// TODO: ASEnvironment: Find a better name. As in ASDisplayNode this returns NO which in theory is wrong as as
//                      it supports multiple subnodes
- (BOOL)supportsMultipleChildren;

@end

NS_ASSUME_NONNULL_END
//
//  ASEnvironmentInternal.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASEnvironmentInternal.h"

#import <queue>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

#define AS_SUPPORT_PROPAGATION YES
#define AS_DOES_NOT_SUPPORT_PROPAGATION NO

BOOL ASEnvironmentStatePropagationEnabled()
{
  return AS_DOES_NOT_SUPPORT_PROPAGATION;
}

BOOL ASEnvironmentStateTraitCollectionPropagationEnabled()
{
  return AS_SUPPORT_PROPAGATION;
}

#pragma mark - Traversing an ASEnvironment Tree

void ASEnvironmentPerformBlockOnObjectAndChildren(id<ASEnvironment> object, void(^block)(id<ASEnvironment> node))
{
  if (!object) {
    return;
  }
  
  std::queue<id<ASEnvironment>> queue;
  queue.push(object);
  
  while (!queue.empty()) {
    id<ASEnvironment> object = queue.front(); queue.pop();
    
    block(object);
    
    for (id<ASEnvironment> child in [object children]) {
      queue.push(child);
    }
  }
}

void ASEnvironmentPerformBlockOnObjectAndParents(id<ASEnvironment> object, void(^block)(id<ASEnvironment> node))
{
  while (object) {
    block(object);
    object = [object parent];
  }
}


#pragma mark - Set and get extensible values from state structs

void _ASEnvironmentLayoutOptionsExtensionSetBoolAtIndex(id<ASEnvironment> object, int idx, BOOL value)
{
  NSCAssert(idx < kMaxEnvironmentStateBoolExtensions, @"Setting index outside of max bool extensions space");
  
  ASEnvironmentState state = object.environmentState;
  state.layoutOptionsState._extensions.boolExtensions[idx] = value;
  object.environmentState = state;
}

BOOL _ASEnvironmentLayoutOptionsExtensionGetBoolAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateBoolExtensions, @"Accessing index outside of max bool extensions space");
  return object.environmentState.layoutOptionsState._extensions.boolExtensions[idx];
}

void _ASEnvironmentLayoutOptionsExtensionSetIntegerAtIndex(id<ASEnvironment> object, int idx, NSInteger value)
{
  NSCAssert(idx < kMaxEnvironmentStateIntegerExtensions, @"Setting index outside of max integer extensions space");
  
  ASEnvironmentState state = object.environmentState;
  state.layoutOptionsState._extensions.integerExtensions[idx] = value;
  object.environmentState = state;
}

NSInteger _ASEnvironmentLayoutOptionsExtensionGetIntegerAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateIntegerExtensions, @"Accessing index outside of max integer extensions space");
  return object.environmentState.layoutOptionsState._extensions.integerExtensions[idx];
}

void _ASEnvironmentLayoutOptionsExtensionSetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx, UIEdgeInsets value)
{
  NSCAssert(idx < kMaxEnvironmentStateEdgeInsetExtensions, @"Setting index outside of max edge insets extensions space");
  
  ASEnvironmentState state = object.environmentState;
  state.layoutOptionsState._extensions.edgeInsetsExtensions[idx] = value;
  object.environmentState = state;
}

UIEdgeInsets _ASEnvironmentLayoutOptionsExtensionGetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateEdgeInsetExtensions, @"Accessing index outside of max edge insets extensions space");
  return object.environmentState.layoutOptionsState._extensions.edgeInsetsExtensions[idx];
}


#pragma mark - Merging functions for states

ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentHierarchyState hierarchyState, ASEnvironmentStatePropagation propagation) {
    // Merge object and hierarchy state
  LOG(@"Merge object and state: %@ - ASEnvironmentHierarchyState", hierarchyState);
  return environmentState;
}

ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentLayoutOptionsState layoutOptionsState, ASEnvironmentStatePropagation propagation) {
  // Merge object and layout options state
  LOG(@"Merge object and state: %@ - ASEnvironmentLayoutOptionsState", layoutOptionsState);
  
  if (!ASEnvironmentStatePropagationEnabled() && propagation == ASEnvironmentStatePropagation::UP) {
    return environmentState;
  }
  
  // Support propagate up
  if (propagation == ASEnvironmentStatePropagation::UP) {

   // Object is the parent and the state is the state of the child
    const ASEnvironmentLayoutOptionsState defaultState = ASEnvironmentDefaultLayoutOptionsState;
    ASEnvironmentLayoutOptionsState parentLayoutOptionsState = environmentState.layoutOptionsState;
    
    // For every field check if the parent value is equal to the default and if so propegate up the value of the passed
    // in layout options state
    if (parentLayoutOptionsState.spacingBefore == defaultState.spacingBefore) {
      parentLayoutOptionsState.spacingBefore = layoutOptionsState.spacingBefore;
    }
    if (parentLayoutOptionsState.spacingAfter == defaultState.spacingAfter) {
      parentLayoutOptionsState.spacingAfter = layoutOptionsState.spacingAfter;
    }
    if (parentLayoutOptionsState.alignSelf == defaultState.alignSelf) {
      parentLayoutOptionsState.alignSelf = layoutOptionsState.alignSelf;
    }
    if (parentLayoutOptionsState.flexGrow == defaultState.flexGrow) {
      parentLayoutOptionsState.flexGrow = layoutOptionsState.flexGrow;
    }
    if (ASRelativeDimensionEqualToRelativeDimension(parentLayoutOptionsState.flexBasis, defaultState.flexBasis)) {
      parentLayoutOptionsState.flexBasis = layoutOptionsState.flexBasis;
    }
    if (parentLayoutOptionsState.alignSelf == defaultState.alignSelf) {
      parentLayoutOptionsState.alignSelf = layoutOptionsState.alignSelf;
    }
    if (parentLayoutOptionsState.ascender == defaultState.ascender) {
      parentLayoutOptionsState.ascender = layoutOptionsState.ascender;
    }
    
    if (ASRelativeSizeRangeEqualToRelativeSizeRange(parentLayoutOptionsState.sizeRange, defaultState.sizeRange)) {
      // For now it is unclear if we should be up-propagating sizeRange or layoutPosition.
      // parentLayoutOptionsState.sizeRange = layoutOptionsState.sizeRange;
    }
    if (CGPointEqualToPoint(parentLayoutOptionsState.layoutPosition, defaultState.layoutPosition)) {
      // For now it is unclear if we should be up-propagating sizeRange or layoutPosition.
      // parentLayoutOptionsState.layoutPosition = layoutOptionsState.layoutPosition;
    }
    
    // Merge extended values if necessary
    const ASEnvironmentStateExtensions defaultExtensions = ASEnvironmentDefaultStateExtensions;
    const ASEnvironmentStateExtensions layoutOptionsStateExtensions = layoutOptionsState._extensions;
    ASEnvironmentStateExtensions parentLayoutOptionsExtensions = parentLayoutOptionsState._extensions;
    
    for (int i = 0; i < kMaxEnvironmentStateBoolExtensions; i++) {
      if (parentLayoutOptionsExtensions.boolExtensions[i] == defaultExtensions.boolExtensions[i]) {
        parentLayoutOptionsExtensions.boolExtensions[i] = layoutOptionsStateExtensions.boolExtensions[i];
      }
    }
    
    for (int i = 0; i < kMaxEnvironmentStateIntegerExtensions; i++) {
      if (parentLayoutOptionsExtensions.integerExtensions[i] == defaultExtensions.integerExtensions[i]) {
        parentLayoutOptionsExtensions.integerExtensions[i] = layoutOptionsStateExtensions.integerExtensions[i];
      }
    }
    
    for (int i = 0; i < kMaxEnvironmentStateEdgeInsetExtensions; i++) {
      if (UIEdgeInsetsEqualToEdgeInsets(parentLayoutOptionsExtensions.edgeInsetsExtensions[i], defaultExtensions.edgeInsetsExtensions[i])) {
        parentLayoutOptionsExtensions.edgeInsetsExtensions[i] = layoutOptionsStateExtensions.edgeInsetsExtensions[i];
      }
    }
    parentLayoutOptionsState._extensions = parentLayoutOptionsExtensions;
    
    // Update layout options state
    environmentState.layoutOptionsState = parentLayoutOptionsState;
  }
  
  return environmentState;
}

ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState childEnvironmentState, ASEnvironmentTraitCollection parentTraitCollection, ASEnvironmentStatePropagation propagation) {
  if (propagation == ASEnvironmentStatePropagation::DOWN && !ASEnvironmentStateTraitCollectionPropagationEnabled()) {
    return childEnvironmentState;
  }
  
  // Support propagate down
  if (propagation == ASEnvironmentStatePropagation::DOWN) {
    ASEnvironmentTraitCollection childTraitCollection = childEnvironmentState.environmentTraitCollection;
    childTraitCollection.horizontalSizeClass = parentTraitCollection.horizontalSizeClass;
    childTraitCollection.verticalSizeClass = parentTraitCollection.verticalSizeClass;
    childTraitCollection.userInterfaceIdiom = parentTraitCollection.userInterfaceIdiom;
    childTraitCollection.forceTouchCapability = parentTraitCollection.forceTouchCapability;
    childTraitCollection.displayScale = parentTraitCollection.displayScale;
    childTraitCollection.containerSize = parentTraitCollection.containerSize;
    childEnvironmentState.environmentTraitCollection = childTraitCollection;

  }
  return childEnvironmentState;
}

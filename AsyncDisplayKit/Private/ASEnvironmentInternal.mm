/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASEnvironmentInternal.h"

#import <queue>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

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
  
  ASEnvironmentStateExtensions extension = object.environmentState.layoutOptionsState._extensions;
  extension.boolExtensions[idx] = value;
  object.environmentState.layoutOptionsState._extensions = extension;
}

BOOL _ASEnvironmentLayoutOptionsExtensionGetBoolAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateBoolExtensions, @"Accessing index outside of max bool extensions space");
  return object.environmentState.layoutOptionsState._extensions.boolExtensions[idx];
}

void _ASEnvironmentLayoutOptionsExtensionSetIntegerAtIndex(id<ASEnvironment> object, int idx, NSInteger value)
{
  NSCAssert(idx < kMaxEnvironmentStateIntegerExtensions, @"Setting index outside of max integer extensions space");
  
  ASEnvironmentStateExtensions extension = object.environmentState.layoutOptionsState._extensions;
  extension.integerExtensions[idx] = value;
  object.environmentState.layoutOptionsState._extensions = extension;
}

NSInteger _ASEnvironmentLayoutOptionsExtensionGetIntegerAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateIntegerExtensions, @"Accessing index outside of max integer extensions space");
  return object.environmentState.layoutOptionsState._extensions.integerExtensions[idx];
}

void _ASEnvironmentLayoutOptionsExtensionSetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx, UIEdgeInsets value)
{
  NSCAssert(idx < kMaxEnvironmentStateEdgeInsetExtensions, @"Setting index outside of max edge insets extensions space");
  
  ASEnvironmentStateExtensions extension = object.environmentState.layoutOptionsState._extensions;
  extension.edgeInsetsExtensions[idx] = value;
  object.environmentState.layoutOptionsState._extensions = extension;
}

UIEdgeInsets _ASEnvironmentLayoutOptionsExtensionGetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx)
{
  NSCAssert(idx < kMaxEnvironmentStateEdgeInsetExtensions, @"Accessing index outside of max edge insets extensions space");
  return object.environmentState.layoutOptionsState._extensions.edgeInsetsExtensions[idx];
}


#pragma mark - Merging functions for states

ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentHierarchyState state, ASEnvironmentStatePropagation propagation) {
    // Merge object and hierarchy state
  LOG(@"Merge object and state: %@ - ASEnvironmentHierarchyState", object);
  return environmentState;
}

ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentLayoutOptionsState state, ASEnvironmentStatePropagation propagation) {
  // Merge object and layout options state
  LOG(@"Merge object and state: %@ - ASEnvironmentLayoutOptionsState", object);
  
  // Support propagate up
  if (propagation == ASEnvironmentStatePropagation::UP) {

   // Object is the parent and the state is the state of the child
    const ASEnvironmentLayoutOptionsState defaultState = ASEnvironmentDefaultLayoutOptionsState;
    ASEnvironmentLayoutOptionsState parentState = environmentState.layoutOptionsState;
    
    // For every field check if the parent value is equal to the default than propegate up the child value to
    // the parent
    if (parentState.spacingBefore != defaultState.spacingBefore) {
      parentState.spacingBefore = state.spacingBefore;
    }
    if (parentState.spacingAfter != defaultState.spacingAfter) {
      parentState.spacingAfter = state.spacingAfter;
    }
    if (parentState.alignSelf != defaultState.alignSelf) {
      parentState.alignSelf = defaultState.alignSelf;
    }
    if (parentState.flexGrow != defaultState.flexGrow) {
      parentState.flexGrow = defaultState.flexGrow;
    }
    if (!ASRelativeDimensionEqualToRelativeDimension(parentState.flexBasis, defaultState.flexBasis)) {
      parentState.flexBasis = defaultState.flexBasis;
    }
    if (parentState.alignSelf != defaultState.alignSelf) {
      parentState.alignSelf = defaultState.alignSelf;
    }
    if (parentState.ascender != defaultState.ascender) {
      parentState.ascender = defaultState.ascender;
    }
    
    if (!ASRelativeSizeRangeEqualToRelativeSizeRange(parentState.sizeRange, defaultState.sizeRange)) {
      parentState.sizeRange = defaultState.sizeRange;
    }
    if (CGPointEqualToPoint(parentState.layoutPosition, defaultState.layoutPosition)) {
      parentState.layoutPosition = defaultState.layoutPosition;
    }
    
    environmentState.layoutOptionsState = parentState;
  }
  
  return environmentState;
}

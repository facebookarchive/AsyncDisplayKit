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


#pragma mark - Merging functions for states

void ASEnvironmentMergeObjectAndState(id<ASEnvironment> object, ASEnvironmentHierarchyState& state, ASEnvironmentStatePropagation propagation) {
    // Merge object and hierarchy state
  LOG(@"Merge object and state: %@ - ASEnvironmentHierarchyState", object);
}

void ASEnvironmentMergeObjectAndState(id<ASEnvironment> object, ASEnvironmentLayoutOptionsState& state, ASEnvironmentStatePropagation propagation) {
  // Merge object and layout options state
  LOG(@"Merge object and state: %@ - ASEnvironmentLayoutOptionsState", object);
  
  // Support propagate up
  if (propagation == UP) {

   // Object is the parent and the state is the state of the child
    const ASEnvironmentLayoutOptionsState defaultState = ASEnvironmentDefaultLayoutOptionsState;
    ASEnvironmentLayoutOptionsState parentState = object.environmentCollection->layoutOptionsState;
    
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
    
    object.environmentCollection->layoutOptionsState = parentState;
  }
  
}

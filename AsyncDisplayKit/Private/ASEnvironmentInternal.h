//
//  ASEnvironmentInternal.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASEnvironment.h>

#pragma once

BOOL ASEnvironmentStatePropagationEnabled();
BOOL ASEnvironmentStateTraitCollectionPropagationEnabled();


#pragma mark - Set and get extensible values for layout options

void _ASEnvironmentLayoutOptionsExtensionSetBoolAtIndex(id<ASEnvironment> object, int idx, BOOL value);
BOOL _ASEnvironmentLayoutOptionsExtensionGetBoolAtIndex(id<ASEnvironment> object, int idx);

void _ASEnvironmentLayoutOptionsExtensionSetIntegerAtIndex(id<ASEnvironment> object, int idx, NSInteger value);
NSInteger _ASEnvironmentLayoutOptionsExtensionGetIntegerAtIndex(id<ASEnvironment> object, int idx);

void _ASEnvironmentLayoutOptionsExtensionSetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx, UIEdgeInsets value);
UIEdgeInsets _ASEnvironmentLayoutOptionsExtensionGetEdgeInsetsAtIndex(id<ASEnvironment> object, int idx);


#pragma mark - Traversing an ASEnvironment Tree

void ASEnvironmentPerformBlockOnObjectAndChildren(id<ASEnvironment> object, void(^block)(id<ASEnvironment> object));
void ASEnvironmentPerformBlockOnObjectAndParents(id<ASEnvironment> object, void(^block)(id<ASEnvironment> object));


#pragma mark - 

enum class ASEnvironmentStatePropagation { DOWN, UP };


#pragma mark - Merging

static const struct ASEnvironmentStateExtensions ASEnvironmentDefaultStateExtensions = {};

static const struct ASEnvironmentLayoutOptionsState ASEnvironmentDefaultLayoutOptionsState = {};
ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentLayoutOptionsState state, ASEnvironmentStatePropagation propagation);

static const struct ASEnvironmentHierarchyState ASEnvironmentDefaultHierarchyState = {};
ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentHierarchyState state, ASEnvironmentStatePropagation propagation);

static const struct ASEnvironmentTraitCollection ASEnvironmentDefaultTraitCollection = {};
ASEnvironmentState ASEnvironmentMergeObjectAndState(ASEnvironmentState environmentState, ASEnvironmentTraitCollection state, ASEnvironmentStatePropagation propagation);


#pragma mark - Propagation

template <typename ASEnvironmentStateType>
void ASEnvironmentStatePropagateDown(id<ASEnvironment> object, ASEnvironmentStateType state) {
  ASEnvironmentPerformBlockOnObjectAndChildren(object, ^(id<ASEnvironment> node) {
    node.environmentState = ASEnvironmentMergeObjectAndState(node.environmentState, state, ASEnvironmentStatePropagation::DOWN);
  });
}

template <typename ASEnvironmentStateType>
void ASEnvironmentStatePropagateUp(id<ASEnvironment> object, ASEnvironmentStateType state) {
  ASEnvironmentPerformBlockOnObjectAndParents(object, ^(id<ASEnvironment> node) {
    node.environmentState = ASEnvironmentMergeObjectAndState(node.environmentState, state, ASEnvironmentStatePropagation::UP);
  });
}

template <typename ASEnvironmentStateType>
void ASEnvironmentStateApply(id<ASEnvironment> object, ASEnvironmentStateType& state, ASEnvironmentStatePropagation propagate) {
  if (propagate == ASEnvironmentStatePropagation::DOWN) {
    ASEnvironmentStatePropagateUp(object, state);
  } else if (propagate == ASEnvironmentStatePropagation::UP) {
    ASEnvironmentStatePropagateDown(object, state);
  }
}

/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASEnvironment.h"
#import "ASEnvironmentInternal.h"
#import <AsyncDisplayKit/ASAvailability.h>

ASEnvironmentLayoutOptionsState _ASEnvironmentLayoutOptionsStateMakeDefault()
{
  return (ASEnvironmentLayoutOptionsState) {
    // Default values can be defined in here
  };
}

ASEnvironmentHierarchyState _ASEnvironmentHierarchyStateMakeDefault()
{
  return (ASEnvironmentHierarchyState) {
    // Default values can be defined in here
  };
}

extern void ASEnvironmentTraitCollectionClearDisplayContext(id<ASEnvironment> rootEnvironment)
{
  ASEnvironmentState envState = [rootEnvironment environmentState];
  ASEnvironmentTraitCollection displayTraits = envState.traitCollection;
  displayTraits.displayContext = nil;
  envState.traitCollection = displayTraits;
  [rootEnvironment setEnvironmentState:envState];
  
  for (id<ASEnvironment> child in [rootEnvironment children]) {
    ASEnvironmentStatePropagateDown(child, displayTraits);
  }
}

ASEnvironmentTraitCollection _ASEnvironmentTraitCollectionMakeDefault()
{
  return (ASEnvironmentTraitCollection) {
    // Default values can be defined in here
  };
}

ASEnvironmentTraitCollection ASEnvironmentTraitCollectionFromUITraitCollection(UITraitCollection *traitCollection)
{
  ASEnvironmentTraitCollection asyncTraitCollection;
  if (AS_AT_LEAST_IOS8) {
    asyncTraitCollection.displayScale = traitCollection.displayScale;
    asyncTraitCollection.horizontalSizeClass = traitCollection.horizontalSizeClass;
    asyncTraitCollection.verticalSizeClass = traitCollection.verticalSizeClass;
    asyncTraitCollection.userInterfaceIdiom = traitCollection.userInterfaceIdiom;
    if (AS_AT_LEAST_IOS9) {
      asyncTraitCollection.forceTouchCapability = traitCollection.forceTouchCapability;
    }
  }
  return asyncTraitCollection;
}

BOOL ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(ASEnvironmentTraitCollection traitCollection0, ASEnvironmentTraitCollection traitCollection1)
{
  return
    traitCollection0.verticalSizeClass == traitCollection1.verticalSizeClass &&
    traitCollection0.horizontalSizeClass == traitCollection1.horizontalSizeClass &&
    traitCollection0.displayScale == traitCollection1.displayScale &&
    traitCollection0.userInterfaceIdiom == traitCollection1.userInterfaceIdiom &&
    traitCollection0.forceTouchCapability == traitCollection1.forceTouchCapability &&
    traitCollection0.displayContext == traitCollection1.displayContext;
}

ASEnvironmentState ASEnvironmentStateMakeDefault()
{
  return (ASEnvironmentState) {
    .layoutOptionsState = _ASEnvironmentLayoutOptionsStateMakeDefault(),
    .hierarchyState = _ASEnvironmentHierarchyStateMakeDefault(),
    .traitCollection = _ASEnvironmentTraitCollectionMakeDefault()
  };
}


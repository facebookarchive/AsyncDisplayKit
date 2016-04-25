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

extern void ASDisplayTraitsClearDisplayContext(id<ASEnvironment> rootEnvironment)
{
  ASEnvironmentState envState = [rootEnvironment environmentState];
  ASDisplayTraits displayTraits = envState.displayTraits;
  displayTraits.displayContext = nil;
  envState.displayTraits = displayTraits;
  [rootEnvironment setEnvironmentState:envState];
  
  for (id<ASEnvironment> child in [rootEnvironment children]) {
    ASEnvironmentStatePropagateDown(child, displayTraits);
  }
}

ASDisplayTraits _ASDisplayTraitsMakeDefault()
{
  return (ASDisplayTraits) {
    // Default values can be defined in here
  };
}

ASDisplayTraits ASDisplayTraitsFromUITraitCollection(UITraitCollection *traitCollection)
{  
  return (ASDisplayTraits) {
    .displayScale = traitCollection.displayScale,
    .horizontalSizeClass = traitCollection.horizontalSizeClass,
    .userInterfaceIdiom = traitCollection.userInterfaceIdiom,
    .verticalSizeClass = traitCollection.verticalSizeClass,
    .forceTouchCapability = traitCollection.forceTouchCapability,
  };
}

BOOL ASDisplayTraitsIsEqualToASDisplayTraits(ASDisplayTraits displayTraits0, ASDisplayTraits displayTraits1)
{
  return
  displayTraits0.verticalSizeClass == displayTraits1.verticalSizeClass &&
  displayTraits0.horizontalSizeClass == displayTraits1.horizontalSizeClass &&
  displayTraits0.displayScale == displayTraits1.displayScale &&
  displayTraits0.userInterfaceIdiom == displayTraits1.userInterfaceIdiom &&
  displayTraits0.forceTouchCapability == displayTraits1.forceTouchCapability;
}

ASEnvironmentState ASEnvironmentStateMakeDefault()
{
  return (ASEnvironmentState) {
    .layoutOptionsState = _ASEnvironmentLayoutOptionsStateMakeDefault(),
    .hierarchyState = _ASEnvironmentHierarchyStateMakeDefault(),
    .displayTraits = _ASDisplayTraitsMakeDefault()
  };
}


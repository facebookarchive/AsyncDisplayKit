//
//  ASEnvironment.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASEnvironmentInternal.h"
#import "ASAvailability.h"

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

ASEnvironmentTraitCollection _ASEnvironmentTraitCollectionMakeDefault()
{
  return (ASEnvironmentTraitCollection) {
    // Default values can be defined in here
    .containerSize = CGSizeZero,
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

BOOL ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(ASEnvironmentTraitCollection lhs, ASEnvironmentTraitCollection rhs)
{
  return
    lhs.verticalSizeClass == rhs.verticalSizeClass &&
    lhs.horizontalSizeClass == rhs.horizontalSizeClass &&
    lhs.displayScale == rhs.displayScale &&
    lhs.userInterfaceIdiom == rhs.userInterfaceIdiom &&
    lhs.forceTouchCapability == rhs.forceTouchCapability &&
    CGSizeEqualToSize(lhs.containerSize, rhs.containerSize);
}

ASEnvironmentState ASEnvironmentStateMakeDefault()
{
  return (ASEnvironmentState) {
    .layoutOptionsState = _ASEnvironmentLayoutOptionsStateMakeDefault(),
    .hierarchyState = _ASEnvironmentHierarchyStateMakeDefault(),
    .environmentTraitCollection = _ASEnvironmentTraitCollectionMakeDefault()
  };
}


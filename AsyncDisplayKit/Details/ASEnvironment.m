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

ASEnvironmentLayoutOptionsState ASEnvironmentLayoutOptionsStateCreate()
{
  return (ASEnvironmentLayoutOptionsState) {
    .spacingBefore = 0,
    .flexBasis = ASRelativeDimensionUnconstrained,
    .alignSelf = ASStackLayoutAlignSelfAuto,
    
    .sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(CGSizeZero), ASRelativeSizeMakeWithCGSize(CGSizeZero)),
    .layoutPosition = CGPointZero
  };
}

ASEnvironmentHierarchyState ASEnvironmentHierarchyStateCreate()
{
  return (ASEnvironmentHierarchyState) {
    .rasterized = NO,
    .rangeManaged = NO,
    .transitioningSupernodes = NO,
    .layoutPending = NO
  };
}

ASEnvironmentCollection ASEnvironmentCollectionCreate()
{
  return (ASEnvironmentCollection) {
    .hierarchyState = ASEnvironmentHierarchyStateCreate(),
    .layoutOptionsState = ASEnvironmentLayoutOptionsStateCreate()
  };
}
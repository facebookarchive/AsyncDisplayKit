//
//  ASVisibilityProtocols.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASVisibilityProtocols.h>

ASLayoutRangeMode ASLayoutRangeModeForVisibilityDepth(NSUInteger visibilityDepth)
{
  if (visibilityDepth == 0) {
    return ASLayoutRangeModeFull;
  } else if (visibilityDepth == 1) {
    return ASLayoutRangeModeMinimum;
  } else if (visibilityDepth == 2) {
    return ASLayoutRangeModeVisibleOnly;
  }
  return ASLayoutRangeModeLowMemory;
}

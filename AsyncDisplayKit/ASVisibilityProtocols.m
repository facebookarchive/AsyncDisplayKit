//
//  ASVisibilityProtocols.m
//  Pods
//
//  Created by Garrett Moon on 4/28/16.
//
//

#import <Foundation/Foundation.h>

#import "ASVisibilityProtocols.h"

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
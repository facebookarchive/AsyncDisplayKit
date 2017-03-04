//
//  ASLayoutRangeType.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

typedef struct {
  CGFloat leadingBufferScreenfuls;
  CGFloat trailingBufferScreenfuls;
} ASRangeTuningParameters;

FOUNDATION_EXPORT ASRangeTuningParameters const ASRangeTuningParametersZero;

FOUNDATION_EXPORT BOOL ASRangeTuningParametersEqualToRangeTuningParameters(ASRangeTuningParameters lhs, ASRangeTuningParameters rhs);

/**
 * Each mode has a complete set of tuning parameters for range types.
 * Depending on some conditions (including interface state and direction of the scroll view, state of rendering engine, etc),
 * a range controller can choose which mode it should use at a given time.
 */
typedef NS_ENUM(NSInteger, ASLayoutRangeMode) {
  ASLayoutRangeModeUnspecified = -1,
  
  /**
   * Minimum mode is used when a range controller should limit the amount of work it performs.
   * Thus, fewer views/layers are created and less data is fetched, saving system resources.
   * Range controller can automatically switch to full mode when conditions change.
   */
  ASLayoutRangeModeMinimum = 0,
    
  /**
   * Normal/Full mode that a range controller uses to provide the best experience for end users.
   * This mode is usually used for an active scroll view.
   * A range controller under this requires more resources compare to minimum mode.
   */
  ASLayoutRangeModeFull,
  
  /**
   * Visible Only mode is used when a range controller should set its display and preload regions to only the size of their bounds.
   * This causes all additional backing stores & preloaded data to be released, while ensuring a user revisiting the view will
   * still be able to see the expected content.  This mode is automatically set on all ASRangeControllers when the app suspends,
   * allowing the operating system to keep the app alive longer and increase the chance it is still warm when the user returns.
   */
  ASLayoutRangeModeVisibleOnly,
  
  /**
   * Low Memory mode is used when a range controller should discard ALL graphics buffers, including for the area that would be visible
   * the next time the user views it (bounds).  The only range it preserves is Preload, which is limited to the bounds, allowing
   * the content to be restored relatively quickly by re-decoding images (the compressed images are ~10% the size of the decoded ones,
   * and text is a tiny fraction of its rendered size).
   */
  ASLayoutRangeModeLowMemory
};

static NSInteger const ASLayoutRangeModeCount = 4;

typedef NS_ENUM(NSInteger, ASLayoutRangeType) {
  ASLayoutRangeTypeDisplay,
  ASLayoutRangeTypePreload
};

static NSInteger const ASLayoutRangeTypeCount = 2;

#define ASLayoutRangeTypeRender ASLayoutRangeTypeDisplay
#define ASLayoutRangeTypeFetchData ASLayoutRangeTypePreload

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

/**
 * Each mode has a complete set of tuning parameters for range types.
 * Depending on some conditions (including interface state and direction of the scroll view, state of rendering engine, etc),
 * a range controller can choose which mode it should use at a given time.
 */
typedef NS_ENUM(NSUInteger, ASLayoutRangeMode) {
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
   * Visible Only mode is used when a range controller should set its display and fetch data regions to only the size of their bounds.
   * This causes all additional backing stores & fetched data to be released, while ensuring a user revisiting the view will
   * still be able to see the expected content.  This mode is automatically set on all ASRangeControllers when the app suspends,
   * allowing the operating system to keep the app alive longer and increase the chance it is still warm when the user returns.
   */
  ASLayoutRangeModeVisibleOnly,
  
  /**
   * Low Memory mode is used when a range controller should discard ALL graphics buffers, including for the area that would be visible
   * the next time the user views it (bounds).  The only range it preserves is Fetch Data, which is limited to the bounds, allowing
   * the content to be restored relatively quickly by re-decoding images (the compressed images are ~10% the size of the decoded ones,
   * and text is a tiny fraction of its rendered size).
   */
  ASLayoutRangeModeLowMemory,
  ASLayoutRangeModeCount
};

#define ASLayoutRangeModeInvalid ASLayoutRangeModeCount

typedef NS_ENUM(NSInteger, ASLayoutRangeType) {
  ASLayoutRangeTypeDisplay,
  ASLayoutRangeTypeFetchData,
  ASLayoutRangeTypeCount
};

#define ASLayoutRangeTypeRender ASLayoutRangeTypeDisplay
#define ASLayoutRangeTypePreload ASLayoutRangeTypeFetchData

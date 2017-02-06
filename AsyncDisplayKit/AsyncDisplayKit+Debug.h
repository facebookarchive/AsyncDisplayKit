//
//  AsyncDisplayKit+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/ASRangeController.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASImageNode (Debugging)

/**
 * Enables an ASImageNode debug label that shows the ratio of pixels in the source image to those in
 * the displayed bounds (including cropRect).  This helps detect excessive image fetching / downscaling,
 * as well as upscaling (such as providing a URL not suitable for a Retina device).  For dev purposes only.
 * @param enabled Specify YES to show the label on all ASImageNodes with non-1.0x source-to-bounds pixel ratio.
 */
+ (void)setShouldShowImageScalingOverlay:(BOOL)show;
+ (BOOL)shouldShowImageScalingOverlay;

@end

@interface ASControlNode (Debugging)

/**
 * Class method to enable a visualization overlay of the tappable area on the ASControlNode. For app debugging purposes only.
 * NOTE: GESTURE RECOGNIZERS, (including tap gesture recognizers on a control node) WILL NOT BE VISUALIZED!!!
 * Overlay = translucent GREEN color,
 * edges that are clipped by the tappable area of any parent (their bounds + hitTestSlop) in the hierarchy = DARK GREEN BORDERED EDGE,
 * edges that are clipped by clipToBounds = YES of any parent in the hierarchy = ORANGE BORDERED EDGE (may still receive touches beyond
 * overlay rect, but can't be visualized).
 * @param enable Specify YES to make this debug feature enabled when messaging the ASControlNode class.
 */
+ (void)setEnableHitTestDebug:(BOOL)enable;
+ (BOOL)enableHitTestDebug;

@end

@interface ASRangeController (Debugging)

/**
 * Class method to enable a visualization overlay of the all ASRangeController's tuning parameters. For dev purposes only.
 * To use, message ASRangeController in the AppDelegate --> [ASRangeController setShouldShowRangeDebugOverlay:YES];
 * @param enable Specify YES to make this debug feature enabled when messaging the ASRangeController class.
 */
+ (void)setShouldShowRangeDebugOverlay:(BOOL)show;
+ (BOOL)shouldShowRangeDebugOverlay;

+ (void)layoutDebugOverlayIfNeeded;

- (void)addRangeControllerToRangeDebugOverlay;

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
      preloadTuningParameters:(ASRangeTuningParameters)preloadTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;

@end

NS_ASSUME_NONNULL_END

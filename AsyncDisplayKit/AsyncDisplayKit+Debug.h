//
//  AsyncDisplayKit+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASControlNode.h"
#import "ASImageNode.h"

@interface ASControlNode (Debugging)

/**
 Class method to enable a visualization overlay of the tapable area on the ASControlNode. For app debugging purposes only.
 @param enable Specify YES to make this debug feature enabled when messaging the ASControlNode class.
 */
+ (void)setEnableHitTestDebug:(BOOL)enable;

@end

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

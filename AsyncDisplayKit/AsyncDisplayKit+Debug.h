//
//  AsyncDisplayKit+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASControlNode.h"
#import "ASImageNode.h"
#import "ASTextNode.h"
#import "ASCellNode.h"
#import "ASRangeController.h"

@interface ASControlNode (Debugging)

/**
 Class method to enable a visualization overlay of the tappable area on the ASControlNode. For app debugging purposes only.
 NOTE: GESTURE RECOGNIZERS, (including tap gesture recognizers on a control node) WILL NOT BE VISUALIZED!!!
 Overlay = translucent GREEN color, 
 edges that are clipped by the tappable area of any parent (their bounds + hitTestSlop) in the hierarchy = DARK GREEN BORDERED EDGE,
 edges that are clipped by clipToBounds = YES of any parent in the hierarchy = ORANGE BORDERED EDGE (may still receive touches beyond
 overlay rect, but can't be visualized).
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

@interface ASRangeHierarchyCountInfo : NSObject
@property (nonatomic, strong) ASTextNode *textNode;
@property (nonatomic, assign) NSInteger nodeCount;
@property (nonatomic, assign) NSInteger viewCount;
@property (nonatomic, assign) NSInteger layerCount;
@end

@interface ASRangeController (Debug)

/**
 * Class method to enable a visualization overlay of the number of nodes, views and layers in the ASRangeController.
 * For app debugging purposes only.
 *
 * @param enabled Specify YES to make this debug feature enabled when messaging the ASRangeController class.
 */
+ (void)setHierarchyCountDebugEnabled:(BOOL)enable;
+ (BOOL)shouldShowHierarchyDebugCountsOverlay;

+ (void)updateRangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info;
+ (void)debugCountsForAllSubnodes:(ASCellNode *)node increment:(BOOL)increment rangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info;
+ (void)debugCountsForNode:(ASCellNode *)node increment:(BOOL)increment rangeHierarchyCountInfo:(ASRangeHierarchyCountInfo *)info;

@end

//
//  AsyncDisplayKit+Debug.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASTableView.h>
#import <AsyncDisplayKit/ASCollectionView.h>
#import "ASTextNode.h"

@interface ASRangeHierarchyCountInfo : NSObject
@property (nonatomic, strong) ASTextNode *textNode;
@property (nonatomic, assign) NSInteger nodeCount;
@property (nonatomic, assign) NSInteger viewCount;
@property (nonatomic, assign) NSInteger layerCount;
@end

@interface ASControlNode (Debug)
/**
 Class method to enable a visualization overlay of the tapable area on the ASControlNode. For app debugging purposes only.
 @param enabled Specify YES to make this debug feature enabled when messaging the ASControlNode class.
 */
+ (void)setHitTestDebugEnabled:(BOOL)enable;
+ (BOOL)shouldShowHitTestDebugOverlay;

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

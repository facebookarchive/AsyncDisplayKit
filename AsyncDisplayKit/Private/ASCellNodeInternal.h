//
//  ASCellNodeInternal.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 10/9/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASCellNode.h>

@interface ASCellNode (Internal)

/*
 * @abstract Should this node be remeasured when the data controller next adds it?
 *
 * @discussion If possible, cell nodes should be measured in the background. However,
 * we cannot violate a node's thread affinity. When nodes are added in a data controller,
 * nodes with main thread affinity will be measured immediately on the main thread and this 
 * flag will be cleared, so the node will be skipped during the background measurement pass.
 */
@property (nonatomic) BOOL needsMeasure;

@end

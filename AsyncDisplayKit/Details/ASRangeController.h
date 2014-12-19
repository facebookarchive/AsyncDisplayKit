/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASFlowLayoutController.h>
#import <AsyncDisplayKit/ASLayoutController.h>

@protocol ASRangeControllerDelegate;


/**
 * Working range controller.
 *
 * Used internally by ASTableView and potentially by a future ASCollectionView.  Observes the visible range, maintains
 * a working range, and is responsible for handling AsyncDisplayKit machinery (sizing cell nodes, enqueueing and
 * cancelling their asynchronous layout and display, and so on).
 */
@interface ASRangeController : ASDealloc2MainObject <ASDataControllerDelegate>

/**
 * Notify the receiver that the visible range has been updated.
 *
 * @see [ASRangeControllerDelegate rangeControllerVisibleNodeIndexPaths:]
 */
- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(enum ASScrollDirection)scrollDirection;

/**
 * Add the sized node for `indexPath` as a subview of `contentView`.
 *
 * @param contentView UIView to add a (sized) node's view to.
 *
 * @param node The ASCellNode to be added.
 */
- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node;

/**
 * Delegate and ultimate data source.  Must not be nil.
 */
@property (nonatomic, weak) id<ASRangeControllerDelegate> delegate;

@property (nonatomic, strong) id<ASLayoutController> layoutController;

@end


/**
 * <ASRangeController> delegate.  For example, <ASTableView>.
 */
@protocol ASRangeControllerDelegate <NSObject>

/**
 * @param rangeController Sender.
 *
 * @returns an array of index paths corresponding to the nodes currently visible onscreen (i.e., the visible range).
 */
- (NSArray *)rangeControllerVisibleNodeIndexPaths:(ASRangeController *)rangeController;

/**
 * @param rangeController Sender.
 *
 * @returns the receiver's viewport size (i.e., the screen space occupied by the visible range).
 */
- (CGSize)rangeControllerViewportSize:(ASRangeController *)rangeController;

/**
 * Fetch nodes at specific index paths.
 */
- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called for nodes insertion.
 */
- (void)rangeController:(ASRangeController *)rangeController didInsertNodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called for nodes deletion.
 */
- (void)rangeController:(ASRangeController *)rangeController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called for section insertion.
 */
- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet;

/**
 * Called for section deletion.
 */
- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

@optional

/**
 * Called before nodes insertion.
 */
- (void)rangeController:(ASRangeController *)rangeController willInsertNodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called before nodes deletion.
 */
- (void)rangeController:(ASRangeController *)rangeController willDeleteNodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called before section insertion.
 */
- (void)rangeController:(ASRangeController *)rangeController willInsertSectionsAtIndexSet:(NSIndexSet *)indexSet;

/**
 * Called before section deletion.
 */
- (void)rangeController:(ASRangeController *)rangeController willDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet;

@end

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
 * Used internally by ASTableView and ASCollectionView.  It is paired with ASDataController.
 * It is designed to support custom scrolling containers as well.  Observes the visible range, maintains
 * "working ranges" to trigger network calls and rendering, and is responsible for driving asynchronous layout of cells.
 * This includes cancelling those asynchronous operations as cells fall outside of the working ranges.
 */
@interface ASRangeController : ASDealloc2MainObject <ASDataControllerDelegate>

/**
 * Notify the range controller that the visible range has been updated.
 * This is the primary input call that drives updating the working ranges, and triggering their actions.
 *
 * @param scrollDirection The current scroll direction of the scroll view.
 *
 * @see [ASRangeControllerDelegate rangeControllerVisibleNodeIndexPaths:]
 */
- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(ASScrollDirection)scrollDirection;

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
 * Begin updates.
 *
 * @param rangeController Sender.
 */
- (void)rangeControllerBeginUpdates:(ASRangeController *)rangeController;

/**
 * End updates.
 *
 * @param rangeController Sender.
 *
 * @param completion Completion block.
 */
- (void)rangeController:(ASRangeController * )rangeController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion;

/**
 * Fetch nodes at specific index paths.
 *
 * @param rangeController Sender.
 *
 * @param indexPaths Index paths.
 */
- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Called for nodes insertion.
 *
 * @param rangeController Sender.
 *
 * @param indexPaths Index path of inserted nodes.
 *
 * @param animationOptions Animation options. See ASDataControllerAnimationOptions.
 */
- (void)rangeController:(ASRangeController *)rangeController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 * Called for nodes deletion.
 *
 * @param rangeController Sender.
 *
 * @param indexPaths Index path of deleted nodes.
 *
 * @param animationOptions Animation options. See ASDataControllerAnimationOptions.
 */
- (void)rangeController:(ASRangeController *)rangeController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 * Called for section insertion.
 *
 * @param rangeController Sender.
 *
 * @param indexSet Index set of inserted sections.
 *
 * @param animationOptions Animation options. See ASDataControllerAnimationOptions.
 */
- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 * Called for section deletion.
 *
 * @param rangeController Sender.
 *
 * @param indexSet Index set of deleted sections.
 *
 * @param animationOptions Animation options. See ASDataControllerAnimationOptions.
 */
- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

@end

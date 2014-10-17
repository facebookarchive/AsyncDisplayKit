/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASCellNode.h>

typedef struct {
  // working range buffers, on either side of scroll
  NSInteger trailingBufferScreenfuls;
  NSInteger leadingBufferScreenfuls;
} ASRangeTuningParameters;

@protocol ASRangeControllerDelegate;


/**
 * Working range controller.
 *
 * Used internally by ASTableView and potentially by a future ASCollectionView.  Observes the visible range, maintains
 * a working range, and is responsible for handling AsyncDisplayKit machinery (sizing cell nodes, enqueueing and
 * cancelling their asynchronous layout and display, and so on).
 */
@interface ASRangeController : NSObject

/**
 * Notify the receiver that its delegate's data source has been set or changed.  This is like -[UITableView reloadData]
 * but drastically more expensive, as it destroys the working range and all cached nodes.
 */
- (void)rebuildData;

/**
 * Notify the receiver that the visible range has been updated.
 *
 * @see [ASRangeControllerDelegate rangeControllerVisibleNodeIndexPaths:]
 */
- (void)visibleNodeIndexPathsDidChange;

/**
 * ASTableView is only aware of nodes that have already been sized.
 *
 * Custom ASCellNode implementations are encouraged to have "realistic placeholders", since they can only be onscreen if
 * they have enough data for layout.  E.g., try setting all subnodes' background colours to [UIColor lightGrayColor].
 */
- (NSInteger)numberOfSizedSections;
- (NSInteger)numberOfSizedRowsInSection:(NSInteger)section;

/**
 * Add the sized node for `indexPath` as a subview of `contentView`.
 *
 * @param contentView UIView to add a (sized) node's view to.
 *
 * @param indexPath Index path for the node to be added.
 */
- (void)configureContentView:(UIView *)contentView forIndexPath:(NSIndexPath *)indexPath;

/**
 * Query the sized node at `indexPath` for its calculatedSize.
 *
 * @param indexPath The index path for the node of interest.
 *
 * TODO:  Currently we disallow direct access to ASCellNode outside ASRangeController since touching the node's view can
 *        break async display.  We should expose the node anyway, possibly with an assertion guarding against external
 *        use of the view property, so ASCellNode can support configuration for UITableViewCell properties (selection
 *        style, separator style, etc.) and ASTableView can query that data.
 */
- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Notify the receiver that its data source has been updated to append the specified nodes.
 *
 * @param indexPaths Array of NSIndexPaths for the newly-sized nodes.
 */
- (void)appendNodesWithIndexPaths:(NSArray *)indexPaths;

/**
 * Delegate and ultimate data source.  Must not be nil.
 */
@property (nonatomic, weak) id<ASRangeControllerDelegate> delegate;

/**
 * Tuning parameters for the working range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
@property (nonatomic, assign) ASRangeTuningParameters tuningParameters;

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
 * @param rangeController Sender.
 *
 * @returns The number of total sections.
 *
 * @discussion <ASTableView> forwards this method to its data source.
 */
- (NSInteger)rangeControllerSections:(ASRangeController *)rangeController;

/**
 * @param rangeController Sender.
 *
 * @param section Section.
 *
 * @returns The number of rows in `section`.
 *
 * @discussion <ASTableView> forwards this method to its data source.
 */
- (NSInteger)rangeController:(ASRangeController *)rangeController rowsInSection:(NSInteger)section;

/**
 * @param rangeController Sender.
 *
 * @param indexPath Index path for the node of interest.
 * 
 * @returns A new <ASCellNode> corresponding to `indexPath`.
 *
 * @discussion <ASTableView> forwards this method to its data source.
 */
- (ASCellNode *)rangeController:(ASRangeController *)rangeController nodeForIndexPath:(NSIndexPath *)indexPath;

/**
 * @param rangeController Sender.
 *
 * @param indexPath Node to be sized.
 *
 * @returns Sizing constraints for the node at `indexPath`, to be used as an argument to <[ASDisplayNode measure:]>.
 */
- (CGSize)rangeController:(ASRangeController *)rangeController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Notifies the receiver that the specified nodes have been sized and are ready for display.
 *
 * @param rangeController Sender.
 *
 * @param indexPaths Array of NSIndexPaths for the newly-sized nodes.
 */
- (void)rangeController:(ASRangeController *)rangeController didSizeNodesWithIndexPaths:(NSArray *)indexPaths;

@end

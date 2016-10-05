//
//  ASTableNode.h
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableView.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASTableDataSource;
@protocol ASTableDelegate;
@class ASTableView;

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode <ASRangeControllerUpdateRangeProtocol>

- (instancetype)init; // UITableViewStylePlain
- (instancetype)initWithStyle:(UITableViewStyle)style;

@property (strong, nonatomic, readonly) ASTableView *view;

// These properties can be set without triggering the view to be created, so it's fine to set them in -init.
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;

/**
 * Tuning parameters for a range type in full mode.
 *
 * @param rangeType The range type to get the tuning parameters for.
 *
 * @return A tuning parameter value for the given range type in full mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT;

/**
 * Set the tuning parameters for a range type in full mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

/**
 * Tuning parameters for a range type in the specified mode.
 *
 * @param rangeMode The range mode to get the running parameters for.
 * @param rangeType The range type to get the tuning parameters for.
 *
 * @return A tuning parameter value for the given range type in the given mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT;

/**
 * Set the tuning parameters for a range type in the specified mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeMode The range mode to set the running parameters for.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion;

/**
 *  Perform a batch of updates asynchronously, optionally disabling all animations in the batch. This method must be called from the main thread.
 *  The data source must be updated to reflect the changes before the update block completes.
 *
 *  @param animated   NO to disable animations for this batch
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchAnimated:(BOOL)animated updates:(nullable __attribute((noescape)) void (^)())updates completion:(nullable void (^)(BOOL finished))completion;

/**
 *  Blocks execution of the main thread until all section and row updates are committed. This method must be called from the main thread.
 */
- (void)waitUntilAllUpdatesAreCommitted;

/**
 * Inserts one or more sections, with an option to animate the insertion.
 *
 * @param sections An index set that specifies the sections to insert.
 *
 * @param animation A constant that indicates how the insertion is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Deletes one or more sections, with an option to animate the deletion.
 *
 * @param sections An index set that specifies the sections to delete.
 *
 * @param animation A constant that indicates how the deletion is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Reloads the specified sections using a given animation effect.
 *
 * @param sections An index set that specifies the sections to reload.
 *
 * @param animation A constant that indicates how the reloading is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Moves a section to a new location.
 *
 * @param section The index of the section to move.
 *
 * @param newSection The index that is the destination of the move for the section.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Inserts rows at the locations identified by an array of index paths, with an option to animate the insertion.
 *
 * @param indexPaths An array of NSIndexPath objects, each representing a row index and section index that together identify a row.
 *
 * @param animation A constant that indicates how the insertion is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Deletes the rows specified by an array of index paths, with an option to animate the deletion.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the rows to delete.
 *
 * @param animation A constant that indicates how the deletion is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Reloads the specified rows using a given animation effect.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the rows to reload.
 *
 * @param animation A constant that indicates how the reloading is to be animated. See UITableViewRowAnimation.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;

/**
 * Moves the row at a specified location to a destination location.
 *
 * @param indexPath The index path identifying the row to move.
 *
 * @param newIndexPath The index path that is the destination of the move for the row.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

/**
 * Retrieves the number of rows in the given section.
 *
 * @param section The section.
 *
 * @return The number of rows.
 */
- (NSInteger)numberOfRowsInSection:(NSInteger)section AS_WARN_UNUSED_RESULT;

/**
 * The number of sections in the table node.
 */
@property (nonatomic, readonly) NSInteger numberOfSections;

/**
 * Retrieves the node for the row at the given index path.
 */
- (nullable ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Similar to -indexPathForCell:.
 *
 * @param cellNode a node for a row.
 *
 * @return The index path to this row, if it exists.
 *
 * @discussion This method will return @c nil for a node that is still being
 *   displayed in the table view, if the data source has deleted the row.
 *   That is, the node is visible but it no longer corresponds
 *   to any item in the data source and will be removed soon.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode AS_WARN_UNUSED_RESULT;

@end

/**
 * This is a node-based UITableViewDataSource.
 */
@protocol ASTableDataSource <ASCommonTableDataSource, NSObject>

@optional

/**
 * Asks the data source for the number of sections in the table node.
 *
 * @see @c numberOfSectionsInTableView:
 */
- (NSInteger)numberOfSectionsInTableNode:(ASTableNode *)tableNode;

/**
 * Asks the data source for the number of rows in the given section of the table node.
 *
 * @see @c numberOfSectionsInTableView:
 */
- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section;

/**
 * Asks the data source for a block to create a node to represent the row at the given index path.
 * The block will be run by the table node concurrently in the background before the row is inserted
 * into the table view.
 *
 * @param tableNode The sender.
 * @param indexPath The index path of the row.
 *
 * @return a block that creates the node for display at this indexpath.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 *
 * @note This method takes precedence over tableNode:nodeForRowAtIndexPath: if implemented.
 */
- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the data source for a node to represent the row at the given index path.
 *
 * @param tableNode The sender.
 * @param indexPath The index path of the row.
 *
 * @return a node to display for this row. This will be called on the main thread and should not implement reuse (it will be called once per row). Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -tableView:cellForRowAtIndexPath:.
 *
 * @param tableNode The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @return a node for display at this indexpath. This will be called on the main thread and should not implement reuse (it will be called once per row). Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Similar to -tableView:nodeForRowAtIndexPath:
 * This method takes precedence over tableView:nodeForRowAtIndexPath: if implemented.
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @return a block that creates the node for display at this indexpath.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Indicator to lock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)tableViewLockDataSource:(ASTableView *)tableView ASDISPLAYNODE_DEPRECATED;

/**
 * Indicator to unlock the data source for data fetching in asyn mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)tableViewUnlockDataSource:(ASTableView *)tableView ASDISPLAYNODE_DEPRECATED;

@end

/**
 * This is a node-based UITableViewDelegate.
 *
 * Note that -tableView:heightForRowAtIndexPath: has been removed; instead, your custom ASCellNode subclasses are
 * responsible for deciding their preferred onscreen height in -calculateSizeThatFits:.
 */
@protocol ASTableDelegate <ASCommonTableViewDelegate, NSObject>

@optional

- (void)tableNode:(ASTableNode *)tableNode willDisplayRowWithNode:(ASCellNode *)node;

- (void)tableNode:(ASTableNode *)tableNode didEndDisplayingRowWithNode:(ASCellNode *)node;

- (nullable ASCellNode *)tableNode:(ASTableNode *)tableNode willSelectRowWithNode:(ASCellNode *)node;

- (void)tableNode:(ASTableNode *)tableNode didSelectRowWithNode:(ASCellNode *)node;

- (nullable ASCellNode *)tableNode:(ASTableNode *)tableNode willDeselectRowWithNode:(ASCellNode *)node;

- (void)tableNode:(ASTableNode *)tableNode didDeselectRowWithNode:(ASCellNode *)node;

- (BOOL)tableNode:(ASTableNode *)tableNode shouldHighlightRowWithNode:(ASCellNode *)node;
- (void)tableNode:(ASTableNode *)tableNode didHighlightRowWithNode:(ASCellNode *)node;
- (void)tableNode:(ASTableNode *)tableNode didUnhighlightRowWithNode:(ASCellNode *)node;

- (BOOL)tableNode:(ASTableNode *)tableNode shouldShowMenuForRowWithNode:(ASCellNode *)node;
- (BOOL)tableNode:(ASTableNode *)tableNode canPerformAction:(SEL)action forRowWithNode:(ASCellNode *)node withSender:(nullable id)sender;
- (void)tableNode:(ASTableNode *)tableNode performAction:(SEL)action forRowWithNode:(ASCellNode *)node withSender:(nullable id)sender;

/**
 * Provides the constrained size range for measuring the row at the index path.
 * Note: the widths in the returned size range are ignored!
 *
 * @param tableNode The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @return A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)tableNode:(ASTableNode *)tableNode constrainedSizeForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Receive a message that the tableView is near the end of its data set and more data should be fetched if necessary.
 *
 * @param tableView The sender.
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 *
 * ASTableView currently only supports batch events for tail loads. If you require a head load, consider implementing a
 * UIRefreshControl.
 */
- (void)tableNode:(ASTableNode *)tableNode willBeginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * Tell the tableView if batch fetching should begin.
 *
 * @param tableView The sender.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the tableView assumes that it should notify its asyncDelegate when batch fetching
 * should occur.
 */
- (BOOL)shouldBatchFetchForTableNode:(ASTableNode *)tableNode;

/**
 * Informs the delegate that the table view will add the given node
 * at the given index path to the view hierarchy.
 *
 * @param tableView The sender.
 * @param node The node that will be displayed.
 * @param indexPath The index path of the row that will be displayed.
 *
 * @warning AsyncDisplayKit processes table view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 */
- (void)tableView:(ASTableView *)tableView willDisplayNode:(ASCellNode *)node forRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

/**
 * Informs the delegate that the table view did remove the provided node from the view hierarchy.
 * This may be caused by the node scrolling out of view, or by deleting the row
 * or its containing section with @c deleteRowsAtIndexPaths:withRowAnimation: or @c deleteSections:withRowAnimation: .
 *
 * @param tableView The sender.
 * @param node The node which was removed from the view hierarchy.
 * @param indexPath The index path at which the node was located before the removal.
 *
 * @warning AsyncDisplayKit processes table view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 */
- (void)tableView:(ASTableView *)tableView didEndDisplayingNode:(ASCellNode *)node forRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

/**
 * Receive a message that the tableView is near the end of its data set and more data should be fetched if necessary.
 *
 * @param tableView The sender.
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 *
 * ASTableView currently only supports batch events for tail loads. If you require a head load, consider implementing a
 * UIRefreshControl.
 */
- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context ASDISPLAYNODE_DEPRECATED;

/**
 * Tell the tableView if batch fetching should begin.
 *
 * @param tableView The sender.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the tableView assumes that it should notify its asyncDelegate when batch fetching
 * should occur.
 */
- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Provides the constrained size range for measuring the row at the index path.
 * Note: the widths in the returned size range are ignored!
 *
 * @param tableView The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @return A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)tableView:(ASTableView *)tableView constrainedSizeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Informs the delegate that the table view will add the node
 * at the given index path to the view hierarchy.
 *
 * @param tableView The sender.
 * @param indexPath The index path of the row that will be displayed.
 *
 * @warning AsyncDisplayKit processes table view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 *
 * This method is deprecated. Use @c tableView:willDisplayNode:forRowAtIndexPath: instead.
 */
- (void)tableView:(ASTableView *)tableView willDisplayNodeForRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

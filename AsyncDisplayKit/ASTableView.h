//
//  ASTableView.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASTableViewProtocols.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASBatchContext.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCellNode;
@protocol ASTableDataSource;
@protocol ASTableDelegate;

/**
 * Asynchronous UITableView with Intelligent Preloading capabilities.
 *
 * ASTableNode is recommended over ASTableView.  This class is provided for adoption convenience.
 *
 * ASTableView is a true subclass of UITableView, meaning it is pointer-compatible with code that
 * currently uses UITableView
 *
 * The main difference is that asyncDataSource expects -nodeForRowAtIndexPath, an ASCellNode, and
 * the heightForRowAtIndexPath: method is eliminated (as are the performance problems caused by it).
 * This is made possible because ASCellNodes can calculate their own size, and preload ahead of time.
 */
@interface ASTableView : UITableView

@property (nonatomic, weak) id<ASTableDelegate>   asyncDelegate;
@property (nonatomic, weak) id<ASTableDataSource> asyncDataSource;

/**
 * Initializer.
 *
 * @param frame A rectangle specifying the initial location and size of the table view in its superview’s coordinates.
 * The frame of the table view changes as table cells are added and deleted.
 *
 * @param style A constant that specifies the style of the table view. See UITableViewStyle for descriptions of valid constants.
 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;

/**
 * Tuning parameters for a range type in full mode.
 *
 * @param rangeType The range type to get the tuning parameters for.
 *
 * @returns A tuning parameter value for the given range type in full mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

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
 * @returns A tuning parameter value for the given range type in the given mode.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

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
 * The number of screens left to scroll before the delegate -tableView:beginBatchFetchingWithContext: is called.
 *
 * Defaults to two screenfuls.
 */
@property (nonatomic, assign) CGFloat leadingScreensForBatching;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on 
 * the main thread.
 * @warning This method is substantially more expensive than UITableView's version.
 */
-(void)reloadDataWithCompletion:(void (^ _Nullable)())completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadData;

/**
 * Reload everything from scratch entirely on the main thread, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UITableView's version and will block the main thread while
 * all the cells load.
 */
- (void)reloadDataImmediately;

/**
 * Triggers a relayout of all nodes.
 *
 */
- (void)relayoutItems;

/**
 *  begins a batch of insert, delete reload and move operations. This method must be called from the main thread.
 */
- (void)beginUpdates;

/**
 *  Concludes a series of method calls that insert, delete, select, or reload rows and sections of the table view, with animation enabled and no completion block.
 *  You call this method to bracket a series of method calls that begins with beginUpdates and that consists of operations
 *  to insert, delete, select, and reload rows and sections of the table view. When you call endUpdates, ASTableView begins animating
 *  the operations simultaneously. This method is must be called from the main thread. It's important to remember that the ASTableView will
 *  be processing the updates asynchronously after this call is completed.
 */
- (void)endUpdates;

/**
 *  Concludes a series of method calls that insert, delete, select, or reload rows and sections of the table view.
 *  You call this method to bracket a series of method calls that begins with beginUpdates and that consists of operations 
 *  to insert, delete, select, and reload rows and sections of the table view. When you call endUpdates, ASTableView begins animating
 *  the operations simultaneously. This method is must be called from the main thread. It's important to remember that the ASTableView will
 *  be processing the updates asynchronously after this call and are not guaranteed to be reflected in the ASTableView until
 *  the completion block is executed.
 *
 *  @param animated   NO to disable all animations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL completed))completion;

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
 * Similar to -cellForRowAtIndexPath:.
 * 
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath.
 */
- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -indexPathForCell:.
 *
 * @param cellNode a cellNode part of the table view
 *
 * @returns an indexPath for this cellNode
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;

/**
 * Similar to -visibleCells.
 *
 * @returns an array containing the cell nodes being displayed on screen.
 */
- (NSArray<ASCellNode *> *)visibleNodes;

/**
 * YES to automatically adjust the contentOffset when cells are inserted or deleted "before"
 * visible cells, maintaining the users' visible scroll position. Currently this feature tracks insertions, moves and deletions of
 * cells, but section edits are ignored.
 *
 * default is NO.
 */
@property (nonatomic) BOOL automaticallyAdjustsContentOffset;

/**
 * Triggers all loaded ASCellNodes to destroy displayed contents (freeing a lot of memory).
 *
 * @discussion This method should only be called by ASTableNode.  To be removed in a later release.
 */
- (void)clearContents;

/**
 * Triggers all loaded ASCellNodes to purge any data fetched from the network or disk (freeing memory).
 *
 * @discussion This method should only be called by ASTableNode.  To be removed in a later release.
 */
- (void)clearFetchedData;

@end


/**
 * This is a node-based UITableViewDataSource.
 */
@protocol ASTableDataSource <ASCommonTableViewDataSource, NSObject>

@optional

/**
 * Similar to -tableView:cellForRowAtIndexPath:.
 *
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath. This will be called on the main thread and should not implement reuse (it will be called once per row). Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath;


/**
 * Similar to -tableView:nodeForRowAtIndexPath:
 * This method takes precedence over tableView:nodeForRowAtIndexPath: if implemented.
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a block that creates the node for display at this indexpath.  
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath;

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

@protocol ASTableViewDataSource <ASTableDataSource>
@end

/**
 * This is a node-based UITableViewDelegate.
 *
 * Note that -tableView:heightForRowAtIndexPath: has been removed; instead, your custom ASCellNode subclasses are
 * responsible for deciding their preferred onscreen height in -calculateSizeThatFits:.
 */
@protocol ASTableDelegate <ASCommonTableViewDelegate, NSObject>

@optional

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
 */
- (void)tableView:(ASTableView *)tableView willDisplayNodeForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Informs the delegate that the table view did remove the provided node from the view hierarchy.
 * This may be caused by the node scrolling out of view, or by deleting the row
 * or its containing section with @c deleteRowsAtIndexPaths:withRowAnimation: or @c deleteSections:withRowAnimation: .
 *
 * @param tableView The sender.
 * @param node The node which was removed from the view hierarchy.
 * @param indexPath The index path at which the node was located before the removal.
 */
- (void)tableView:(ASTableView *)tableView didEndDisplayingNode:(ASCellNode *)node forRowAtIndexPath:(NSIndexPath *)indexPath;

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
- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context;

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
- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView;

/**
 * Provides the constrained size range for measuring the row at the index path.
 * Note: the widths in the returned size range are ignored!
 * 
 * @param tableView The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @returns A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)tableView:(ASTableView *)tableView constrainedSizeForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Informs the delegate that the table view did remove the node which was previously
 * at the given index path from the view hierarchy.
 *
 * @warning AsyncDisplayKit processes table view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 *
 * This method is deprecated. Use @c tableView:didEndDisplayingNode:forRowAtIndexPath: instead.
 */
- (void)tableView:(ASTableView *)tableView didEndDisplayingNodeForRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

@end

@protocol ASTableViewDelegate <ASTableDelegate>
@end

@interface ASTableView (Deprecated)

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

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

#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASTableView.h>


NS_ASSUME_NONNULL_BEGIN

@protocol ASTableDataSource;
@protocol ASTableDelegate;
@class ASTableView, ASBatchContext;

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode <ASRangeControllerUpdateRangeProtocol>

- (instancetype)init; // UITableViewStylePlain
- (instancetype)initWithStyle:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;

@property (strong, nonatomic, readonly) ASTableView *view;

// These properties can be set without triggering the view to be created, so it's fine to set them in -init.
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;

/*
 * A Boolean value that determines whether the table will be flipped.
 * If the value of this property is YES, the first cell node will be at the bottom of the table (as opposed to the top by default). This is useful for chat/messaging apps. The default value is NO.
 */
@property (nonatomic, assign) BOOL inverted;
/*
 * A Boolean value that determines whether users can select a row.
 * If the value of this property is YES (the default), users can select rows. If you set it to NO, they cannot select rows. Setting this property affects cell selection only when the table view is not in editing mode. If you want to restrict selection of cells in editing mode, use `allowsSelectionDuringEditing`.
 */
@property (nonatomic, assign) BOOL allowsSelection;
/*
 * A Boolean value that determines whether users can select cells while the table view is in editing mode.
 * If the value of this property is YES, users can select rows during editing. The default value is NO. If you want to restrict selection of cells regardless of mode, use allowsSelection.
 */
@property (nonatomic, assign) BOOL allowsSelectionDuringEditing;
/*
 * A Boolean value that determines whether users can select more than one row outside of editing mode.
 * This property controls whether multiple rows can be selected simultaneously outside of editing mode. When the value of this property is YES, each row that is tapped acquires a selected appearance. Tapping the row again removes the selected appearance. If you access indexPathsForSelectedRows, you can get the index paths that identify the selected rows.
 */
@property (nonatomic, assign) BOOL allowsMultipleSelection;
/*
 * A Boolean value that controls whether users can select more than one cell simultaneously in editing mode.
 * The default value of this property is NO. If you set it to YES, check marks appear next to selected rows in editing mode. In addition, UITableView does not query for editing styles when it goes into editing mode. If you access indexPathsForSelectedRows, you can get the index paths that identify the selected rows.
 */
@property (nonatomic, assign) BOOL allowsMultipleSelectionDuringEditing;

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
 * Scrolls the table to the given row.
 *
 * @param indexPath The index path of the row.
 * @param scrollPosition Where the row should end up after the scroll.
 * @param animated Whether the scroll should be animated or not.
 *
 * This method must be called on the main thread.
 */
- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadData;

/**
 * Triggers a relayout of all nodes.
 *
 * @discussion This method invalidates and lays out every cell node in the table view.
 */
- (void)relayoutItems;

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
- (void)performBatchAnimated:(BOOL)animated updates:(nullable AS_NOESCAPE void (^)())updates completion:(nullable void (^)(BOOL finished))completion;

/**
 *  Perform a batch of updates asynchronously, optionally disabling all animations in the batch. This method must be called from the main thread.
 *  The data source must be updated to reflect the changes before the update block completes.
 *
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchUpdates:(nullable AS_NOESCAPE void (^)())updates completion:(nullable void (^)(BOOL finished))completion;

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

#pragma mark - Selection

/**
 * Selects a row in the table view identified by index path, optionally scrolling the row to a location in the table view.
 * This method does not cause any selection-related delegate methods to be called.
 *
 * @param indexPath An index path identifying a row in the table view.
 *
 * @param animated Specify YES to animate the change in the selection or NO to make the change without animating it.
 *
 * @param scrollPosition A constant that identifies a relative position in the table view (top, middle, bottom) for the row when scrolling concludes. See `UITableViewScrollPosition` for descriptions of valid constants.
 *
 * @discussion This method must be called from the main thread.
 */
- (void)selectRowAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition;

/*
 * Deselects a given row identified by index path, with an option to animate the deselection.
 * This method does not cause any selection-related delegate methods to be called.
 * Calling this method does not cause any scrolling to the deselected row.
 *
 * @param indexPath An index path identifying a row in the table view.
 *
 * @param animated Specify YES to animate the change in the selection or NO to make the change without animating it.
 *
 * @discussion This method must be called from the main thread.
 */
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

#pragma mark - Querying Data

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
 * Similar to -visibleCells.
 *
 * @return an array containing the nodes being displayed on screen. This must be called on the main thread.
 */
@property (nonatomic, readonly) NSArray<__kindof ASCellNode *> *visibleNodes;

/**
 * Retrieves the node for the row at the given index path.
 */
- (nullable __kindof ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

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

/**
 * Similar to -[UITableView rectForRowAtIndexPath:]
 *
 * @param indexPath An index path identifying a row in the table view.
 *
 * @return A rectangle defining the area in which the table view draws the row or CGRectZero if indexPath is invalid.
 *
 * @discussion This method must be called from the main thread.
 */
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Similar to -[UITableView cellForRowAtIndexPath:]
 *
 * @param indexPath An index path identifying a row in the table view.
 *
 * @return An object representing a cell of the table, or nil if the cell is not visible or indexPath is out of range.
 *
 * @discussion This method must be called from the main thread.
 */
- (nullable __kindof UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Similar to UITableView.indexPathForSelectedRow
 *
 * @return The value of this property is an index path identifying the row and section
 *   indexes of the selected row, or nil if the index path is invalid. If there are multiple selections,
 *   this property contains the first index-path object in the array of row selections;
 *   this object has the lowest index values for section and row.
 *
 * @discussion This method must be called from the main thread.
 */
@property (nonatomic, readonly, nullable) NSIndexPath *indexPathForSelectedRow;

@property (nonatomic, readonly, nullable) NSArray<NSIndexPath *> *indexPathsForSelectedRows;

/**
 * Similar to -[UITableView indexPathForRowAtPoint:]
 *
 * @param point A point in the local coordinate system of the table view (the table view’s bounds).
 *
 * @return An index path representing the row and section associated with point, 
 *  or nil if the point is out of the bounds of any row.
 *
 * @discussion This method must be called from the main thread.
 */
- (nullable NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point AS_WARN_UNUSED_RESULT;

/**
 * Similar to -[UITableView indexPathsForRowsInRect:]
 *
 * @param rect A rectangle defining an area of the table view in local coordinates.
 *
 * @return An array of NSIndexPath objects each representing a row and section index identifying a row within rect.
 *  Returns an empty array if there aren’t any rows to return.
 *
 * @discussion This method must be called from the main thread.
 */
- (nullable NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect AS_WARN_UNUSED_RESULT;

/**
 * Similar to -[UITableView indexPathsForVisibleRows]
 *
 * @return The value of this property is an array of NSIndexPath objects each representing a row index and section index
 *  that together identify a visible row in the table view. If no rows are visible, the value is nil.
 *
 * @discussion This method must be called from the main thread.
 */
- (NSArray<NSIndexPath *> *)indexPathsForVisibleRows AS_WARN_UNUSED_RESULT;

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
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @return a node for display at this indexpath. This will be called on the main thread and should not implement reuse (it will be called once per row). Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

/**
 * Indicator to lock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)tableViewLockDataSource:(ASTableView *)tableView ASDISPLAYNODE_DEPRECATED_MSG("Data source accesses are on the main thread. Method will not be called.");

/**
 * Indicator to unlock the data source for data fetching in asyn mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)tableViewUnlockDataSource:(ASTableView *)tableView ASDISPLAYNODE_DEPRECATED_MSG("Data source accesses are on the main thread. Method will not be called.");

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

- (nullable NSIndexPath *)tableNode:(ASTableNode *)tableNode willSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (nullable NSIndexPath *)tableNode:(ASTableNode *)tableNode willDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)tableNode:(ASTableNode *)tableNode didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)tableNode:(ASTableNode *)tableNode shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableNode:(ASTableNode *)tableNode didHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableNode:(ASTableNode *)tableNode didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)tableNode:(ASTableNode *)tableNode shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableNode:(ASTableNode *)tableNode canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender;
- (void)tableNode:(ASTableNode *)tableNode performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender;

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
 * @param tableNode The sender.
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
 * @param tableNode The sender.
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
- (void)tableView:(ASTableView *)tableView willDisplayNode:(ASCellNode *)node forRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (void)tableView:(ASTableView *)tableView didEndDisplayingNode:(ASCellNode *)node forRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (BOOL)shouldBatchFetchForTableView:(ASTableView *)tableView AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (ASSizeRange)tableView:(ASTableView *)tableView constrainedSizeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

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
- (void)tableView:(ASTableView *)tableView willDisplayNodeForRowAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASTableNode's method instead.");

@end

NS_ASSUME_NONNULL_END

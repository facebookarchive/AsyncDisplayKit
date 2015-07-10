/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASTableViewProtocols.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASBatchContext.h>


@class ASCellNode;
@protocol ASTableViewDataSource;
@protocol ASTableViewDelegate;


/**
 * Node-based table view.
 *
 * ASTableView is a version of UITableView that uses nodes -- specifically, ASCellNode subclasses -- with asynchronous
 * pre-rendering instead of synchronously loading UITableViewCells.
 */
@interface ASTableView : UITableView

@property (nonatomic, weak) id<ASTableViewDataSource> asyncDataSource;
@property (nonatomic, weak) id<ASTableViewDelegate> asyncDelegate;      // must not be nil

/**
 * Tuning parameters for a range.
 *
 * @param rangeType The range to get the tuning parameters for.
 *
 * @returns A tuning parameter value for the given range.
 *
 * Defaults to the render range having one sceenful both leading and trailing and the preload range having two 
 * screenfuls in both directions.
 */
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType;

/**
 * Set the tuning parameters for a range.
 *
 * @param tuningParameters The tuning parameters to store for a range.
 * @param rangeType The range to set the tuning parameters for.
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

/**
 * Initializer.
 *
 * @param frame A rectangle specifying the initial location and size of the table view in its superview’s coordinates. 
 * The frame of the table view changes as table cells are added and deleted.
 *
 * @param style A constant that specifies the style of the table view. See UITableViewStyle for descriptions of valid constants.
 *
 * @param asyncDataFetchingEnabled Enable the data fetching in async mode.
 * 
 * @discussion If asyncDataFetching is enabled, the `ASTableView` will fetch data through `tableView:numberOfRowsInSection:` and
 * `tableView:nodeForRowAtIndexPath:` in async mode from background thread. Otherwise, the methods will be invoked synchronically 
 * from calling thread.
 * Enabling asyncDataFetching could avoid blocking main thread for `ASCellNode` allocation, which is frequently reported issue for 
 * large scale data. On another hand, the application code need take the responsibility to avoid data inconsistence. Specifically, 
 * we will lock the data source through `tableViewLockDataSource`, and unlock it by `tableViewUnlockDataSource` after the data fetching. 
 * The application should not update the data source while the data source is locked, to keep data consistence.
 */
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled;

/**
 * The number of screens left to scroll before the delegate -tableView:beginBatchFetchingWithContext: is called.
 *
 * Defaults to one screenful.
 */
@property (nonatomic, assign) CGFloat leadingScreensForBatching;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on 
 * the main thread.
 * @warning This method is substantially more expensive than UITableView's version.
 */
-(void)reloadDataWithCompletion:(void (^)())completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UITableView's version.
 */
- (void)reloadData;


/**
 * We don't support the these methods for animation yet.
 *
 * TODO: support animations.
 */
- (void)beginUpdates;
- (void)endUpdates;

/**
 * Section updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the UI collection
 * view will be updated asynchronously. The asyncDataSource must be updated to reflect the changes before these methods are called.
 */
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Row updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the UI collection
 * view will be updated asynchronously. The asyncDataSource must be updated to reflect the changes before these methods are called.
 */
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
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
 * Similar to -visibleCells.
 *
 * @returns an array containing the nodes being displayed on screen.
 */
- (NSArray *)visibleNodes;

@end


/**
 * This is a node-based UITableViewDataSource.
 */
@protocol ASTableViewDataSource <ASCommonTableViewDataSource, NSObject>

/**
 * Similar to -tableView:cellForRowAtIndexPath:.
 *
 * @param tableView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath.  Must be thread-safe (can be called on the main thread or a background
 * queue) and should not implement reuse (it will be called once per row).  Unlike UITableView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath;

@optional

/**
 * Indicator to lock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistence or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 */
- (void)tableViewLockDataSource:(ASTableView *)tableView;

/**
 * Indicator to unlock the data source for data fetching in asyn mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistence or exception
 * due to the data access in async mode.
 *
 * @param tableView The sender.
 */
- (void)tableViewUnlockDataSource:(ASTableView *)tableView;

@end


/**
 * This is a node-based UITableViewDelegate.
 *
 * Note that -tableView:heightForRowAtIndexPath: has been removed; instead, your custom ASCellNode subclasses are
 * responsible for deciding their preferred onscreen height in -calculateSizeThatFits:.
 */
@protocol ASTableViewDelegate <ASCommonTableViewDelegate, NSObject>

@optional

- (void)tableView:(ASTableView *)tableView willDisplayNodeForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(ASTableView *)tableView didEndDisplayingNodeForRowAtIndexPath:(NSIndexPath*)indexPath;

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

@end

@interface ASTableView (Deprecated)

@property (nonatomic, assign) ASRangeTuningParameters rangeTuningParameters ASDISPLAYNODE_DEPRECATED;

@end

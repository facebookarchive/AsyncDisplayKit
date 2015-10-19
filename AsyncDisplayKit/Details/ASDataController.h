/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDealloc2MainObject.h>
#import <AsyncDisplayKit/ASDimension.h>
#import "ASFlowLayoutController.h"

@class ASCellNode;
@class ASDataController;

FOUNDATION_EXPORT NSString * const ASDataControllerRowNodeKind;

typedef NSUInteger ASDataControllerAnimationOptions;

/**
 Data source for data controller
 It will be invoked in the same thread as the api call of ASDataController.
 */
@protocol ASDataControllerSource <NSObject>

/**
 Fetch the ASCellNode for specific index path.
 */
- (ASCellNode *)dataController:(ASDataController *)dataController nodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 The constrained size range for layout.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 Fetch the number of rows in specific section.
 */
- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section;

/**
 Fetch the number of sections.
 */
- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController;

/**
 Lock the data source for data fetching.
 */
- (void)dataControllerLockDataSource;

/**
 Unlock the data source after data fetching.
 */
- (void)dataControllerUnlockDataSource;

@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

@optional

/**
 Called for batch update.
 */
- (void)dataControllerBeginUpdates:(ASDataController *)dataController;
- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion;

/**
 Called for insertion of elements.
 */
- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for deletion of elements.
 */
- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for insertion of sections.
 */
- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for deletion of sections.
 */
- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

@end

/**
 * Controller to layout data in background, and managed data updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the data
 * will be updated asynchronously. The dataSource must be updated to reflect the changes before these methods has been called.
 * For each data updating, the corresponding methods in delegate will be called.
 */
@protocol ASFlowLayoutControllerDataSource;
@interface ASDataController : ASDealloc2MainObject <ASFlowLayoutControllerDataSource>

/**
 Data source for fetching data info.
 */
@property (nonatomic, weak) id<ASDataControllerSource> dataSource;

/**
 Delegate to notify when data is updated.
 */
@property (nonatomic, weak) id<ASDataControllerDelegate> delegate;

/**
 *  Designated initializer.
 *
 * @param asyncDataFetchingEnabled Enable the data fetching in async mode.
 *
 * @discussion If enabled, we will fetch data through `dataController:nodeAtIndexPath:` and `dataController:rowsInSection:` in background thread.
 * Otherwise, the methods will be invoked synchronically in calling thread. Enabling data fetching in async mode could avoid blocking main thread
 * while allocating cell on main thread, which is frequently reported issue for handling large scale data. On another hand, the application code
 * will take the responsibility to avoid data inconsistence. Specifically, we will lock the data source through `dataControllerLockDataSource`,
 * and unlock it by `dataControllerUnlockDataSource` after the data fetching. The application should not update the data source while
 * the data source is locked.
 */
- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled;

/** @name Initial loading
 *
 * @discussion This method allows choosing an animation style for the first load of content.  It is typically used just once,
 * for example in viewWillAppear:, to specify an animation option for the information already present in the asyncDataSource.
 */

- (void)initialDataLoadingWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/** @name Data Updating */

- (void)beginUpdates;

- (void)endUpdates;

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion;

- (void)insertSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)deleteSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 * Re-measures all loaded nodes in the backing store.
 * 
 * @discussion Used to respond to a change in size of the containing view
 * (e.g. ASTableView or ASCollectionView after an orientation change).
 */
- (void)relayoutAllNodes;

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions completion:(void (^)())completion;

- (void)reloadDataImmediatelyWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/** @name Data Querying */

- (NSUInteger)numberOfSections;

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths;

/**
 * Direct access to the nodes that have completed calculation and layout
 */
- (NSArray *)completedNodes;

@end

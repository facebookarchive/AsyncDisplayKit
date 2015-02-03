/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASCollectionViewProtocols.h>
#import <AsyncDisplayKit/ASBaseDefines.h>


@class ASCellNode;
@protocol ASCollectionViewDataSource;
@protocol ASCollectionViewDelegate;


/**
 * Node-based collection view.
 *
 * ASCollectionView is a version of UICollectionView that uses nodes -- specifically, ASCellNode subclasses -- with asynchronous
 * pre-rendering instead of synchronously loading UICollectionViewCells.
 */
@interface ASCollectionView : UICollectionView

@property (nonatomic, weak) id<ASCollectionViewDataSource> asyncDataSource;
@property (nonatomic, weak) id<ASCollectionViewDelegate> asyncDelegate;

/**
 * Tuning parameters for a range.
 *
 * @param range The range to get the tuning parameters for.
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
 * @param range The range to set the tuning parameters for.
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

/**
 * Initializer.
 *
 * @discussion If asyncDataFetching is enabled, the `AScollectionView` will fetch data through `collectionView:numberOfRowsInSection:` and
 * `collectionView:nodeForRowAtIndexPath:` in async mode from background thread. Otherwise, the methods will be invoked synchronically
 * from calling thread.
 * Enabling asyncDataFetching could avoid blocking main thread for `ASCellNode` allocation, which is frequently reported issue for
 * large scale data. On another hand, the application code need take the responsibility to avoid data inconsistence. Specifically,
 * we will lock the data source through `collectionViewLockDataSource`, and unlock it by `collectionViewUnlockDataSource` after the data fetching.
 * The application should not update the data source while the data source is locked, to keep data consistence.
 */
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout asyncDataFetching:(BOOL)asyncDataFetchingEnabled;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData;

/**
 * Section updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the UI table
 * view will be updated asynchronously. The asyncDataSource must be updated to reflect the changes before these methods are called.
 */
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;
- (void)reloadSections:(NSIndexSet *)sections;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Items updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the UI table
 * view will be updated asynchronously. The asyncDataSource must be updated to reflect the changes before these methods are called.
 */
- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths;
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

/**
 * Similar to -cellForItemAtIndexPath:.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath.
 */
- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -visibleCells.
 *
 * @returns an array containing the nodes being displayed on screen.
 */
- (NSArray *)visibleNodes;

/**
 * Query the sized node at `indexPath` for its calculatedSize.
 *
 * @param indexPath The index path for the node of interest.
 */
- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

@end


/**
 * This is a node-based UICollectionViewDataSource.
 */
@protocol ASCollectionViewDataSource <ASCommonCollectionViewDataSource, NSObject>

/**
 * Similar to -collectionView:cellForItemAtIndexPath:.
 *
 * @param collection The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath.  Must be thread-safe (can be called on the main thread or a background
 * queue) and should not implement reuse (it will be called once per row).  Unlike UICollectionView's version, this method
 * is not called when the row is about to display.
 */
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Indicator to lock the data source for data fetching in asyn mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistence or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 */
- (void)collectionViewLockDataSource:(ASCollectionView *)collectionView;

/**
 * Indicator to unlock the data source for data fetching in asyn mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistence or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 */
- (void)collectionViewUnlockDataSource:(ASCollectionView *)collectionView;

@end


/**
 * This is a node-based UICollectionViewDelegate.
 */
@protocol ASCollectionViewDelegate <ASCommonCollectionViewDelegate, NSObject>

@optional

- (void)collectionView:(ASCollectionView *)collectionView willDisplayNodeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(ASCollectionView *)collectionView didEndDisplayingNodeForItemAtIndexPath:(NSIndexPath*)indexPath;

@end

@interface ASCollectionView (Deprecated)

@property (nonatomic, assign) ASRangeTuningParameters rangeTuningParameters ASDISPLAYNODE_DEPRECATED;

@end

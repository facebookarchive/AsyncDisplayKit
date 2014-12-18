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
 * Tuning parameters for the working range.
 *
 * Defaults to a trailing buffer of one screenful and a leading buffer of two screenfuls.
 */
@property (nonatomic, assign) ASRangeTuningParameters rangeTuningParameters;

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

@end


/**
 * This is a node-based UICollectionViewDelegate.
 */
@protocol ASCollectionViewDelegate <ASCommonCollectionViewDelegate, NSObject>

@optional

- (void)collectionView:(UICollectionView *)collectionView willDisplayNodeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingNodeForItemAtIndexPath:(NSIndexPath*)indexPath;

@end

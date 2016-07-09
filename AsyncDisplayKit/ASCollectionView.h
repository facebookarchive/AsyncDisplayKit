//
//  ASCollectionView.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASCollectionViewProtocols.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASBatchContext.h>

@class ASCellNode;
@class ASCollectionNode;
@protocol ASCollectionDataSource;
@protocol ASCollectionDelegate;
@protocol ASCollectionViewLayoutInspecting;

NS_ASSUME_NONNULL_BEGIN

/**
 * Asynchronous UICollectionView with Intelligent Preloading capabilities.
 *
 * ASCollectionNode is recommended over ASCollectionView.  This class exists for adoption convenience.
 *
 * ASCollectionView is a true subclass of UICollectionView, meaning it is pointer-compatible
 * with code that currently uses UICollectionView.
 *
 * The main difference is that asyncDataSource expects -nodeForItemAtIndexPath, an ASCellNode, and
 * the sizeForItemAtIndexPath: method is eliminated (as are the performance problems caused by it).
 * This is made possible because ASCellNodes can calculate their own size, and preload ahead of time.
 */
@interface ASCollectionView : UICollectionView

/**
 * Initializer.
 *
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout;
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout;

// The corresponding ASCollectionNode, which exists even if directly allocating & handling the view class.
@property (nonatomic, weak, readonly) ASCollectionNode *collectionNode;

@property (nonatomic, weak) id<ASCollectionDelegate>   asyncDelegate;
@property (nonatomic, weak) id<ASCollectionDataSource> asyncDataSource;

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
 * The number of screens left to scroll before the delegate -collectionView:beginBatchFetchingWithContext: is called.
 *
 * Defaults to two screenfuls.
 */
@property (nonatomic, assign) CGFloat leadingScreensForBatching;

/**
 * Optional introspection object for the collection view's layout.
 *
 * @discussion Since supplementary and decoration views are controlled by the collection view's layout, this object
 * is used as a bridge to provide information to the internal data controller about the existence of these views and
 * their associated index paths. For collection views using `UICollectionViewFlowLayout`, a default inspector
 * implementation `ASCollectionViewFlowLayoutInspector` is created and set on this property by default. Custom
 * collection view layout subclasses will need to provide their own implementation of an inspector object for their
 * supplementary views to be compatible with `ASCollectionView`'s supplementary node support.
 */
@property (nonatomic, weak) id<ASCollectionViewLayoutInspecting> layoutInspector;

/**
 *  Perform a batch of updates asynchronously, optionally disabling all animations in the batch. This method must be called from the main thread. 
 *  The asyncDataSource must be updated to reflect the changes before the update block completes.
 *
 *  @param animated   NO to disable animations for this batch
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single 
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or 
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchAnimated:(BOOL)animated updates:(void (^ _Nullable)())updates completion:(void (^ _Nullable)(BOOL))completion;

/**
 *  Perform a batch of updates asynchronously.  This method must be called from the main thread.
 *  The asyncDataSource must be updated to reflect the changes before update block completes.
 *
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchUpdates:(void (^ _Nullable)())updates completion:(void (^ _Nullable)(BOOL))completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadDataWithCompletion:(void (^ _Nullable)())completion;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData;

/**
 * Reload everything from scratch entirely on the main thread, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version and will block the main thread
 * while all the cells load.
 */
- (void)reloadDataImmediately;

/**
 * Triggers a relayout of all nodes.
 *
 */
- (void)relayoutItems;

/**
 *  Blocks execution of the main thread until all section and row updates are committed. This method must be called from the main thread.
 */
- (void)waitUntilAllUpdatesAreCommitted;

/**
 * Registers the given kind of supplementary node for use in creating node-backed supplementary views.
 *
 * @param elementKind The kind of supplementary node that will be requested through the data source.
 *
 * @discussion Use this method to register support for the use of supplementary nodes in place of the default
 * `registerClass:forSupplementaryViewOfKind:withReuseIdentifier:` and `registerNib:forSupplementaryViewOfKind:withReuseIdentifier:`
 * methods. This method will register an internal backing view that will host the contents of the supplementary nodes
 * returned from the data source.
 */
- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind;

/**
 * Inserts one or more sections.
 *
 * @param sections An index set that specifies the sections to insert.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertSections:(NSIndexSet *)sections;

/**
 * Deletes one or more sections.
 *
 * @param sections An index set that specifies the sections to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteSections:(NSIndexSet *)sections;

/**
 * Reloads the specified sections.
 *
 * @param sections An index set that specifies the sections to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadSections:(NSIndexSet *)sections;

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
 * Inserts items at the locations identified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects, each representing an item index and section index that together identify an item.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Deletes the items specified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Reloads the specified items.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Moves the item at a specified location to a destination location.
 *
 * @param indexPath The index path identifying the item to move.
 *
 * @param newIndexPath The index path that is the destination of the move for the item.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

/**
 * Similar to -cellForItemAtIndexPath:.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath or nil
 */
- (nullable ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath;


/**
 * Similar to -supplementaryViewForElementKind:atIndexPath:
 *
 * @param elementKind The kind of supplementary node to locate.
 * @param indexPath The index path of the requested supplementary node.
 *
 * @returns The specified supplementary node or nil
 */
- (nullable ASCellNode *)supplementaryNodeForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -indexPathForCell:.
 *
 * @param cellNode a cellNode part of the table view
 *
 * @returns an indexPath for this cellNode
 */
- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;

/**
 * Similar to -visibleCells.
 *
 * @returns an array containing the nodes being displayed on screen.
 */
- (NSArray<ASCellNode *> *)visibleNodes;

/**
 * Query the sized node at `indexPath` for its calculatedSize.
 *
 * @param indexPath The index path for the node of interest.
 */
- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Determines collection view's current scroll direction. Supports 2-axis collection views.
 *
 * @returns a bitmask of ASScrollDirection values.
 */
- (ASScrollDirection)scrollDirection;

/**
 * Determines collection view's scrollable directions.
 *
 * @returns a bitmask of ASScrollDirection values.
 */
- (ASScrollDirection)scrollableDirections;

/**
 * Triggers all loaded ASCellNodes to destroy displayed contents (freeing a lot of memory).
 *
 * @discussion This method should only be called by ASCollectionNode.  To be removed in a later release.
 */
- (void)clearContents;

/**
 * Triggers all loaded ASCellNodes to purge any data fetched from the network or disk (freeing memory).
 *
 * @discussion This method should only be called by ASCollectionNode.  To be removed in a later release.
 */
- (void)clearFetchedData;

/**
 * Forces the .contentInset to be UIEdgeInsetsZero.
 *
 * @discussion By default, UIKit sets the top inset to the navigation bar height, even for horizontally
 * scrolling views.  This can only be disabled by setting a property on the containing UIViewController,
 * automaticallyAdjustsScrollViewInsets, which may not be accessible.  ASPagerNode uses this to ensure
 * its flow layout behaves predictably and does not log undefined layout warnings.
 */
@property (nonatomic) BOOL zeroContentInsets;

@end


/**
 * This is a node-based UICollectionViewDataSource.
 */
#define ASCollectionViewDataSource ASCollectionDataSource
@protocol ASCollectionDataSource <ASCommonCollectionViewDataSource>

@optional

/**
 * Similar to -collectionView:cellForItemAtIndexPath:.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a node for display at this indexpath. This will be called on the main thread and should
 *   not implement reuse (it will be called once per row).  Unlike UICollectionView's version,
 *   this method is not called when the row is about to display.
 */
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -collectionView:nodeForItemAtIndexPath:
 * This method takes precedence over collectionView:nodeForItemAtIndexPath: if implemented.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @returns a block that creates the node for display at this indexpath.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the collection view to provide a supplementary node to display in the collection view.
 *
 * @param collectionView An object representing the collection view requesting this information.
 * @param kind           The kind of supplementary node to provide.
 * @param indexPath      The index path that specifies the location of the new supplementary node.
 */
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Provides the constrained size range for measuring the node at the index path.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @returns A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Indicator to lock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)collectionViewLockDataSource:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED;

/**
 * Indicator to unlock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)collectionViewUnlockDataSource:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED;

@end


/**
 * This is a node-based UICollectionViewDelegate.
 */
#define ASCollectionViewDelegate ASCollectionDelegate
@protocol ASCollectionDelegate <ASCommonCollectionViewDelegate, NSObject>

@optional

/**
 * Informs the delegate that the collection view will add the node
 * at the given index path to the view hierarchy.
 *
 * @param collectionView The sender.
 * @param indexPath The index path of the item that will be displayed.
 *
 * @warning AsyncDisplayKit processes collection view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 */
- (void)collectionView:(ASCollectionView *)collectionView willDisplayNodeForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Informs the delegate that the collection view did remove the provided node from the view hierarchy.
 * This may be caused by the node scrolling out of view, or by deleting the item
 * or its containing section with @c deleteItemsAtIndexPaths: or @c deleteSections: .
 * 
 * @param collectionView The sender.
 * @param node The node which was removed from the view hierarchy.
 * @param indexPath The index path at which the node was located before it was removed.
 *
 * @warning AsyncDisplayKit processes collection view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 */
- (void)collectionView:(ASCollectionView *)collectionView didEndDisplayingNode:(ASCellNode *)node forItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Receive a message that the collectionView is near the end of its data set and more data should be fetched if 
 * necessary.
 *
 * @param collectionView The sender.
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 *
 * UICollectionView currently only supports batch events for tail loads. If you require a head load, consider
 * implementing a UIRefreshControl.
 */
- (void)collectionView:(ASCollectionView *)collectionView willBeginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * Tell the collectionView if batch fetching should begin.
 *
 * @param collectionView The sender.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the collectionView assumes that it should notify its asyncDelegate when batch fetching
 * should occur.
 */
- (BOOL)shouldBatchFetchForCollectionView:(ASCollectionView *)collectionView;

/**
 * Informs the delegate that the collection view did remove the node which was previously
 * at the given index path from the view hierarchy.
 *
 * @warning AsyncDisplayKit processes collection view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 *
 * This method is deprecated. Use @c collectionView:didEndDisplayingNode:forItemAtIndexPath: instead.
 */
- (void)collectionView:(ASCollectionView *)collectionView didEndDisplayingNodeForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

@end

/**
 * Defines methods that let you coordinate with a `UICollectionViewFlowLayout` in combination with an `ASCollectionView`.
 */
@protocol ASCollectionViewDelegateFlowLayout <ASCollectionViewDelegate>

@optional

/**
 * @discussion This method is deprecated and does nothing from 1.9.7 and up
 * Previously it applies the section inset to every cells within the corresponding section.
 * The expected behavior is to apply the section inset to the whole section rather than
 * shrinking each cell individually.
 * If you want this behavior, you can integrate your insets calculation into
 * `constrainedSizeForNodeAtIndexPath`
 * please file a github issue if you would like this to be restored.
 */
- (UIEdgeInsets)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section __deprecated_msg("This method does nothing for 1.9.7+ due to incorrect implementation previously, see the header file for more information.");

/**
 * Asks the delegate for the size of the header in the specified section.
 */
- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section;

/**
 * Asks the delegate for the size of the footer in the specified section.
 */
- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section;

@end

@interface ASCollectionView (Deprecated)

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout asyncDataFetching:(BOOL)asyncDataFetchingEnabled ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

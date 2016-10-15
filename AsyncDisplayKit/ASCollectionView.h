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
@protocol ASSectionContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * Asynchronous UICollectionView with Intelligent Preloading capabilities.
 *
 * @discussion ASCollectionView is a true subclass of UICollectionView, meaning it is pointer-compatible
 * with code that currently uses UICollectionView.
 *
 * The main difference is that asyncDataSource expects -nodeForItemAtIndexPath, an ASCellNode, and
 * the sizeForItemAtIndexPath: method is eliminated (as are the performance problems caused by it).
 * This is made possible because ASCellNodes can calculate their own size, and preload ahead of time.
 *
 * @note ASCollectionNode is strongly recommended over ASCollectionView.  This class exists for adoption convenience.
 */
@interface ASCollectionView : UICollectionView

/**
 * The object that acts as the asynchronous delegate of the collection view
 *
 * @discussion The delegate must adopt the ASCollectionDelegate protocol. The collection view maintains a weak reference to the delegate object.
 *
 * The delegate object is responsible for providing size constraints for nodes and indicating whether batch fetching should begin.
 */
@property (nonatomic, weak) id<ASCollectionDelegate>   asyncDelegate;

/**
 * The object that acts as the asynchronous data source of the collection view
 *
 * @discussion The datasource must adopt the ASCollectionDataSource protocol. The collection view maintains a weak reference to the datasource object.
 *
 * The datasource object is responsible for providing nodes or node creation blocks to the collection view.
 */
@property (nonatomic, weak) id<ASCollectionDataSource> asyncDataSource;

/**
 * Returns the corresponding ASCollectionNode
 *
 * @return collectionNode The corresponding ASCollectionNode, if one exists.
 */
@property (nonatomic, weak, readonly) ASCollectionNode *collectionNode;

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
 * Retrieves the node for the item at the given index path.
 *
 * @param indexPath The index path of the requested node.
 * @return The node at the given index path, or @c nil if no item exists at the specified path.
 */
- (nullable ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Similar to -supplementaryViewForElementKind:atIndexPath:
 *
 * @param elementKind The kind of supplementary node to locate.
 * @param indexPath The index path of the requested supplementary node.
 *
 * @return The specified supplementary node or @c nil.
 */
- (nullable ASCellNode *)supplementaryNodeForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Retrieves the context object for the given section, as provided by the data source in
 * the @c collectionNode:contextForSection: method. This method must be called on the main thread.
 *
 * @param section The section to get the context for.
 *
 * @return The context object, or @c nil if no context was provided.
 */
- (nullable id<ASSectionContext>)contextForSection:(NSInteger)section AS_WARN_UNUSED_RESULT;

/**
 * Determines collection view's current scroll direction. Supports 2-axis collection views.
 *
 * @return a bitmask of ASScrollDirection values.
 */
@property (nonatomic, readonly) ASScrollDirection scrollDirection;

/**
 * Determines collection view's scrollable directions.
 *
 * @return a bitmask of ASScrollDirection values.
 */
@property (nonatomic, readonly) ASScrollDirection scrollableDirections;

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

@interface ASCollectionView (Deprecated)

/**
 * Initializes an ASCollectionView
 *
 * @discussion Initializes and returns a newly allocated collection view object with the specified layout.
 *
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout ASDISPLAYNODE_DEPRECATED;

/**
 * Initializes an ASCollectionView
 *
 * @discussion Initializes and returns a newly allocated collection view object with the specified frame and layout.
 *
 * @param frame The frame rectangle for the collection view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This frame is passed to the superclass during initialization.
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout ASDISPLAYNODE_DEPRECATED;

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
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Set the tuning parameters for a range type in full mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType ASDISPLAYNODE_DEPRECATED;

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
- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

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
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType ASDISPLAYNODE_DEPRECATED;

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
- (void)performBatchAnimated:(BOOL)animated updates:(nullable __attribute((noescape)) void (^)())updates completion:(nullable void (^)(BOOL finished))completion ASDISPLAYNODE_DEPRECATED;

/**
 *  Perform a batch of updates asynchronously.  This method must be called from the main thread.
 *  The asyncDataSource must be updated to reflect the changes before update block completes.
 *
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchUpdates:(nullable __attribute((noescape)) void (^)())updates completion:(nullable void (^)(BOOL finished))completion ASDISPLAYNODE_DEPRECATED;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion ASDISPLAYNODE_DEPRECATED;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData ASDISPLAYNODE_DEPRECATED;

/**
 * Reload everything from scratch entirely on the main thread, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version and will block the main thread
 * while all the cells load.
 */
- (void)reloadDataImmediately ASDISPLAYNODE_DEPRECATED;

/**
 * Triggers a relayout of all nodes.
 *
 * @discussion This method invalidates and lays out every cell node in the collection.
 */
- (void)relayoutItems ASDISPLAYNODE_DEPRECATED;

/**
 *  Blocks execution of the main thread until all section and row updates are committed. This method must be called from the main thread.
 */
- (void)waitUntilAllUpdatesAreCommitted ASDISPLAYNODE_DEPRECATED;

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
- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind ASDISPLAYNODE_DEPRECATED;

/**
 * Inserts one or more sections.
 *
 * @param sections An index set that specifies the sections to insert.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED;

/**
 * Deletes one or more sections.
 *
 * @param sections An index set that specifies the sections to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED;

/**
 * Reloads the specified sections.
 *
 * @param sections An index set that specifies the sections to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED;

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
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection ASDISPLAYNODE_DEPRECATED;

/**
 * Inserts items at the locations identified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects, each representing an item index and section index that together identify an item.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED;

/**
 * Deletes the items specified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED;

/**
 * Reloads the specified items.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED;

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
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath ASDISPLAYNODE_DEPRECATED;

/**
 * Query the sized node at @c indexPath for its calculatedSize.
 *
 * @param indexPath The index path for the node of interest.
 *
 * This method is deprecated. Call @c calculatedSize on the node of interest instead. First deprecated in version 2.0.
 */
- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

/**
 * Similar to -visibleCells.
 *
 * @return an array containing the nodes being displayed on screen.
 */
- (NSArray<__kindof ASCellNode *> *)visibleNodes AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

/**
 * Similar to -indexPathForCell:.
 *
 * @param cellNode a cellNode in the collection view
 *
 * @return The index path for this cell node.
 *
 * @discussion This index path returned by this method is in the _view's_ index space
 *    and should only be used with @c ASCollectionView directly. To get an index path suitable
 *    for use with your data source and @c ASCollectionNode, call @c indexPathForNode: on the
 *    collection node instead.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

@end

ASDISPLAYNODE_DEPRECATED
@protocol ASCollectionViewDataSource <ASCollectionDataSource>
@end

ASDISPLAYNODE_DEPRECATED
@protocol ASCollectionViewDelegate <ASCollectionDelegate>
@end

/**
 * Defines methods that let you coordinate with a `UICollectionViewFlowLayout` in combination with an `ASCollectionView`.
 */
@protocol ASCollectionViewDelegateFlowLayout <ASCollectionDelegate>

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

NS_ASSUME_NONNULL_END

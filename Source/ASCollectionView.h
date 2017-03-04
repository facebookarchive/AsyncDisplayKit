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

#import <AsyncDisplayKit/ASCollectionViewProtocols.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASBatchContext.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

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
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode AS_WARN_UNUSED_RESULT;

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

/*
 * A Boolean value that determines whether the nodes that the data source renders will be flipped.
 */
@property (nonatomic, assign) BOOL inverted;

@end

@interface ASCollectionView (Deprecated)

/**
 * Forces the .contentInset to be UIEdgeInsetsZero.
 *
 * @discussion By default, UIKit sets the top inset to the navigation bar height, even for horizontally
 * scrolling views.  This can only be disabled by setting a property on the containing UIViewController,
 * automaticallyAdjustsScrollViewInsets, which may not be accessible.  ASPagerNode uses this to ensure
 * its flow layout behaves predictably and does not log undefined layout warnings.
 */
@property (nonatomic) BOOL zeroContentInsets ASDISPLAYNODE_DEPRECATED_MSG("Set automaticallyAdjustsScrollViewInsets=NO on your view controller instead.");

/**
 * The object that acts as the asynchronous delegate of the collection view
 *
 * @discussion The delegate must adopt the ASCollectionDelegate protocol. The collection view maintains a weak reference to the delegate object.
 *
 * The delegate object is responsible for providing size constraints for nodes and indicating whether batch fetching should begin.
 */
@property (nonatomic, weak) id<ASCollectionDelegate> asyncDelegate ASDISPLAYNODE_DEPRECATED_MSG("Please use ASCollectionNode's .delegate property instead.");

/**
 * The object that acts as the asynchronous data source of the collection view
 *
 * @discussion The datasource must adopt the ASCollectionDataSource protocol. The collection view maintains a weak reference to the datasource object.
 *
 * The datasource object is responsible for providing nodes or node creation blocks to the collection view.
 */
@property (nonatomic, weak) id<ASCollectionDataSource> asyncDataSource ASDISPLAYNODE_DEPRECATED_MSG("Please use ASCollectionNode's .dataSource property instead.");

/**
 * Initializes an ASCollectionView
 *
 * @discussion Initializes and returns a newly allocated collection view object with the specified layout.
 *
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout ASDISPLAYNODE_DEPRECATED_MSG("Please use ASCollectionNode instead of ASCollectionView.");

/**
 * Initializes an ASCollectionView
 *
 * @discussion Initializes and returns a newly allocated collection view object with the specified frame and layout.
 *
 * @param frame The frame rectangle for the collection view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This frame is passed to the superclass during initialization.
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout ASDISPLAYNODE_DEPRECATED_MSG("Please use ASCollectionNode instead of ASCollectionView.");

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
- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Set the tuning parameters for a range type in full mode.
 *
 * @param tuningParameters The tuning parameters to store for a range type.
 * @param rangeType The range type to set the tuning parameters for.
 *
 * @see ASLayoutRangeMode
 * @see ASLayoutRangeType
 */
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

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
- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

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
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

- (nullable __kindof UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

- (void)selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

@property (nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForVisibleItems ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode property instead.");

@property (nonatomic, readonly, nullable) NSArray<NSIndexPath *> *indexPathsForSelectedItems ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode property instead.");

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
- (void)performBatchAnimated:(BOOL)animated updates:(nullable AS_NOESCAPE void (^)())updates completion:(nullable void (^)(BOOL finished))completion ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 *  Perform a batch of updates asynchronously.  This method must be called from the main thread.
 *  The asyncDataSource must be updated to reflect the changes before update block completes.
 *
 *  @param updates    The block that performs the relevant insert, delete, reload, or move operations.
 *  @param completion A completion handler block to execute when all of the operations are finished. This block takes a single
 *                    Boolean parameter that contains the value YES if all of the related animations completed successfully or
 *                    NO if they were interrupted. This parameter may be nil. If supplied, the block is run on the main thread.
 */
- (void)performBatchUpdates:(nullable AS_NOESCAPE void (^)())updates completion:(nullable void (^)(BOOL finished))completion ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Reload everything from scratch entirely on the main thread, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version and will block the main thread
 * while all the cells load.
 */
- (void)reloadDataImmediately ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's -reloadDataWithCompletion: followed by -waitUntilAllUpdatesAreCommitted instead.");

/**
 * Triggers a relayout of all nodes.
 *
 * @discussion This method invalidates and lays out every cell node in the collection.
 */
- (void)relayoutItems ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 *  Blocks execution of the main thread until all section and row updates are committed. This method must be called from the main thread.
 */
- (void)waitUntilAllUpdatesAreCommitted ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

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
- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Inserts one or more sections.
 *
 * @param sections An index set that specifies the sections to insert.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Deletes one or more sections.
 *
 * @param sections An index set that specifies the sections to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Reloads the specified sections.
 *
 * @param sections An index set that specifies the sections to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadSections:(NSIndexSet *)sections ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

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
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Inserts items at the locations identified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects, each representing an item index and section index that together identify an item.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Deletes the items specified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to delete.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Reloads the specified items.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to reload.
 *
 * @discussion This method must be called from the main thread. The asyncDataSource must be updated to reflect the changes
 * before this method is called.
 */
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

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
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

/**
 * Query the sized node at @c indexPath for its calculatedSize.
 *
 * @param indexPath The index path for the node of interest.
 *
 * This method is deprecated. Call @c calculatedSize on the node of interest instead. First deprecated in version 2.0.
 */
- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Call -calculatedSize on the node of interest instead.");

/**
 * Similar to -visibleCells.
 *
 * @return an array containing the nodes being displayed on screen.
 */
- (NSArray<__kindof ASCellNode *> *)visibleNodes AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode method instead.");

@end

ASDISPLAYNODE_DEPRECATED_MSG("Renamed to ASCollectionDataSource.")
@protocol ASCollectionViewDataSource <ASCollectionDataSource>
@end

ASDISPLAYNODE_DEPRECATED_MSG("Renamed to ASCollectionDelegate.")
@protocol ASCollectionViewDelegate <ASCollectionDelegate>
@end

/**
 * Defines methods that let you coordinate a `UICollectionViewFlowLayout` in combination with an `ASCollectionNode`.
 */
@protocol ASCollectionDelegateFlowLayout <ASCollectionDelegate>

@optional

/**
 * Asks the delegate for the inset that should be applied to the given section.
 *
 * @see the same method in UICollectionViewDelegate. 
 */
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section;

/**
 * Asks the delegate for the size range that should be used to measure the header in the given flow layout section.
 *
 * @param collectionNode The sender.
 * @param section The section.
 *
 * @return The size range for the header, or @c ASSizeRangeZero if there is no header in this section.
 *
 * If you want the header to completely determine its own size, return @c ASSizeRangeUnconstrained.
 *
 * @note Only the scrollable dimension of the returned size range will be used. In a vertical flow,
 * only the height will be used. In a horizontal flow, only the width will be used. The other dimension
 * will be constrained to fill the collection node.
 *
 * @discussion If you do not implement this method, ASDK will fall back to calling @c collectionView:layout:referenceSizeForHeaderInSection:
 * and using that as the exact constrained size. If you don't implement that method, ASDK will read the @c headerReferenceSize from the layout.
 */
- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode sizeRangeForHeaderInSection:(NSInteger)section;

/**
 * Asks the delegate for the size range that should be used to measure the footer in the given flow layout section.
 *
 * @param collectionNode The sender.
 * @param section The section.
 *
 * @return The size range for the footer, or @c ASSizeRangeZero if there is no footer in this section.
 *
 * If you want the footer to completely determine its own size, return @c ASSizeRangeUnconstrained.
 *
 * @note Only the scrollable dimension of the returned size range will be used. In a vertical flow,
 * only the height will be used. In a horizontal flow, only the width will be used. The other dimension
 * will be constrained to fill the collection node.
 *
 * @discussion If you do not implement this method, ASDK will fall back to calling @c collectionView:layout:referenceSizeForFooterInSection:
 * and using that as the exact constrained size. If you don't implement that method, ASDK will read the @c footerReferenceSize from the layout.
 */
- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode sizeRangeForFooterInSection:(NSInteger)section;

/**
 * Asks the delegate for the size of the header in the specified section.
 */
- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:sizeRangeForHeaderInSection: instead.");

/**
 * Asks the delegate for the size of the footer in the specified section.
 */
- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section ASDISPLAYNODE_DEPRECATED_MSG("Implement collectionNode:sizeRangeForFooterInSection: instead.");

@end

ASDISPLAYNODE_DEPRECATED_MSG("Renamed to ASCollectionDelegateFlowLayout.")
@protocol ASCollectionViewDelegateFlowLayout <ASCollectionDelegateFlowLayout>
@end

NS_ASSUME_NONNULL_END

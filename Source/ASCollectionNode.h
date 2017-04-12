//
//  ASCollectionNode.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UICollectionView.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASCollectionView.h>
#import <AsyncDisplayKit/ASBlockTypes.h>

@protocol ASCollectionViewLayoutFacilitatorProtocol;
@protocol ASCollectionDelegate;
@protocol ASCollectionDataSource;
@class ASCollectionView;

NS_ASSUME_NONNULL_BEGIN

/**
 * ASCollectionNode is a node based class that wraps an ASCollectionView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASCollectionNode : ASDisplayNode <ASRangeControllerUpdateRangeProtocol>

- (instancetype)init NS_UNAVAILABLE;

/**
 * Initializes an ASCollectionNode
 *
 * @discussion Initializes and returns a newly allocated collection node object with the specified layout.
 *
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout;

/**
 * Initializes an ASCollectionNode
 *
 * @discussion Initializes and returns a newly allocated collection node object with the specified frame and layout.
 *
 * @param frame The frame rectangle for the collection view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This frame is passed to the superclass during initialization.
 * @param layout The layout object to use for organizing items. The collection view stores a strong reference to the specified object. Must not be nil.
 */
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout;

/**
 * Returns the corresponding ASCollectionView
 *
 * @return view The corresponding ASCollectionView.
 */
@property (strong, nonatomic, readonly) ASCollectionView *view;

/**
 * The object that acts as the asynchronous delegate of the collection view
 *
 * @discussion The delegate must adopt the ASCollectionDelegate protocol. The collection view maintains a weak reference to the delegate object.
 *
 * The delegate object is responsible for providing size constraints for nodes and indicating whether batch fetching should begin.
 * @note This is a convenience method which sets the asyncDelegate on the collection node's collection view.
 */
@property (weak, nonatomic) id <ASCollectionDelegate>   delegate;

/**
 * The object that acts as the asynchronous data source of the collection view
 *
 * @discussion The datasource must adopt the ASCollectionDataSource protocol. The collection view maintains a weak reference to the datasource object.
 *
 * The datasource object is responsible for providing nodes or node creation blocks to the collection view.
 * @note This is a convenience method which sets the asyncDatasource on the collection node's collection view.
 */
@property (weak, nonatomic) id <ASCollectionDataSource> dataSource;

/*
 * A Boolean value that determines whether the collection node will be flipped.
 * If the value of this property is YES, the first cell node will be at the bottom of the collection node (as opposed to the top by default). This is useful for chat/messaging apps. The default value is NO.
 */
@property (nonatomic, assign) BOOL inverted;

/**
 * A Boolean value that indicates whether users can select items in the collection node.
 * If the value of this property is YES (the default), users can select items. If you want more fine-grained control over the selection of items, you must provide a delegate object and implement the appropriate methods of the UICollectionNodeDelegate protocol.
 */
@property (nonatomic, assign) BOOL allowsSelection;

/**
 * A Boolean value that determines whether users can select more than one item in the collection node.
 * This property controls whether multiple items can be selected simultaneously. The default value of this property is NO.
 * When the value of this property is YES, tapping a cell adds it to the current selection (assuming the delegate permits the cell to be selected). Tapping the cell again removes it from the selection.
 */
@property (nonatomic, assign) BOOL allowsMultipleSelection;

/**
 * The layout used to organize the node's items.
 *
 * @discussion Assigning a new layout object to this property causes the new layout to be applied (without animations) to the node’s items.
 */
@property (nonatomic, strong) UICollectionViewLayout *collectionViewLayout;

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
 * Scrolls the collection to the given item.
 *
 * @param indexPath The index path of the item.
 * @param scrollPosition Where the item should end up after the scroll.
 * @param animated Whether the scroll should be animated or not.
 *
 * This method must be called on the main thread.
 */
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;

#pragma mark - Editing

/**
 * Registers the given kind of supplementary node for use in creating node-backed supplementary elements.
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
 *  Blocks execution of the main thread until all section and item updates are committed to the view. This method must be called from the main thread.
 */
- (void)waitUntilAllUpdatesAreCommitted;

/**
 * Inserts one or more sections.
 *
 * @param sections An index set that specifies the sections to insert.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertSections:(NSIndexSet *)sections;

/**
 * Deletes one or more sections.
 *
 * @param sections An index set that specifies the sections to delete.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteSections:(NSIndexSet *)sections;

/**
 * Reloads the specified sections.
 *
 * @param sections An index set that specifies the sections to reload.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
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
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Inserts items at the locations identified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects, each representing an item index and section index that together identify an item.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Deletes the items specified by an array of index paths.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to delete.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Reloads the specified items.
 *
 * @param indexPaths An array of NSIndexPath objects identifying the items to reload.
 *
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
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
 * @discussion This method must be called from the main thread. The data source must be updated to reflect the changes
 * before this method is called.
 */
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @param completion block to run on completion of asynchronous loading or nil. If supplied, the block is run on
 * the main thread.
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadDataWithCompletion:(nullable void (^)())completion;


/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 */
- (void)reloadData;

/**
 * Triggers a relayout of all nodes.
 *
 * @discussion This method invalidates and lays out every cell node in the collection view.
 */
- (void)relayoutItems;

#pragma mark - Selection

/**
 * The index paths of the selected items, or @c nil if no items are selected.
 */
@property (nonatomic, readonly, nullable) NSArray<NSIndexPath *> *indexPathsForSelectedItems;

/**
 * Selects the item at the specified index path and optionally scrolls it into view.
 * If the `allowsSelection` property is NO, calling this method has no effect. If there is an existing selection with a different index path and the `allowsMultipleSelection` property is NO, calling this method replaces the previous selection.
 * This method does not cause any selection-related delegate methods to be called.
 *
 * @param indexPath The index path of the item to select. Specifying nil for this parameter clears the current selection.
 *
 * @param animated Specify YES to animate the change in the selection or NO to make the change without animating it.
 *
 * @param scrollPosition An option that specifies where the item should be positioned when scrolling finishes. For a list of possible values, see `UICollectionViewScrollPosition`.
 *
 * @discussion This method must be called from the main thread.
 */
- (void)selectItemAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition;

/**
 * Deselects the item at the specified index.
 * If the allowsSelection property is NO, calling this method has no effect.
 * This method does not cause any selection-related delegate methods to be called.
 *
 * @param indexPath The index path of the item to select. Specifying nil for this parameter clears the current selection.
 *
 * @param animated Specify YES to animate the change in the selection or NO to make the change without animating it.
 *
 * @discussion This method must be called from the main thread.
 */
- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

#pragma mark - Querying Data

/**
 * Retrieves the number of items in the given section.
 *
 * @param section The section.
 *
 * @return The number of items.
 */
- (NSInteger)numberOfItemsInSection:(NSInteger)section AS_WARN_UNUSED_RESULT;

/**
 * The number of sections.
 */
@property (nonatomic, readonly) NSInteger numberOfSections;

/**
 * Similar to -visibleCells.
 *
 * @return an array containing the nodes being displayed on screen. This must be called on the main thread.
 */
@property (nonatomic, readonly) NSArray<__kindof ASCellNode *> *visibleNodes;

/**
 * Retrieves the node for the item at the given index path.
 *
 * @param indexPath The index path of the requested item.
 *
 * @return The node for the given item, or @c nil if no item exists at the specified path.
 */
- (nullable __kindof ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Retrieve the index path for the item with the given node.
 *
 * @param cellNode A node for an item in the collection node.
 *
 * @return The indexPath for this item.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode AS_WARN_UNUSED_RESULT;

/**
 * Retrieve the index paths of all visible items.
 *
 * @return an array containing the index paths of all visible items. This must be called on the main thread.
 */
@property (nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForVisibleItems;

/**
 * Retrieve the index path of the item at the given point.
 *
 * @param point The point of the requested item.
 *
 * @return The indexPath for the item at the given point. This must be called on the main thread.
 */
- (nullable NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point AS_WARN_UNUSED_RESULT;

/**
 * Retrieve the cell at the given index path.
 *
 * @param indexPath The index path of the requested item.
 *
 * @return The cell for the given index path. This must be called on the main thread.
 */
- (nullable UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Retrieves the context object for the given section, as provided by the data source in
 * the @c collectionNode:contextForSection: method.
 *
 * @param section The section to get the context for.
 *
 * @return The context object, or @c nil if no context was provided.
 *
 * TODO: This method currently accepts @c section in the _view_ index space, but it should
 *   be in the node index space. To get the context in the view index space (e.g. for subclasses
 *   of @c UICollectionViewLayout, the user will call the same method on @c ASCollectionView.
 */
- (nullable id<ASSectionContext>)contextForSection:(NSInteger)section AS_WARN_UNUSED_RESULT;

@end

@interface ASCollectionNode (Deprecated)

/**
 * Reload everything from scratch, destroying the working range and all cached nodes.
 *
 * @warning This method is substantially more expensive than UICollectionView's version.
 *
 * @deprecated This method is deprecated in 2.0. Use @c reloadDataWithCompletion: and
 *   then @c waitUntilAllUpdatesAreCommitted instead.
 */
- (void)reloadDataImmediately ASDISPLAYNODE_DEPRECATED_MSG("Use -reloadData / -reloadDataWithCompletion: followed by -waitUntilAllUpdatesAreCommitted instead.");

@end

/**
 * This is a node-based UICollectionViewDataSource.
 */
@protocol ASCollectionDataSource <ASCommonCollectionDataSource>

@optional

/**
 * Asks the data source for the number of items in the given section of the collection node.
 *
 * @see @c collectionView:numberOfItemsInSection:
 */
- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section;

/**
 * Asks the data source for the number of sections in the collection node.
 *
 * @see @c numberOfSectionsInCollectionView:
 */
- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode;

/**
 * Similar to -collectionNode:nodeForItemAtIndexPath:
 * This method takes precedence over collectionNode:nodeForItemAtIndexPath: if implemented.
 *
 * @param collectionNode The sender.
 * @param indexPath The index path of the item.
 *
 * @return a block that creates the node for display for this item.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Similar to -collectionView:cellForItemAtIndexPath:.
 *
 * @param collectionNode The sender.
 * @param indexPath The index path of the item.
 *
 * @return A node to display for the given item. This will be called on the main thread and should
 *   not implement reuse (it will be called once per item).  Unlike UICollectionView's version,
 *   this method is not called when the item is about to display.
 */
- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForItemAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the data source to provide a node-block to display for the given supplementary element in the collection view.
 *
 * @param collectionNode The sender.
 * @param kind           The kind of supplementary element.
 * @param indexPath      The index path of the supplementary element.
 */
- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the data source to provide a node to display for the given supplementary element in the collection view.
 *
 * @param collectionNode The sender.
 * @param kind           The kind of supplementary element.
 * @param indexPath      The index path of the supplementary element.
 */
- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the data source to provide a context object for the given section. This object
 * can later be retrieved by calling @c contextForSection: and is useful when implementing
 * custom @c UICollectionViewLayout subclasses. The context object is ret
 *
 * @param collectionNode The sender.
 * @param section The index of the section to provide context for.
 *
 * @return A context object to assign to the given section, or @c nil.
 */
- (nullable id<ASSectionContext>)collectionNode:(ASCollectionNode *)collectionNode contextForSection:(NSInteger)section;

/**
 * Asks the data source to provide an array of supplementary element kinds that exist in a given section.
 *
 * @param collectionNode The sender.
 * @param section The index of the section to provide supplementary kinds for.
 *
 * @return The supplementary element kinds that exist in the given section, if any.
 */
- (NSArray<NSString *> *)collectionNode:(ASCollectionNode *)collectionNode supplementaryElementKindsInSection:(NSInteger)section;

/**
 * Similar to -collectionView:cellForItemAtIndexPath:.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @return a node for display at this indexpath. This will be called on the main thread and should
 *   not implement reuse (it will be called once per row).  Unlike UICollectionView's version,
 *   this method is not called when the row is about to display.
 */
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

/**
 * Similar to -collectionView:nodeForItemAtIndexPath:
 * This method takes precedence over collectionView:nodeForItemAtIndexPath: if implemented.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the requested node.
 *
 * @return a block that creates the node for display at this indexpath.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

/**
 * Asks the collection view to provide a supplementary node to display in the collection view.
 *
 * @param collectionView An object representing the collection view requesting this information.
 * @param kind           The kind of supplementary node to provide.
 * @param indexPath      The index path that specifies the location of the new supplementary node.
 */
- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

/**
 * Indicator to lock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)collectionViewLockDataSource:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED_MSG("Data source accesses are on the main thread. Method will not be called.");

/**
 * Indicator to unlock the data source for data fetching in async mode.
 * We should not update the data source until the data source has been unlocked. Otherwise, it will incur data inconsistency or exception
 * due to the data access in async mode.
 *
 * @param collectionView The sender.
 * @deprecated The data source is always accessed on the main thread, and this method will not be called.
 */
- (void)collectionViewUnlockDataSource:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED_MSG("Data source accesses are on the main thread. Method will not be called.");

@end

/**
 * This is a node-based UICollectionViewDelegate.
 */
@protocol ASCollectionDelegate <ASCommonCollectionDelegate, NSObject>

@optional

/**
 * Provides the constrained size range for measuring the given item.
 *
 * @param collectionNode The sender.
 *
 * @param indexPath The index path of the item.
 *
 * @return A constrained size range for layout for the item at this index path.
 */
- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath;

- (void)collectionNode:(ASCollectionNode *)collectionNode willDisplayItemWithNode:(ASCellNode *)node;

- (void)collectionNode:(ASCollectionNode *)collectionNode didEndDisplayingItemWithNode:(ASCellNode *)node;

- (void)collectionNode:(ASCollectionNode *)collectionNode willDisplaySupplementaryElementWithNode:(ASCellNode *)node NS_AVAILABLE_IOS(8_0);
- (void)collectionNode:(ASCollectionNode *)collectionNode didEndDisplayingSupplementaryElementWithNode:(ASCellNode *)node;

- (BOOL)collectionNode:(ASCollectionNode *)collectionNode shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionNode:(ASCollectionNode *)collectionNode didHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionNode:(ASCollectionNode *)collectionNode didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionNode:(ASCollectionNode *)collectionNode shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionNode:(ASCollectionNode *)collectionNode shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionNode:(ASCollectionNode *)collectionNode didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionNode:(ASCollectionNode *)collectionNode didDeselectItemAtIndexPath:(NSIndexPath *)indexPath;

- (BOOL)collectionNode:(ASCollectionNode *)collectionNode shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionNode:(ASCollectionNode *)collectionNode canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath sender:(nullable id)sender;
- (void)collectionNode:(ASCollectionNode *)collectionNode performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath sender:(nullable id)sender;

/**
 * Receive a message that the collection node is near the end of its data set and more data should be fetched if
 * necessary.
 *
 * @param collectionNode The sender.
 * @param context A context object that must be notified when the batch fetch is completed.
 *
 * @discussion You must eventually call -completeBatchFetching: with an argument of YES in order to receive future
 * notifications to do batch fetches. This method is called on a background queue.
 *
 * ASCollectionNode currently only supports batch events for tail loads. If you require a head load, consider
 * implementing a UIRefreshControl.
 */
- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context;

/**
 * Tell the collection node if batch fetching should begin.
 *
 * @param collectionNode The sender.
 *
 * @discussion Use this method to conditionally fetch batches. Example use cases are: limiting the total number of
 * objects that can be fetched or no network connection.
 *
 * If not implemented, the collection node assumes that it should notify its asyncDelegate when batch fetching
 * should occur.
 */
- (BOOL)shouldBatchFetchForCollectionNode:(ASCollectionNode *)collectionNode;

/**
 * Provides the constrained size range for measuring the node at the index path.
 *
 * @param collectionView The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @return A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's constrainedSizeForItemAtIndexPath: instead. PLEASE NOTE the very subtle method name change.");

/**
 * Informs the delegate that the collection view will add the given node
 * at the given index path to the view hierarchy.
 *
 * @param collectionView The sender.
 * @param node The node that will be displayed.
 * @param indexPath The index path of the item that will be displayed.
 *
 * @warning AsyncDisplayKit processes collection view edits asynchronously. The index path
 *   passed into this method may not correspond to the same item in your data source
 *   if your data source has been updated since the last edit was processed.
 */
- (void)collectionView:(ASCollectionView *)collectionView willDisplayNode:(ASCellNode *)node forItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

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
- (void)collectionView:(ASCollectionView *)collectionView didEndDisplayingNode:(ASCellNode *)node forItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

- (void)collectionView:(ASCollectionView *)collectionView willBeginBatchFetchWithContext:(ASBatchContext *)context ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

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
- (BOOL)shouldBatchFetchForCollectionView:(ASCollectionView *)collectionView ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

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
 *
 * This method is deprecated. Use @c collectionView:willDisplayNode:forItemAtIndexPath: instead.
 */
- (void)collectionView:(ASCollectionView *)collectionView willDisplayNodeForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED_MSG("Use ASCollectionNode's method instead.");

@end

@protocol ASCollectionDataSourceInterop <ASCollectionDataSource>

/**
 * This method offers compatibility with synchronous, standard UICollectionViewCell objects.
 * These cells will **not** have the performance benefits of ASCellNodes (like preloading, async layout, and
 * async drawing) - even when mixed within the same ASCollectionNode.
 *
 * In order to use this method, you must:
 * 1. Implement it on your ASCollectionDataSource object.
 * 2. Call registerCellClass: on the collectionNode.view (in viewDidLoad, or register an onDidLoad: block).
 * 3. Return nil from the nodeBlockForItem...: or nodeForItem...: method. NOTE: it is an error to return
 *    nil from within a nodeBlock, if you have returned a nodeBlock object.
 * 4. Lastly, you must implement a method to provide the size for the cell. There are two ways this is done:
 * 4a. UICollectionViewFlowLayout (incl. ASPagerNode). Implement
 collectionNode:constrainedSizeForItemAtIndexPath:.
 * 4b. Custom collection layouts. Set .view.layoutInspector and have it implement
 collectionView:constrainedSizeForNodeAtIndexPath:.
 *
 * For an example of using this method with all steps above (including a custom layout, 4b.),
 * see the app in examples/CustomCollectionView and enable kShowUICollectionViewCells = YES.
 */
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;

@optional

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Implement this property and return YES if you want your interop data source to be
 * used when dequeuing cells for node-backed items.
 *
 * If NO (the default), the interop data source will only be consulted in cases
 * where no ASCellNode was provided to AsyncDisplayKit.
 *
 * If YES, the interop data source will always be consulted to dequeue cells, and
 * will be expected to return _ASCollectionViewCells in cases where a node was provided.
 *
 * The default value is NO.
 */
@property (class, nonatomic, readonly) BOOL dequeuesCellsForNodeBackedItems;

@end

@protocol ASCollectionDelegateInterop <ASCollectionDelegate>

@optional

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END

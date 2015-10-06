/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDataController.h"

@interface ASDataController (Subclasses)

/**
 * Queues the given operation until an `endUpdates` synchronize update is completed.
 *
 * If this method is called outside of a begin/endUpdates batch update, the block is
 * executed immediately.
 */
- (void)performEditCommandWithBlock:(void (^)(void))block;

/**
 * Safely locks access to the data source and executes the given block, unlocking once complete.
 *
 * When `asyncDataFetching` is enabled, the block is executed on a background thread.
 */
- (void)accessDataSourceWithBlock:(dispatch_block_t)block;

- (void)willPerformInitialDataLoading;

/**
 * An opportunity for a subclass to access the data source before entering into the editing queue
 */
- (void)prepareForReloadData;

/**
 * Subclasses can override this to reload data after the abstract data controller deletes its old data and before it reloads the new.
 *
 * @discussion Invoked on the editing transaction queue.
 */
- (void)willReloadData;

- (void)prepareInsertSections:(NSIndexSet *)sections;

- (void)willInsertSections:(NSIndexSet *)sections;

- (void)willDeleteSections:(NSIndexSet *)sections;

- (void)prepareForReloadSections:(NSIndexSet *)sections;

- (void)willReloadSections:(NSIndexSet *)sections;

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Provides a collection of index paths for nodes of the given kind that are currently in the editing store
 */
- (NSArray *)indexPathsForEditingNodesOfKind:(NSString *)kind;

/**
 * Read-only access to the underlying editing nodes of the given kind
 */
- (NSMutableArray *)editingNodesOfKind:(NSString *)kind;

/**
 * Read only access to the underlying completed nodes of the given kind
 */
- (NSMutableArray *)completedNodesOfKind:(NSString *)kind;

/**
 * Measure and layout the given nodes in optimized batches, constraining each to a given size in `constrainedSizeForNodeOfKind:atIndexPath:`.
 */
- (void)batchLayoutNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

/**
 * Provides the size range for a specific node during the layout process.
 */
- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Inserts the given nodes of the specified kind into the backing store, calling completion on the main thread when the write finishes.
 */
- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

/**
 * Deletes the given nodes of the specified kind in the backing store, calling completion on the main thread when the deletion finishes.
 */
- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

/**
 * Inserts the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock;

/**
 * Deletes the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock;

@end

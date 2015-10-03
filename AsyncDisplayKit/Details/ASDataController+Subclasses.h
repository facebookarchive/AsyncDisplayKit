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

/**
 * An opportunity for a subclass to access the data source before entering into the editing queue
 */
- (void)prepareForReloadData;

/**
 * Subclasses can override this to reload data after the abstract data controller deletes its old data and before it reloads the new.
 */
- (void)willReloadData;

- (NSMutableDictionary *)internalCompletedNodes;

/**
 * Measure and layout the given nodes in optimized batches, constraining each to a given size.
 */
- (void)batchLayoutNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths constrainedSize:(ASSizeRange (^)(NSIndexPath *indexPath))constraintedSizeBlock completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock;

- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock;

- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock;

@end

//
//  ASDataController+Subclasses.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

@class ASIndexedNodeContext;

typedef void (^ASDataControllerCompletionBlock)(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths);

@interface ASDataController (Subclasses)

#pragma mark - Internal editing & completed store querying

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

#pragma mark - Node sizing

/**
 * Measure and layout the given nodes in optimized batches, constraining each to a given size in `constrainedSizeForNodeOfKind:atIndexPath:`.
 */
- (void)batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts ofKind:(NSString *)kind completion:(ASDataControllerCompletionBlock)completionBlock;

/**
 * Perform measurement and layout of loaded nodes on the main thread, skipping unloaded nodes.
 *
 * @discussion Once nodes have loaded their views, we can't layout in the background so this is a chance
 * to do so immediately on the main thread.
 */
- (void)layoutLoadedNodes:(NSArray<ASCellNode *> *)nodes fromContexts:(NSArray<ASIndexedNodeContext *> *)contexts ofKind:(NSString *)kind;

/**
 * Provides the size range for a specific node during the layout process.
 */
- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

#pragma mark - Node & Section Insertion/Deletion API

/**
 * Inserts the given nodes of the specified kind into the backing store, calling completion on the main thread when the write finishes.
 */
- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock;

/**
 * Deletes the given nodes of the specified kind in the backing store, calling completion on the main thread when the deletion finishes.
 */
- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock;

/**
 * Inserts the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock;

/**
 * Deletes the given sections of the specified kind in the backing store, calling completion on the main thread when finished.
 */
- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock;

#pragma mark - Data Manipulation Hooks

/**
 * Notifies the subclass to perform any work needed before the data controller is reloaded entirely
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 */
 - (void)prepareForReloadData;
 
/**
 * Notifies the subclass that the data controller is about to reload its data entirely
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform new node creation like supplementary views
 * or header/footer nodes.
 */
- (void)willReloadData;

/**
 * Notifies the subclass to perform setup before sections are inserted in the data controller
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 *
 * @param sections Indices of sections to be inserted
 */
- (void)prepareForInsertSections:(NSIndexSet *)sections;

/**
 * Notifies the subclass that the data controller will insert new sections at the given position
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform any additional transformations like supplementary views
 * or header/footer nodes.
 *
 * @param sections Indices of sections to be inserted
 */
- (void)willInsertSections:(NSIndexSet *)sections;

/**
 * Notifies the subclass that the data controller will delete sections at the given positions
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform any additional transformations like supplementary views
 * or header/footer nodes.
 *
 * @param sections Indices of sections to be deleted
 */
- (void)willDeleteSections:(NSIndexSet *)sections;

/**
 * Notifies the subclass that the data controller will move a section to a new position
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform any additional transformations like supplementary views
 * or header/footer nodes.
 *
 * @param section    Index of current section position
 * @param newSection Index of new section position
 */
- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection;

/**
 * Notifies the subclass to perform setup before rows are inserted in the data controller.
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 *
 * @param indexPaths Index paths for the rows to be inserted.
 */
- (void)prepareForInsertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Notifies the subclass that the data controller will insert new rows at the given index paths.
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform any additional transformations like supplementary views
 * or header/footer nodes.
 *
 * @param indexPaths Index paths for the rows to be inserted.
 */
- (void)willInsertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Notifies the subclass to perform setup before rows are deleted in the data controller.
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 *
 * @param indexPaths Index paths for the rows to be deleted.
 */
- (void)prepareForDeleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Notifies the subclass that the data controller will delete rows at the given index paths.
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 *
 * @param indexPaths Index paths for the rows to be deleted.
 */
- (void)willDeleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

@end

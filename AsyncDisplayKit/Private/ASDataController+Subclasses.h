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
#import <vector>

@class ASIndexedNodeContext;

typedef void (^ASDataControllerCompletionBlock)(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths);

@interface ASDataController (Subclasses)

#pragma mark - Internal editing & completed store querying

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
 *
 * This method runs synchronously.
 * @param batchCompletion A handler to be run after each batch is completed. It is executed synchronously on the calling thread.
 */
- (void)batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts batchCompletion:(ASDataControllerCompletionBlock)batchCompletionHandler;

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
 * Deletes the given sections in the backing store, calling completion on the main thread when finished.
 */
- (void)deleteSections:(NSIndexSet *)indexSet completion:(void (^)())completionBlock;

#pragma mark - Data Manipulation Hooks

/**
 * Notifies the subclass to perform any work needed before the data controller is reloaded entirely
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 */
 - (void)prepareForReloadDataWithSectionCount:(NSInteger)newSectionCount;
 
/**
 * Notifies the subclass that the data controller is about to reload its data entirely
 *
 * @discussion This method will be performed on the data controller's editing background queue before the parent's
 * concrete implementation. This is a great place to perform new node creation like supplementary views
 * or header/footer nodes.
 */
- (void)willReloadDataWithSectionCount:(NSInteger)newSectionCount;

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
 * Notifies the subclass to perform setup before sections are deleted in the data controller
 *
 * @discussion This method will be performed before the data controller enters its editing queue.
 * The data source is locked at this point and accessing it is safe. Use this method to set up any nodes or
 * data stores before entering into editing the backing store on a background thread.
 *
 * @param sections Indices of sections to be inserted
 */
- (void)prepareForDeleteSections:(NSIndexSet *)sections;

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

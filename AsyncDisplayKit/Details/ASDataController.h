//
//  ASDataController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASEventLog.h>
#ifdef __cplusplus
#import <vector>
#endif

NS_ASSUME_NONNULL_BEGIN

#if ASEVENTLOG_ENABLE
#define ASDataControllerLogEvent(dataController, ...) [dataController.eventLog logEventWithBacktrace:(AS_SAVE_EVENT_BACKTRACES ? [NSThread callStackSymbols] : nil) format:__VA_ARGS__]
#else
#define ASDataControllerLogEvent(dataController, ...)
#endif

@class ASCellNode;
@class ASDataController;
@class _ASHierarchyChangeSet;
@protocol ASTraitEnvironment;

typedef NSUInteger ASDataControllerAnimationOptions;

extern NSString * const ASDataControllerRowNodeKind;
extern NSString * const ASCollectionInvalidUpdateException;

/**
 Data source for data controller
 It will be invoked in the same thread as the api call of ASDataController.
 */

@protocol ASDataControllerSource <NSObject>

/**
 Fetch the ASCellNode block for specific index path. This block should return the ASCellNode for the specified index path.
 */
- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath;

/**
 The constrained size range for layout.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

/**
 Fetch the number of rows in specific section.
 */
- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section;

/**
 Fetch the number of sections.
 */
- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController;

@end

@protocol ASDataControllerEnvironmentDelegate
- (id<ASTraitEnvironment>)dataControllerEnvironment;
@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

/**
 Called for batch update.
 */
- (void)dataControllerBeginUpdates:(ASDataController *)dataController;
- (void)dataControllerWillDeleteAllData:(ASDataController *)dataController;
- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL))completion;

/**
 Called for insertion of elements.
 */
- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray<ASCellNode *> *)nodes atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for deletion of elements.
 */
- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray<ASCellNode *> *)nodes atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for insertion of sections.
 */
- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray<NSArray<ASCellNode *> *> *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 Called for deletion of sections.
 */
- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

@end

/**
 * Controller to layout data in background, and managed data updating.
 *
 * All operations are asynchronous and thread safe. You can call it from background thread (it is recommendated) and the data
 * will be updated asynchronously. The dataSource must be updated to reflect the changes before these methods has been called.
 * For each data updating, the corresponding methods in delegate will be called.
 */
@interface ASDataController : NSObject

- (instancetype)initWithDataSource:(id<ASDataControllerSource>)dataSource eventLog:(nullable ASEventLog *)eventLog NS_DESIGNATED_INITIALIZER;

/**
 Data source for fetching data info.
 */
@property (nonatomic, weak, readonly) id<ASDataControllerSource> dataSource;

/**
 An object that will be included in the backtrace of any update validation exceptions that occur.
 */
@property (nonatomic, weak) id validationErrorSource;

/**
 Delegate to notify when data is updated.
 */
@property (nonatomic, weak) id<ASDataControllerDelegate> delegate;

/**
 *
 */
@property (nonatomic, weak) id<ASDataControllerEnvironmentDelegate> environmentDelegate;

#ifdef __cplusplus
/**
 * Returns the most recently gathered item counts from the data source. If the counts
 * have been invalidated, this synchronously queries the data source and saves the result.
 *
 * This must be called on the main thread.
 */
- (std::vector<NSInteger>)itemCountsFromDataSource;
#endif

/**
 * Returns YES if reloadData has been called at least once. Before this point it is
 * important to ignore/suppress some operations. For example, inserting a section
 * before the initial data load should have no effect.
 *
 * This must be called on the main thread.
 */
@property (nonatomic, readonly) BOOL initialReloadDataHasBeenCalled;

#if ASEVENTLOG_ENABLE
/*
 * @abstract The primitive event tracing object. You shouldn't directly use it to log event. Use the ASDataControllerLogEvent macro instead.
 */
@property (nonatomic, strong, readonly) ASEventLog *eventLog;
#endif

/** @name Data Updating */

- (void)updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet animated:(BOOL)animated;

/**
 * Re-measures all loaded nodes in the backing store.
 * 
 * @discussion Used to respond to a change in size of the containing view
 * (e.g. ASTableView or ASCollectionView after an orientation change).
 */
- (void)relayoutAllNodes;

- (void)reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions completion:(void (^ _Nullable)())completion;

- (void)reloadDataImmediatelyWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)waitUntilAllUpdatesAreCommitted;

/** @name Data Querying */

- (NSUInteger)numberOfSections;

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

- (nullable ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath;

- (NSUInteger)completedNumberOfSections;

- (NSUInteger)completedNumberOfRowsInSection:(NSUInteger)section;

- (nullable ASCellNode *)nodeAtCompletedIndexPath:(NSIndexPath *)indexPath;

/**
 * @return The index path, in the data source's index space, for the given node.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;

/**
 * @return The index path, in UIKit's index space, for the given node.
 *
 * @discussion @c indexPathForNode: is returns an index path in the data source's index space.
 *   This method is useful for e.g. looking up the cell for a given node.
 */
- (nullable NSIndexPath *)completedIndexPathForNode:(ASCellNode *)cellNode;

/**
 * Direct access to the nodes that have completed calculation and layout
 */
- (NSArray<NSArray <ASCellNode *> *> *)completedNodes;

/**
 * Immediately move this item. This is called by ASTableView when the user has finished an interactive
 * item move and the table view is requesting a model update.
 * 
 * This must be called on the main thread.
 */
- (void)moveCompletedNodeAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;

@end

NS_ASSUME_NONNULL_END

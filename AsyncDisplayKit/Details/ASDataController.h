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
#import <AsyncDisplayKit/ASDealloc2MainObject.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASFlowLayoutController.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCellNode;
@class ASDataController;
@protocol ASEnvironment;

typedef NSUInteger ASDataControllerAnimationOptions;

/**
 * ASCellNode creation block. Used to lazily create the ASCellNode instance for a specified indexPath.
 */
typedef ASCellNode * _Nonnull(^ASCellNodeBlock)();

FOUNDATION_EXPORT NSString * const ASDataControllerRowNodeKind;

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
- (id<ASEnvironment>)dataControllerEnvironment;
@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

@optional

/**
 Called for batch update.
 */
- (void)dataControllerBeginUpdates:(ASDataController *)dataController;
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
@protocol ASFlowLayoutControllerDataSource;
@interface ASDataController : ASDealloc2MainObject <ASFlowLayoutControllerDataSource>

/**
 Data source for fetching data info.
 */
@property (nonatomic, weak) id<ASDataControllerSource> dataSource;

/**
 Delegate to notify when data is updated.
 */
@property (nonatomic, weak) id<ASDataControllerDelegate> delegate;

/**
 *
 */
@property (nonatomic, weak) id<ASDataControllerEnvironmentDelegate> environmentDelegate;

/** @name Data Updating */

- (void)beginUpdates;

- (void)endUpdates;

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^ _Nullable)(BOOL))completion;

- (void)insertSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)deleteSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 * Re-measures all loaded nodes in the backing store.
 * 
 * @discussion Used to respond to a change in size of the containing view
 * (e.g. ASTableView or ASCollectionView after an orientation change).
 */
- (void)relayoutAllNodes;

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions completion:(void (^ _Nullable)())completion;

- (void)reloadDataImmediatelyWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions;

- (void)waitUntilAllUpdatesAreCommitted;

/** @name Data Querying */

- (NSUInteger)numberOfSections;

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section;

- (nullable ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath;

- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;

- (NSArray<ASCellNode *> *)nodesAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 * Direct access to the nodes that have completed calculation and layout
 */
- (NSArray<NSArray <ASCellNode *> *> *)completedNodes;

@end

NS_ASSUME_NONNULL_END

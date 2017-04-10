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
@class ASCollectionElement;
@class ASDataController;
@class ASElementMap;
@class ASLayout;
@class _ASHierarchyChangeSet;
@protocol ASTraitEnvironment;
@protocol ASSectionContext;

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
 Fetch the number of rows in specific section.
 */
- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section;

/**
 Fetch the number of sections.
 */
- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController;

/**
 Returns if the collection element size matches a given size
 */
- (BOOL)dataController:(ASDataController *)dataController presentedSizeForElement:(ASCollectionElement *)element matchesSize:(CGSize)size;

@optional

/**
 The constrained size range for layout. Called only if collection layout delegate is not provided.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

- (NSArray<NSString *> *)dataController:(ASDataController *)dataController supplementaryNodeKindsInSections:(NSIndexSet *)sections;

- (NSUInteger)dataController:(ASDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section;

- (ASCellNodeBlock)dataController:(ASDataController *)dataController supplementaryNodeBlockOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 The constrained size range for layout. Called only if no data controller layout delegate is provided.
 */
- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (nullable id<ASSectionContext>)dataController:(ASDataController *)dataController contextForSection:(NSInteger)section;

@end

@protocol ASDataControllerEnvironmentDelegate

- (nullable id<ASTraitEnvironment>)dataControllerEnvironment;

@end

/**
 Delegate for notify the data updating of data controller.
 These methods will be invoked from main thread right now, but it may be moved to background thread in the future.
 */
@protocol ASDataControllerDelegate <NSObject>

/**
 * Called before updating with given change set.
 *
 * @param changeSet The change set that includes all updates
 */
- (void)dataController:(ASDataController *)dataController willUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

/**
 * Called for change set updates.
 *
 * @param changeSet The change set that includes all updates
 */
- (void)dataController:(ASDataController *)dataController didUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

@end

@protocol ASDataControllerLayoutDelegate <NSObject>

/**
 * @abstract Returns a layout context needed for a coming layout pass with the given elements.
 * The context should contain the elements and any additional information needed.
 *
 * @discussion This method will be called on main thread.
 */
- (id)layoutContextWithElements:(ASElementMap *)elements;

/**
 * @abstract Prepares in advance a new layout with the given context.
 *
 * @param context A context that was previously returned by `-layoutContextWithElements:`.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, this method should rely solely on the given context and should not reach out to its collection/table view for information regarding items.
 *
 * @discussion This method will be called on background theads. It must be thread-safe and should not change any internal state of the conforming object.
 * It's recommended to put the resulting layouts of this method into a thread-safe cache that can be looked up later on.
 *
 * @discussion This method must block its calling thread. It can dispatch to other theads to reduce blocking time.
 */
- (void)prepareLayoutWithContext:(id)context;

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
 * The map that is currently displayed. The "UIKit index space."
 */
@property (nonatomic, strong, readonly) ASElementMap *visibleMap;

/**
 * The latest map fetched from the data source. May be more recent than @c visibleMap.
 */
@property (nonatomic, strong, readonly) ASElementMap *pendingMap;

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

/**
 * Delegate for preparing layouts. Main thead only.
 */
@property (nonatomic, weak) id<ASDataControllerLayoutDelegate> layoutDelegate;

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

- (void)updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

/**
 * Re-measures all loaded nodes in the backing store.
 * 
 * @discussion Used to respond to a change in size of the containing view
 * (e.g. ASTableView or ASCollectionView after an orientation change).
 */
- (void)relayoutAllNodes;

/**
 * Re-measures given nodes in the backing store.
 *
 * @discussion Used to respond to setNeedsLayout calls in ASCellNode
 */
- (void)relayoutNodes:(id<NSFastEnumeration>)nodes nodesSizeChanged:(NSMutableArray * _Nonnull)nodesSizesChanged;

- (void)waitUntilAllUpdatesAreCommitted;

/**
 * Notifies the data controller object that its environment has changed. The object will request its environment delegate for new information
 * and propagate the information to all visible elements, including ones that are being prepared in background.
 *
 * @discussion If called before the initial @c reloadData, this method will do nothing and the trait collection of the initial load will be requested from the environment delegate.
 *
 * @discussion This method can be called on any threads.
 */
- (void)environmentDidChange;

@end

NS_ASSUME_NONNULL_END

//
//  ASRangeController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#define ASRangeControllerLoggingEnabled 0

NS_ASSUME_NONNULL_BEGIN

@class _ASHierarchyChangeSet;
@protocol ASRangeControllerDataSource;
@protocol ASRangeControllerDelegate;
@protocol ASLayoutController;

/**
 * Working range controller.
 *
 * Used internally by ASTableView and ASCollectionView.  It is paired with ASDataController.
 * It is designed to support custom scrolling containers as well.  Observes the visible range, maintains
 * "working ranges" to trigger network calls and rendering, and is responsible for driving asynchronous layout of cells.
 * This includes cancelling those asynchronous operations as cells fall outside of the working ranges.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASRangeController : NSObject <ASDataControllerDelegate>
{
  id<ASLayoutController>                  _layoutController;
  __weak id<ASRangeControllerDataSource>  _dataSource;
  __weak id<ASRangeControllerDelegate>    _delegate;
}

/**
 * Notify the range controller that the visible range has been updated.
 * This is the primary input call that drives updating the working ranges, and triggering their actions.
 * The ranges will be updated in the next turn of the main loop, or when -updateIfNeeded is called.
 *
 * @see [ASRangeControllerDelegate rangeControllerVisibleNodeIndexPaths:]
 */
- (void)setNeedsUpdate;

/**
 * Update the ranges immediately, if -setNeedsUpdate has been called since the last update.
 * This is useful because the ranges must be updated immediately after a cell is added
 * into a table/collection to satisfy interface state API guarantees.
 */
- (void)updateIfNeeded;

/**
 * Add the sized node for `indexPath` as a subview of `contentView`.
 *
 * @param contentView UIView to add a (sized) node's view to.
 *
 * @param node The cell node to be added.
 */
- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node;

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType;

// These methods call the corresponding method on each node, visiting each one that
// the range controller has set a non-default interface state on.
- (void)clearContents;
- (void)clearPreloadedData;

/**
 * An object that describes the layout behavior of the ranged component (table view, collection view, etc.)
 *
 * Used primarily for providing the current range of index paths and identifying when the
 * range controller should invalidate its range.
 */
@property (nonatomic, strong) id<ASLayoutController> layoutController;

/**
 * The underlying data source for the range controller
 */
@property (nonatomic, weak) id<ASRangeControllerDataSource> dataSource;

/**
 * Delegate for handling range controller events. Must not be nil.
 */
@property (nonatomic, weak) id<ASRangeControllerDelegate> delegate;

@end


/**
 * Data source for ASRangeController.
 *
 * Allows the range controller to perform external queries on the range. 
 * Ex. range nodes, visible index paths, and viewport size.
 */
@protocol ASRangeControllerDataSource <NSObject>

/**
 * @param rangeController Sender.
 *
 * @return an array of elements corresponding to the data currently visible onscreen (i.e., the visible range).
 */
- (NSArray<ASCollectionElement *> *)visibleElementsForRangeController:(ASRangeController *)rangeController;

/**
 * @param rangeController Sender.
 *
 * @return the current scroll direction of the view using this range controller.
 */
- (ASScrollDirection)scrollDirectionForRangeController:(ASRangeController *)rangeController;

/**
 * @param rangeController Sender.
 *
 * @return the ASInterfaceState of the node that this controller is powering.  This allows nested range controllers
 * to collaborate with one another, as an outer controller may set bits in .interfaceState such as Visible.
 * If this controller is an orthogonally scrolling element, it waits until it is visible to preload outside the viewport.
 */
- (ASInterfaceState)interfaceStateForRangeController:(ASRangeController *)rangeController;

- (ASElementMap *)elementMapForRangeController:(ASRangeController *)rangeController;

- (NSString *)nameForRangeControllerDataSource;

@end

/**
 * Delegate for ASRangeController.
 */
@protocol ASRangeControllerDelegate <NSObject>

/**
 * Called before updating with given change set.
 *
 * @param changeSet The change set that includes all updates
 */
- (void)rangeController:(ASRangeController *)rangeController willUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

/**
 * Called after updating with given change set.
 *
 * @param changeSet The change set that includes all updates
 */
- (void)rangeController:(ASRangeController *)rangeController didUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet;

@end

@interface ASRangeController (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

/**
 * Update the range mode for a range controller to a explicitly set mode until the node that contains the range
 * controller becomes visible again
 *
 * Logic for the automatic range mode:
 * 1. If there are no visible node paths available nothing is to be done and no range update will happen
 * 2. The initial range update if the range controller is visible always will be
 *    ASLayoutRangeModeMinimum as it's the initial fetch
 * 3. The range mode set explicitly via updateCurrentRangeWithMode: will last at least one range update. After that it
 the range controller will use the explicit set range mode until it becomes visible and a new range update was
 triggered or a new range mode via updateCurrentRangeWithMode: is set
 * 4. If range mode is not explicitly set the range mode is variying based if the range controller is visible or not
 */
- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;

@end

@interface ASRangeController (DebugInternal)

+ (void)layoutDebugOverlayIfNeeded;

- (void)addRangeControllerToRangeDebugOverlay;

- (void)updateRangeController:(ASRangeController *)controller
     withScrollableDirections:(ASScrollDirection)scrollableDirections
              scrollDirection:(ASScrollDirection)direction
                    rangeMode:(ASLayoutRangeMode)mode
      displayTuningParameters:(ASRangeTuningParameters)displayTuningParameters
      preloadTuningParameters:(ASRangeTuningParameters)preloadTuningParameters
               interfaceState:(ASInterfaceState)interfaceState;

@end

NS_ASSUME_NONNULL_END

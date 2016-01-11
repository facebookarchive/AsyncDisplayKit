/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRangeController.h"

#import "ASAssert.h"
#import "ASDisplayNodeExtras.h"
#import "ASMultiDimensionalArrayUtils.h"
#import "ASRangeHandlerVisible.h"
#import "ASRangeHandlerRender.h"
#import "ASRangeHandlerPreload.h"
#import "ASInternalHelpers.h"
#import "ASLayoutController.h"
#import "ASLayoutRangeType.h"

@implementation ASRangeController

- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(ASScrollDirection)scrollDirection
{
}

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node
{
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [_layoutController setTuningParameters:tuningParameters forRangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [_layoutController tuningParametersForRangeType:rangeType];
}

@end

@interface ASRangeControllerStable ()
{
  BOOL _rangeIsValid;

  BOOL _dataControllerIsUpdating;
  BOOL _pendingUpdateVisibleNodeIndexPaths;
  
  // keys should be ASLayoutRangeTypes and values NSSets containing NSIndexPaths
  NSMutableDictionary *_rangeTypeIndexPaths;
  NSDictionary *_rangeTypeHandlers;
  BOOL _queuedRangeUpdate;
  
  ASScrollDirection _scrollDirection;
}

@end

@implementation ASRangeControllerStable

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _rangeIsValid = YES;
  _rangeTypeIndexPaths = [NSMutableDictionary dictionary];
  _rangeTypeHandlers = @{
                         @(ASLayoutRangeTypeVisible)  : [[ASRangeHandlerVisible alloc] init],
                         @(ASLayoutRangeTypeDisplay)  : [[ASRangeHandlerRender alloc] init],
                         @(ASLayoutRangeTypeFetchData): [[ASRangeHandlerPreload alloc] init],
                         };
  
  return self;
}

#pragma mark - Cell node view handling

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node
{
  if (node.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }
  
  // clean the content view
  for (UIView *view in contentView.subviews) {
    [view removeFromSuperview];
  }
  
  [self moveCellNode:node toView:contentView];
}

- (void)moveCellNode:(ASCellNode *)node toView:(UIView *)view
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"Cannot move a nil node to a view");
  ASDisplayNodeAssert(view, @"Cannot move a node to a non-existent view");

  // force any nodes that are about to come into view to have display enabled
  if (node.displaySuspended) {
    [node recursivelySetDisplaySuspended:NO];
  }

  [view addSubview:node.view];
}

#pragma mark - Core visible node range managment API

- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(ASScrollDirection)scrollDirection
{
  _scrollDirection = scrollDirection;

  if (_queuedRangeUpdate) {
    return;
  }

  // coalesce these events -- handling them multiple times per runloop is noisy and expensive
  _queuedRangeUpdate = YES;
    
  [self performSelector:@selector(_updateVisibleNodeIndexPaths)
             withObject:nil
             afterDelay:0
                inModes:@[ NSRunLoopCommonModes ]];
}

- (void)_updateVisibleNodeIndexPaths
{
  if (!_queuedRangeUpdate) {
    return;
  }

  if (_dataControllerIsUpdating) {
    // When data controller is updating, it returns _externalCompletedNodes instead of _completeNodes;
    // But when adding/removing items, _externalCompletedNodes get out of sync, because only _completedNodes are being updated;
    // When that happens, our index paths in _rangeTypeIndexPaths exist in _completeNodes, but might not exist in
    // _externalCompleteNodes; So while data controller is updating we postpone updating visible node index paths
    _pendingUpdateVisibleNodeIndexPaths = YES;
    return;
  }

  NSArray *visibleNodePaths = [_dataSource visibleNodeIndexPathsForRangeController:self];

  if (visibleNodePaths.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    _queuedRangeUpdate = NO;
    return ; // don't do anything for this update, but leave _rangeIsValid to make sure we update it later
  }

  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
  CGSize viewportSize = [_dataSource viewportSizeForRangeController:self];
  [_layoutController setViewportSize:viewportSize];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if ([_layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)]) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }
  
  for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
    ASLayoutRangeType rangeType = (ASLayoutRangeType)i;
    id rangeKey = @(rangeType);

    // this delegate decide what happens when a node is added or removed from a range
    id<ASRangeHandler> rangeHandler = _rangeTypeHandlers[rangeKey];

    if (!_rangeIsValid || [_layoutController shouldUpdateForVisibleIndexPaths:visibleNodePaths rangeType:rangeType]) {
      NSSet *indexPaths = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:rangeType];

      // Notify to remove indexpaths that are leftover that are not visible or included in the _layoutController calculated paths
      // This value may be nil for the first call of this method.
      NSMutableSet *removedIndexPaths = [_rangeTypeIndexPaths[rangeKey] mutableCopy];
      [removedIndexPaths minusSet:indexPaths];
      [removedIndexPaths minusSet:visibleNodePathsSet];

      if (removedIndexPaths.count) {
        NSArray *removedNodes = [_dataSource rangeController:self nodesAtIndexPaths:[removedIndexPaths allObjects]];
        for (ASCellNode *node in removedNodes) {
          // since this class usually manages large or infinite data sets, the working range
          // directly bounds memory usage by requiring redrawing any content that falls outside the range.
          [rangeHandler node:node exitedRangeOfType:rangeType];
        }
      }

      // Notify to add index paths that are not currently in _rangeTypeIndexPaths
      NSMutableSet *addedIndexPaths = [indexPaths mutableCopy];
      [addedIndexPaths minusSet:_rangeTypeIndexPaths[rangeKey]];

      // The preload range (for example) should include nodes that are visible
      // TODO: remove this once we have removed the dependency on Core Animation's -display
      if ([self shouldSkipVisibleNodesForRangeType:rangeType]) {
        [addedIndexPaths minusSet:visibleNodePathsSet];
      }
      
      if (addedIndexPaths.count) {
        NSArray *addedNodes = [_dataSource rangeController:self nodesAtIndexPaths:[addedIndexPaths allObjects]];
        for (ASCellNode *node in addedNodes) {
          [rangeHandler node:node enteredRangeOfType:rangeType];
        }
      }

      // set the range indexpaths so that we can remove/add on the next update pass
      _rangeTypeIndexPaths[rangeKey] = indexPaths;
    }
  }

  _rangeIsValid = YES;
  _queuedRangeUpdate = NO;
}

- (BOOL)shouldSkipVisibleNodesForRangeType:(ASLayoutRangeType)rangeType
{
  return rangeType == ASLayoutRangeTypeDisplay;
}

#pragma mark - ASDataControllerDelegete

- (void)dataControllerBeginUpdates:(ASDataController *)dataController
{
  ASPerformBlockOnMainThread(^{
    _dataControllerIsUpdating = YES;
    [_delegate didBeginUpdatesInRangeController:self];
  });
}

- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASPerformBlockOnMainThread(^{
    _dataControllerIsUpdating = NO;
    [_delegate rangeController:self didEndUpdatesAnimated:animated completion:completion];
    if (_pendingUpdateVisibleNodeIndexPaths) {
      _pendingUpdateVisibleNodeIndexPaths = NO;
      [self _updateVisibleNodeIndexPaths];
    }
  });
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
      
    // We're inserting nodes so we need to appropriately shift indexes of _rangeTypeIndexPaths
    for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
      id rangeKey = @((ASLayoutRangeType)i);
      NSSet *rangePaths = _rangeTypeIndexPaths[rangeKey];
      NSMutableSet *shiftedRangePaths = [NSMutableSet new];
      for (NSIndexPath *path in rangePaths) {
        int shift = 0;
        for (NSIndexPath *pathToInsert in indexPaths) {
          // if inserted index path is before this one, we need to shift it
          if (pathToInsert.section == path.section && (pathToInsert.item <= path.item + shift)) {
            ++shift;
          }
        }
        NSIndexPath *shifted = path;
        if (shift > 0) {
          shifted = [NSIndexPath indexPathForItem:path.item + shift inSection:path.section];
        }
        [shiftedRangePaths addObject:shifted];
      }
      _rangeTypeIndexPaths[rangeKey] = shiftedRangePaths;
    }
    [_delegate rangeController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    
    // When removing nodes we need to make sure that removed indexPaths are not left in _rangeTypeIndexPaths,
    // otherwise _updateVisibleNodeIndexPaths may try to retrieve nodes from dataSource that aren't there anymore
    for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
      id rangeKey = @((ASLayoutRangeType)i);

      NSMutableSet *rangePaths = [_rangeTypeIndexPaths[rangeKey] mutableCopy];
      for (NSIndexPath *pathToRemove in indexPaths) {
        [rangePaths removeObject:pathToRemove];
      }
        
      // After removing paths we are left with gaps; We need to shift all remaining index paths
      // so that there are no gaps left
      NSMutableSet *shiftedRangePaths = [NSMutableSet new];
      for (NSIndexPath *path in rangePaths) {
        int shift = 0;
        for (NSIndexPath *pathToRemove in indexPaths) {
          if (pathToRemove.section == path.section && pathToRemove.item < path.item) {
            // removed path was before this path, we need to shift it back
            ++shift;
          }
        }
        NSIndexPath *shifted = path;
        if (shift > 0) {
          shifted = [NSIndexPath indexPathForItem:path.item - shift inSection:path.section];
        }
        [shiftedRangePaths addObject:shifted];
      }

      _rangeTypeIndexPaths[rangeKey] = shiftedRangePaths;
    }
    
    [_delegate rangeController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(sections.count == indexSet.count, @"Invalid sections");
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    
    for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
      id rangeKey = @((ASLayoutRangeType)i);
      NSMutableSet *rangePaths = [_rangeTypeIndexPaths[rangeKey] mutableCopy];
          
      // When inserting sections we need to update _rangeTypeIndexPaths to reflect shifted sections
      NSMutableSet *shiftedRangePaths = [NSMutableSet new];
      for (NSIndexPath *path in rangePaths) {
        __block int shift = 0;
        [indexSet enumerateIndexesUsingBlock:^(NSUInteger indexToAdd, BOOL *stop) {
          if (indexToAdd <= (path.section + shift)) {
            ++shift;
          }
        }];
          
        NSIndexPath *shifted = path;
        if (shift > 0) {
          shifted = [NSIndexPath indexPathForItem:path.item inSection:path.section + shift];
        }
        [shiftedRangePaths addObject:shifted];
      }
      _rangeTypeIndexPaths[rangeKey] = shiftedRangePaths;
    }

    [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    
    // When removing nodes we need to make sure that removed indexPaths are not left in _rangeTypeIndexPaths,
    // otherwise _updateVisibleNodeIndexPaths may try to retrieve nodes from dataSource that aren't there anymore
    for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
      id rangeKey = @((ASLayoutRangeType)i);
      NSMutableSet *rangePaths = [_rangeTypeIndexPaths[rangeKey] mutableCopy];
      for (NSIndexPath *path in _rangeTypeIndexPaths[rangeKey]) {
        if ([indexSet containsIndex:path.section]) {
          [rangePaths removeObject:path];
        }
      }
        
      // After removing paths we are left with gaps; We need to shift all remaining index paths
      // so that there are no gaps left
      NSMutableSet *shiftedRangePaths = [NSMutableSet new];
      for (NSIndexPath *path in rangePaths) {
        __block int shift = 0;
        [indexSet enumerateIndexesUsingBlock:^(NSUInteger indexToRemove, BOOL *stop) {
          if (indexToRemove < path.section) {
            ++shift;
          }
        }];

        NSIndexPath *shifted = path;
        if (shift > 0) {
          shifted = [NSIndexPath indexPathForItem:path.item inSection:path.section - shift];
        }
        [shiftedRangePaths addObject:shifted];
      }
        
      _rangeTypeIndexPaths[rangeKey] = shiftedRangePaths;
    }
    
    [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

@end

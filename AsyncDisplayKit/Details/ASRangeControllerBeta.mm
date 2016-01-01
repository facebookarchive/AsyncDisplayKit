/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRangeControllerBeta.h"

#import "ASAssert.h"
#import "ASDisplayNodeExtras.h"
#import "ASMultiDimensionalArrayUtils.h"
#import "ASRangeHandlerVisible.h"
#import "ASRangeHandlerRender.h"
#import "ASRangeHandlerPreload.h"
#import "ASInternalHelpers.h"
#import "ASDisplayNode+FrameworkPrivate.h"

@interface ASRangeControllerBeta ()
{
  BOOL _rangeIsValid;
  BOOL _queuedRangeUpdate;
  ASScrollDirection _scrollDirection;
}

@end

@implementation ASRangeControllerBeta

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _rangeIsValid = YES;
  
  return self;
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
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self _updateVisibleNodeIndexPaths];
  });
}

- (void)_updateVisibleNodeIndexPaths
{
  if (!_queuedRangeUpdate) {
    return;
  }

  // FIXME: Consider if we need to check this separately from the range calculation below.
  NSArray *visibleNodePaths = [_dataSource visibleNodeIndexPathsForRangeController:self];

  if (visibleNodePaths.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    _queuedRangeUpdate = NO;
    return; // don't do anything for this update, but leave _rangeIsValid == NO to make sure we update it later
  }

  CGSize viewportSize = [_dataSource viewportSizeForRangeController:self];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if ([_layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)]) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }
  
  NSSet *fetchDataIndexPaths = [_layoutController indexPathsForScrolling:_scrollDirection
                                                            viewportSize:viewportSize
                                                               rangeType:ASLayoutRangeTypeFetchData];
  
  NSSet *displayIndexPaths   = [_layoutController indexPathsForScrolling:_scrollDirection
                                                            viewportSize:viewportSize
                                                               rangeType:ASLayoutRangeTypeDisplay];
  
  NSSet *visibleIndexPaths   = [_layoutController indexPathsForScrolling:_scrollDirection
                                                            viewportSize:viewportSize
                                                               rangeType:ASLayoutRangeTypeVisible];

  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
//  NSLog(@"visible sets are equal: %d", [visibleIndexPaths isEqualToSet:visibleNodePathsSet]);
  
  // Typically the fetchDataIndexPaths will be the largest, and be a superset of the others, though it may be disjoint.
  NSMutableSet *allIndexPaths = [fetchDataIndexPaths mutableCopy];
  [allIndexPaths unionSet:displayIndexPaths];
  [allIndexPaths unionSet:visibleIndexPaths];
  
  NSMutableArray *modified = [NSMutableArray array];
  
  for (NSIndexPath *indexPath in allIndexPaths) {
    // Before a node / indexPath is exposed to ASRangeController, ASDataController should have already measured it.
    // For consistency, make sure each node knows that it should measure itself if something changes.
    ASInterfaceState interfaceState = ASInterfaceStateMeasureLayout;
    
    if ([fetchDataIndexPaths containsObject:indexPath]) {
      interfaceState |= ASInterfaceStateFetchData;
    }
    if ([displayIndexPaths containsObject:indexPath]) {
      interfaceState |= ASInterfaceStateDisplay;
    }
    if ([visibleIndexPaths containsObject:indexPath]) {
      interfaceState |= ASInterfaceStateVisible;
    }
    
    ASDisplayNode *node = [_dataSource rangeController:self nodeAtIndexPath:indexPath];
    ASDisplayNodeAssert(node.hierarchyState & ASHierarchyStateRangeManaged, @"All nodes reaching this point should be range-managed, or interfaceState may be incorrectly reset.");
    // Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
    if (node.interfaceState != interfaceState) {
      [modified addObject:indexPath];
      [node recursivelySetInterfaceState:interfaceState];
    }
  }
  
/*
  [modified sortUsingSelector:@selector(compare:)];
  
  for (NSIndexPath *indexPath in modified) {
    NSLog(@"indexPath %@, Visible: %d, Display: %d, FetchData: %d", indexPath, [visibleIndexPaths containsObject:indexPath], [displayIndexPaths containsObject:indexPath], [fetchDataIndexPaths containsObject:indexPath]);
  }
*/
  
  _rangeIsValid = YES;
  _queuedRangeUpdate = NO;
}

#pragma mark - Cell node view handling

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"Cannot move a nil node to a view");
  ASDisplayNodeAssert(contentView, @"Cannot move a node to a non-existent view");
  
  if (node.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }
  
  // clean the content view
  for (UIView *view in contentView.subviews) {
    [view removeFromSuperview];
  }
  
  [contentView addSubview:node.view];
}

#pragma mark - ASDataControllerDelegete

- (void)dataControllerBeginUpdates:(ASDataController *)dataController
{
  ASPerformBlockOnMainThread(^{
    [_delegate didBeginUpdatesInRangeController:self];
  });
}

- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASPerformBlockOnMainThread(^{
    [_delegate rangeController:self didEndUpdatesAnimated:animated completion:completion];
  });
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(sections.count == indexSet.count, @"Invalid sections");
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

@end

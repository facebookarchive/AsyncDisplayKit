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

extern BOOL ASInterfaceStateIncludesVisible(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateVisible) == ASInterfaceStateVisible);
}

extern BOOL ASInterfaceStateIncludesDisplay(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateDisplay) == ASInterfaceStateDisplay);
}

extern BOOL ASInterfaceStateIncludesFetchData(ASInterfaceState interfaceState)
{
  return ((interfaceState & ASInterfaceStateFetchData) == ASInterfaceStateFetchData);
}

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
  [_layoutController setViewportSize:viewportSize];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if ([_layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)]) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }
  
  ASInterfaceState selfInterfaceState = [_dataSource interfaceStateForRangeController:self];
  
  NSSet *visibleIndexPaths   = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeVisible];
  
#if RangeControllerLoggingEnabled
  NSMutableArray *modified = [NSMutableArray array];
#endif
  
  if (ASInterfaceStateIncludesVisible(selfInterfaceState)) {
    // If we are already visible, get busy!  Better get started on preloading before the user scrolls more...
    NSSet *fetchDataIndexPaths = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeFetchData];
    NSSet *displayIndexPaths = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeDisplay];
  
    // Typically the fetchDataIndexPaths will be the largest, and be a superset of the others, though it may be disjoint.
    NSMutableSet *allIndexPaths = [fetchDataIndexPaths mutableCopy];
    [allIndexPaths unionSet:displayIndexPaths];
    [allIndexPaths unionSet:visibleIndexPaths];
    
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
#if RangeControllerLoggingEnabled
        [modified addObject:indexPath];
#endif
        [node recursivelySetInterfaceState:interfaceState];
      }
    }
  } else {
    // If selfInterfaceState isn't visible, then visibleIndexPaths represents what /will/ be immediately visible at the
    // instant we come onscreen.  So, fetch data and display all of those things, but don't waste resources preloading yet.
    // We handle this as a separate case to minimize set operations for offscreen preloading, including containsObject:.
    
    for (NSIndexPath *indexPath in visibleIndexPaths) {
      // Set Layout, Fetch Data, Display.  DO NOT set Visible: even though these elements are in the visible range / "viewport",
      // our overall container object is itself not visible yet.  The moment it becomes visible, we will run the condition above.
      ASInterfaceState interfaceState = ASInterfaceStateMeasureLayout | ASInterfaceStateFetchData | ASInterfaceStateDisplay;
      
      ASDisplayNode *node = [_dataSource rangeController:self nodeAtIndexPath:indexPath];
      ASDisplayNodeAssert(node.hierarchyState & ASHierarchyStateRangeManaged, @"All nodes reaching this point should be range-managed, or interfaceState may be incorrectly reset.");
      // Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
      if (node.interfaceState != interfaceState) {
#if RangeControllerLoggingEnabled
        [modified addObject:indexPath];
#endif
        [node recursivelySetInterfaceState:interfaceState];
      }
    }
  }
  
#if RangeControllerLoggingEnabled
  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
  BOOL setsAreEqual = [visibleIndexPaths isEqualToSet:visibleNodePathsSet];
  NSLog(@"visible sets are equal: %d", setsAreEqual);
  if (!setsAreEqual) {
    NSLog(@"standard: %@", visibleIndexPaths);
    NSLog(@"custom: %@", visibleNodePathsSet);
  }
  
  [modified sortUsingSelector:@selector(compare:)];
  
  for (NSIndexPath *indexPath in modified) {
    ASDisplayNode *node = [_dataSource rangeController:self nodeAtIndexPath:indexPath];
    ASInterfaceState interfaceState = node.interfaceState;
    BOOL inVisible = ASInterfaceStateIncludesVisible(interfaceState);
    BOOL inDisplay = ASInterfaceStateIncludesDisplay(interfaceState);
    BOOL inFetchData = ASInterfaceStateIncludesFetchData(interfaceState);
    NSLog(@"indexPath %@, Visible: %d, Display: %d, FetchData: %d", indexPath, inVisible, inDisplay, inFetchData);
  }
#endif
  
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

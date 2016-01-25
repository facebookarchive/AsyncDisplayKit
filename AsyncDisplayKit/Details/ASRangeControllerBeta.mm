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
  BOOL _layoutControllerImplementsSetVisibleIndexPaths;
  ASScrollDirection _scrollDirection;
  NSSet<NSIndexPath *> *_allPreviousIndexPaths;
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

- (void)setLayoutController:(id<ASLayoutController>)layoutController
{
  _layoutController = layoutController;
  _layoutControllerImplementsSetVisibleIndexPaths = [_layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)];
}

- (void)_updateVisibleNodeIndexPaths
{
  ASDisplayNodeAssert(_layoutController, @"An ASLayoutController is required by ASRangeController");
  if (!_queuedRangeUpdate || !_layoutController) {
    return;
  }

  // TODO: Consider if we need to use this codepath, or can rely on something more similar to the data & display ranges
  // Example: ... = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeVisible];
  NSArray<NSIndexPath *> *visibleNodePaths = [_dataSource visibleNodeIndexPathsForRangeController:self];

  if (visibleNodePaths.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    _queuedRangeUpdate = NO;
    return; // don't do anything for this update, but leave _rangeIsValid == NO to make sure we update it later
  }

  [_layoutController setViewportSize:[_dataSource viewportSizeForRangeController:self]];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if (_layoutControllerImplementsSetVisibleIndexPaths) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }
  
  // allNodes is a 2D array: it contains arrays for each section, each containing nodes.
  NSArray<NSArray *> *allNodes = [_dataSource completedNodes];
  NSUInteger numberOfSections = [allNodes count];
  
  NSArray<ASDisplayNode *> *currentSectionNodes = nil;
  NSInteger currentSectionIndex = -1; // Set to -1 so we don't match any indexPath.section on the first iteration.
  NSUInteger numberOfNodesInSection = 0;
  
  NSSet<NSIndexPath *> *visibleIndexPaths = [NSSet setWithArray:visibleNodePaths];
  NSSet<NSIndexPath *> *displayIndexPaths = nil;
  NSSet<NSIndexPath *> *fetchDataIndexPaths = nil;
  
  // Prioritize the order in which we visit each.  Visible nodes should be updated first so they are enqueued on
  // the network or display queues before preloading (offscreen) nodes are enqueued.
  NSMutableOrderedSet<NSIndexPath *> *allIndexPaths = [[NSMutableOrderedSet alloc] initWithSet:visibleIndexPaths];
  
  ASInterfaceState selfInterfaceState = [_dataSource interfaceStateForRangeController:self];
  
  if (ASInterfaceStateIncludesVisible(selfInterfaceState)) {
    // If we are already visible, get busy!  Better get started on preloading before the user scrolls more...
    fetchDataIndexPaths = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeFetchData];

    ASRangeTuningParameters parametersFetchData = [_layoutController tuningParametersForRangeType:ASLayoutRangeTypeFetchData];
    ASRangeTuningParameters parametersDisplay = [_layoutController tuningParametersForRangeType:ASLayoutRangeTypeDisplay];
    if (parametersDisplay.leadingBufferScreenfuls == parametersFetchData.leadingBufferScreenfuls &&
        parametersDisplay.trailingBufferScreenfuls == parametersFetchData.trailingBufferScreenfuls) {
      displayIndexPaths = fetchDataIndexPaths;
    } else {
      displayIndexPaths   = [_layoutController indexPathsForScrolling:_scrollDirection rangeType:ASLayoutRangeTypeDisplay];
    }
  
    // Typically the fetchDataIndexPaths will be the largest, and be a superset of the others, though it may be disjoint.
    // Because allIndexPaths is an NSMutableOrderedSet, this adds the non-duplicate items /after/ the existing items.
    // This means that during iteration, we will first visit visible, then display, then fetch data nodes.
    [allIndexPaths unionSet:displayIndexPaths];
    [allIndexPaths unionSet:fetchDataIndexPaths];
  }
  
  // Add anything we had applied interfaceState to in the last update, but is no longer in range, so we can clear any
  // range flags it still has enabled.  Most of the time, all but a few elements are equal; a large programmatic
  // scroll or major main thread stall could cause entirely disjoint sets.  In either case we must visit all.
  // Calling "-set" on NSMutableOrderedSet just references the underlying mutable data store, so we must copy it.
  NSSet<NSIndexPath *> *allCurrentIndexPaths = [[allIndexPaths set] copy];
  [allIndexPaths unionSet:_allPreviousIndexPaths];
  _allPreviousIndexPaths = allCurrentIndexPaths;
  
  if (!_rangeIsValid) {
    [allIndexPaths addObjectsFromArray:ASIndexPathsForMultidimensionalArray(allNodes)];
  }
  
  // This array is only used if logging is enabled.
  NSMutableArray<NSIndexPath *> *modifiedIndexPaths = (RangeControllerLoggingEnabled ? [NSMutableArray array] : nil);
  
  for (NSIndexPath *indexPath in allIndexPaths) {
    // Before a node / indexPath is exposed to ASRangeController, ASDataController should have already measured it.
    // For consistency, make sure each node knows that it should measure itself if something changes.
    ASInterfaceState interfaceState = ASInterfaceStateMeasureLayout;
    
    if (ASInterfaceStateIncludesVisible(selfInterfaceState)) {
      if ([fetchDataIndexPaths containsObject:indexPath]) {
        interfaceState |= ASInterfaceStateFetchData;
      }
      if ([displayIndexPaths containsObject:indexPath]) {
        interfaceState |= ASInterfaceStateDisplay;
      }
      if ([visibleIndexPaths containsObject:indexPath]) {
        interfaceState |= ASInterfaceStateVisible;
      }
    } else {
      // If selfInterfaceState isn't visible, then visibleIndexPaths represents what /will/ be immediately visible at the
      // instant we come onscreen.  So, fetch data and display all of those things, but don't waste resources preloading yet.
      // We handle this as a separate case to minimize set operations for offscreen preloading, including containsObject:.

      // Set Layout, Fetch Data, Display.  DO NOT set Visible: even though these elements are in the visible range / "viewport",
      // our overall container object is itself not visible yet.  The moment it becomes visible, we will run the condition above.
      if ([allCurrentIndexPaths containsObject:indexPath]) {
        // We might be looking at an indexPath that was previously in-range, but now we need to clear it.
        // In that case we'll just set it back to MeasureLayout.  Only set Display | FetchData if in allCurrentIndexPaths.
        interfaceState |= ASInterfaceStateDisplay;
        interfaceState |= ASInterfaceStateFetchData;
      }
    }
    
    NSInteger section = indexPath.section;
    NSInteger row     = indexPath.row;
    
    if (section >= 0 && row >= 0 && section < numberOfSections) {
      if (section != currentSectionIndex) {
        // Often we'll be dealing with indexPaths in the same section, but the set isn't sorted and we may even bounce
        // between the same ones.  Still, this saves dozens of method calls to access the inner array and count.
        currentSectionNodes = [allNodes objectAtIndex:section];
        numberOfNodesInSection = [currentSectionNodes count];
        currentSectionIndex = section;
      }
      
      if (row < numberOfNodesInSection) {
        ASDisplayNode *node = [currentSectionNodes objectAtIndex:row];
        
        ASDisplayNodeAssert(node.hierarchyState & ASHierarchyStateRangeManaged, @"All nodes reaching this point should be range-managed, or interfaceState may be incorrectly reset.");
        // Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
        if (node.interfaceState != interfaceState) {
          [modifiedIndexPaths addObject:indexPath];
          [node recursivelySetInterfaceState:interfaceState];
        }
      }
    }
  }
  
  _rangeIsValid = YES;
  _queuedRangeUpdate = NO;
  
#if RangeControllerLoggingEnabled
  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
  BOOL setsAreEqual = [visibleIndexPaths isEqualToSet:visibleNodePathsSet];
  NSLog(@"visible sets are equal: %d", setsAreEqual);
  if (!setsAreEqual) {
    NSLog(@"standard: %@", visibleIndexPaths);
    NSLog(@"custom: %@", visibleNodePathsSet);
  }
  
  [modifiedIndexPaths sortUsingSelector:@selector(compare:)];
  
  for (NSIndexPath *indexPath in modifiedIndexPaths) {
    ASDisplayNode *node = [_dataSource rangeController:self nodeAtIndexPath:indexPath];
    ASInterfaceState interfaceState = node.interfaceState;
    BOOL inVisible = ASInterfaceStateIncludesVisible(interfaceState);
    BOOL inDisplay = ASInterfaceStateIncludesDisplay(interfaceState);
    BOOL inFetchData = ASInterfaceStateIncludesFetchData(interfaceState);
    NSLog(@"indexPath %@, Visible: %d, Display: %d, FetchData: %d", indexPath, inVisible, inDisplay, inFetchData);
  }
#endif
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

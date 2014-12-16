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
#import "ASDisplayNodeInternal.h"
#import "ASLayoutController.h"

#import "ASMultiDimensionalArrayUtils.h"

@interface ASDisplayNode (ASRangeController)

- (void)display;
- (void)recursivelyDisplay;

@end

@implementation ASDisplayNode (ASRangeController)

- (void)display
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"backing store must be loaded before calling -display");

  CALayer *layer = self.layer;

  // rendering a backing store requires a node be laid out
  [layer setNeedsLayout];
  [layer layoutIfNeeded];

  if (layer.contents) {
    return;
  }

  [layer setNeedsDisplay];
  [layer displayIfNeeded];
}

- (void)recursivelyDisplay
{
  for (ASDisplayNode *node in self.subnodes) {
    [node recursivelyDisplay];
  }

  [self display];
}

@end

@interface ASRangeController () {
  NSSet *_workingRangeIndexPaths;
  NSSet *_workingRangeNodes;
  
  BOOL _queuedRangeUpdate;

  ASScrollDirection _scrollDirection;
}

@end

@implementation ASRangeController

- (instancetype)init {
  if (self = [super init]) {

    _workingRangeIndexPaths = [NSSet set];
  }

  return self;
}

#pragma mark - View manipulation.

- (void)discardNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  if ([_workingRangeNodes containsObject:node]) {
    // move the node's view to the working range area, so its rendering persists
    [self addNodeToWorkingRange:node];
  } else {
    // this node isn't in the working range, remove it from the view hierarchy
    [self removeNodeFromWorkingRange:node];
  }
}

- (void)removeNodeFromWorkingRange:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  [node recursivelySetDisplaySuspended:YES];
  [node.view removeFromSuperview];

  // since this class usually manages large or infinite data sets, the working range
  // directly bounds memory usage by requiring redrawing any content that falls outside the range.
  [node recursivelyReclaimMemory];
}

- (void)addNodeToWorkingRange:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  // if node is in the working range it should not actively be in view
  [node.view removeFromSuperview];

  [node recursivelyDisplay];
}

- (void)moveNode:(ASCellNode *)node toView:(UIView *)view
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node && view, @"invalid argument, did you mean -removeNodeFromWorkingRange:?");

  // use an explicit transaction to force CoreAnimation to display nodes in the order they are added.
  [CATransaction begin];

  [view addSubview:node.view];

  [CATransaction commit];
}

#pragma mark -
#pragma mark API.

- (void)visibleNodeIndexPathsDidChangeWithScrollDirection:(ASScrollDirection)scrollDirection
{
  _scrollDirection = scrollDirection;

  if (_queuedRangeUpdate) {
    return;
  }

  // coalesce these events -- handling them multiple times per runloop is noisy and expensive
  _queuedRangeUpdate = YES;
  [self performSelector:@selector(updateVisibleNodeIndexPaths)
             withObject:nil
             afterDelay:0
                inModes:@[ NSRunLoopCommonModes ]];
}

- (void)updateVisibleNodeIndexPaths
{
  if (!_queuedRangeUpdate) {
    return;
  }

  NSArray *indexPaths = [_delegate rangeControllerVisibleNodeIndexPaths:self];
  CGSize viewportSize = [_delegate rangeControllerViewportSize:self];

  if ([_layoutController shouldUpdateWorkingRangesForVisibleIndexPath:indexPaths viewportSize:viewportSize]) {
    [_layoutController setVisibleNodeIndexPaths:indexPaths];
    NSSet *workingRangeIndexPaths = [_layoutController workingRangeIndexPathsForScrolling:_scrollDirection viewportSize:viewportSize];
    NSSet *visibleRangeIndexPaths = [NSSet setWithArray:indexPaths];

    NSMutableSet *removedIndexPaths = [_workingRangeIndexPaths mutableCopy];
    [removedIndexPaths minusSet:workingRangeIndexPaths];
    [removedIndexPaths minusSet:visibleRangeIndexPaths];
    if (removedIndexPaths.count) {
      NSArray *removedNodes = [_delegate rangeController:self nodesAtIndexPaths:[removedIndexPaths allObjects]];
      [removedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
        [self removeNodeFromWorkingRange:node];
      }];
    }

    NSMutableSet *addedIndexPaths = [workingRangeIndexPaths mutableCopy];
    [addedIndexPaths minusSet:_workingRangeIndexPaths];
    [addedIndexPaths minusSet:visibleRangeIndexPaths];
    if (addedIndexPaths.count) {
      NSArray *addedNodes = [_delegate rangeController:self nodesAtIndexPaths:[addedIndexPaths allObjects]];
      [addedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
        [self addNodeToWorkingRange:node];
      }];
    }

    _workingRangeIndexPaths = workingRangeIndexPaths;
    _workingRangeNodes = [NSSet setWithArray:[_delegate rangeController:self nodesAtIndexPaths:[workingRangeIndexPaths allObjects]]];
  }

  _queuedRangeUpdate = NO;
}

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)cellNode
{
  [cellNode recursivelySetDisplaySuspended:NO];

  if (cellNode.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }

  for (UIView *view in contentView.subviews) {
    ASDisplayNode *node = view.asyncdisplaykit_node;
    if (node) {
      // plunk this node back into the working range, if appropriate
      ASDisplayNodeAssert([node isKindOfClass:[ASCellNode class]], @"invalid node");
      [self discardNode:(ASCellNode *)node];
    } else {
      // if it's not a node, it's something random UITableView added to the hierarchy.  kill it.
      [view removeFromSuperview];
    }
  }

  [self moveNode:cellNode toView:contentView];
}

#pragma mark - ASDataControllerDelegete

/**
 * Dispatch to main thread for updating ranges.
 * We are considering to move it to background queue if we could call recursive display in background thread.
 */
- (void)updateOnMainThreadWithBlock:(dispatch_block_t)block {
  if ([NSThread isMainThread]) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      block();
    });
  }
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths {
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");

  NSMutableArray *nodeSizes = [NSMutableArray arrayWithCapacity:nodes.count];
  [nodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
    [nodeSizes addObject:[NSValue valueWithCGSize:node.calculatedSize]];
  }];

  [self updateOnMainThreadWithBlock:^{
    [_layoutController insertNodesAtIndexPaths:indexPaths withSizes:nodeSizes];
    [_delegate rangeController:self didInsertNodesAtIndexPaths:indexPaths];
  }];
}

- (void)dataController:(ASDataController *)dataController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths {
  [self updateOnMainThreadWithBlock:^{
    [_layoutController deleteNodesAtIndexPaths:indexPaths];
    [_delegate rangeController:self didDeleteNodesAtIndexPaths:indexPaths];
  }];
}

- (void)dataController:(ASDataController *)dataController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet {
  [self updateOnMainThreadWithBlock:^{
    [_layoutController insertSectionsAtIndexSet:indexSet];
    [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet];
  }];
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet {
  [self updateOnMainThreadWithBlock:^{
    [_layoutController deleteSectionsAtIndexSet:indexSet];
    [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet];
  }];
}

@end

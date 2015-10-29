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
#import "ASRangeHandlerRender.h"
#import "ASRangeHandlerPreload.h"
#import "ASInternalHelpers.h"

@interface ASRangeController () {
  BOOL _rangeIsValid;

  // keys should be ASLayoutRangeTypes and values NSSets containing NSIndexPaths
  NSMutableDictionary *_rangeTypeIndexPaths;
  NSDictionary *_rangeTypeHandlers;
  BOOL _queuedRangeUpdate;

  ASScrollDirection _scrollDirection;
}

@end

@implementation ASRangeController

- (instancetype)init {
  if (self = [super init]) {

    _rangeIsValid = YES;
    _rangeTypeIndexPaths = [[NSMutableDictionary alloc] init];

    _rangeTypeHandlers = @{
                            @(ASLayoutRangeTypeRender): [[ASRangeHandlerRender alloc] init],
                            @(ASLayoutRangeTypePreload): [[ASRangeHandlerPreload alloc] init],
                            };
  }

  return self;
}


#pragma mark - View manipulation

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


#pragma mark - API

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

  NSArray *visibleNodePaths = [_delegate rangeControllerVisibleNodeIndexPaths:self];

  if ( visibleNodePaths.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    _queuedRangeUpdate = NO;
    return ; // don't do anything for this update, but leave _rangeIsValid to make sure we update it later
  }

  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
  CGSize viewportSize = [_delegate rangeControllerViewportSize:self];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if ([_layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)]) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }

  for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
    ASLayoutRangeType rangeType = (ASLayoutRangeType)i;
    id rangeKey = @(rangeType);

    // this delegate decide what happens when a node is added or removed from a range
    id<ASRangeHandler> rangeDelegate = _rangeTypeHandlers[rangeKey];

    if (!_rangeIsValid || [_layoutController shouldUpdateForVisibleIndexPaths:visibleNodePaths viewportSize:viewportSize rangeType:rangeType]) {
      NSSet *indexPaths = [_layoutController indexPathsForScrolling:_scrollDirection viewportSize:viewportSize rangeType:rangeType];

      // Notify to remove indexpaths that are leftover that are not visible or included in the _layoutController calculated paths
      NSMutableSet *removedIndexPaths = _rangeIsValid ? [[_rangeTypeIndexPaths objectForKey:rangeKey] mutableCopy] : [NSMutableSet set];
      [removedIndexPaths minusSet:indexPaths];
      [removedIndexPaths minusSet:visibleNodePathsSet];

      if (removedIndexPaths.count) {
        NSArray *removedNodes = [_delegate rangeController:self nodesAtIndexPaths:[removedIndexPaths allObjects]];
        [removedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
          // since this class usually manages large or infinite data sets, the working range
          // directly bounds memory usage by requiring redrawing any content that falls outside the range.
          [rangeDelegate node:node exitedRangeOfType:rangeType];
        }];
      }

      // Notify to add indexpaths that are not currently in _rangeTypeIndexPaths
      NSMutableSet *addedIndexPaths = [indexPaths mutableCopy];
      [addedIndexPaths minusSet:[_rangeTypeIndexPaths objectForKey:rangeKey]];

      // The preload range (for example) should include nodes that are visible
      // TODO: remove this once we have removed the dependency on Core Animation's -display
      if ([self shouldSkipVisibleNodesForRangeType:rangeType]) {
        [addedIndexPaths minusSet:visibleNodePathsSet];
      }
      
      if (addedIndexPaths.count) {
        NSArray *addedNodes = [_delegate rangeController:self nodesAtIndexPaths:[addedIndexPaths allObjects]];
        [addedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
          [rangeDelegate node:node enteredRangeOfType:rangeType];
        }];
      }

      // set the range indexpaths so that we can remove/add on the next update pass
      [_rangeTypeIndexPaths setObject:indexPaths forKey:rangeKey];
    }
  }

  _rangeIsValid = YES;
  _queuedRangeUpdate = NO;
}

- (BOOL)shouldSkipVisibleNodesForRangeType:(ASLayoutRangeType)rangeType
{
  return rangeType == ASLayoutRangeTypeRender;
}

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


#pragma mark - ASDataControllerDelegete

- (void)dataControllerBeginUpdates:(ASDataController *)dataController {
  ASPerformBlockOnMainThread(^{
    [_delegate rangeControllerBeginUpdates:self];
  });
}

- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion {
  ASPerformBlockOnMainThread(^{
    [_delegate rangeController:self endUpdatesAnimated:animated completion:completion];
  });
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions {
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");

  NSMutableArray *nodeSizes = [NSMutableArray arrayWithCapacity:nodes.count];
  [nodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
    [nodeSizes addObject:[NSValue valueWithCGSize:node.calculatedSize]];
  }];

  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions {
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions {
  ASDisplayNodeAssert(sections.count == indexSet.count, @"Invalid sections");

  NSMutableArray *sectionNodeSizes = [NSMutableArray arrayWithCapacity:sections.count];

  [sections enumerateObjectsUsingBlock:^(NSArray *nodes, NSUInteger idx, BOOL *stop) {
    NSMutableArray *nodeSizes = [NSMutableArray arrayWithCapacity:nodes.count];
    [nodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx2, BOOL *stop2) {
      [nodeSizes addObject:[NSValue valueWithCGSize:node.calculatedSize]];
    }];
    [sectionNodeSizes addObject:nodeSizes];
  }];

  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions {
  ASPerformBlockOnMainThread(^{
    _rangeIsValid = NO;
    [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

@end

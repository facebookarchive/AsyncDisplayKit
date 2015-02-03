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
#import "ASMultiDimensionalArrayUtils.h"
#import "ASRenderRangeDelegate.h"
#import "ASPreloadRangeDelegate.h"

@interface ASRangeController () {
  BOOL _rangeIsValid;

  // keys should be ASLayoutRangeTypes and values NSSets containing NSIndexPaths
  NSMutableDictionary *_rangeTypeIndexPaths;
  NSDictionary *_rangeTypeDelegates;
  BOOL _queuedRangeUpdate;

  ASScrollDirection _scrollDirection;
}

@end

@implementation ASRangeController

- (instancetype)init {
  if (self = [super init]) {

    _rangeIsValid = YES;
    _rangeTypeIndexPaths = [[NSMutableDictionary alloc] init];

    _rangeTypeDelegates = @{
                            @(ASLayoutRangeTypeRender): [[ASRenderRangeDelegate alloc] init],
                            @(ASLayoutRangeTypePreload): [[ASPreloadRangeDelegate alloc] init],
                            };
  }

  return self;
}


#pragma mark - View manipulation

- (void)moveNode:(ASCellNode *)node toView:(UIView *)view
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"Cannot move a nil node to a view");
  ASDisplayNodeAssert(view, @"Cannot move a node to a non-existent view");

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
  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
  CGSize viewportSize = [_delegate rangeControllerViewportSize:self];

  // the layout controller needs to know what the current visible indices are to calculate range offsets
  [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];

  for (NSInteger i = 0; i < ASLayoutRangeTypeCount; i++) {
    ASLayoutRangeType rangeType = (ASLayoutRangeType)i;
    id rangeKey = @(rangeType);

    // this delegate decide what happens when a node is added or removed from a range
    id<ASRangeDelegate> rangeDelegate = _rangeTypeDelegates[rangeKey];

    if ([_layoutController shouldUpdateForVisibleIndexPaths:visibleNodePaths viewportSize:viewportSize rangeType:rangeType]) {
      NSSet *indexPaths = [_layoutController indexPathsForScrolling:_scrollDirection viewportSize:viewportSize rangeType:rangeType];

      // Notify to remove indexpaths that are leftover that are not visible or included in the _layoutController calculated paths
      NSMutableSet *removedIndexPaths = _rangeIsValid ? [[_rangeTypeIndexPaths objectForKey:rangeKey] mutableCopy] : [NSMutableSet set];
      [removedIndexPaths minusSet:indexPaths];
      [removedIndexPaths minusSet:visibleNodePathsSet];
      if (removedIndexPaths.count) {
        NSArray *removedNodes = [_delegate rangeController:self nodesAtIndexPaths:[removedIndexPaths allObjects]];
        [removedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
          [rangeDelegate node:node exitedRangeType:rangeType];
        }];
      }

      // Notify to add indexpaths that are not currently in _rangeTypeIndexPaths
      NSMutableSet *addedIndexPaths = [indexPaths mutableCopy];
      [addedIndexPaths minusSet:[_rangeTypeIndexPaths objectForKey:rangeKey]];

      // The preload range (for example) should include nodes that are visible
      if ([self shouldRemoveVisibleNodesFromRangeType:rangeType]) {
        [addedIndexPaths minusSet:visibleNodePathsSet];
      }

      if (addedIndexPaths.count) {
        NSArray *addedNodes = [_delegate rangeController:self nodesAtIndexPaths:[addedIndexPaths allObjects]];
        [addedNodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
          [rangeDelegate node:node enteredRangeType:rangeType];
        }];
      }

      // set the range indexpaths so that we can remove/add on the next update pass
      [_rangeTypeIndexPaths setObject:indexPaths forKey:rangeKey];
    }
  }

  _rangeIsValid = YES;
  _queuedRangeUpdate = NO;
}

- (BOOL)shouldRemoveVisibleNodesFromRangeType:(ASLayoutRangeType)rangeType
{
  return rangeType != ASLayoutRangeTypePreload;
}

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)cellNode
{
  [cellNode recursivelySetDisplaySuspended:NO];

  if (cellNode.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }

  // clean the content view
  for (UIView *view in contentView.subviews) {
    [view removeFromSuperview];
  }

  [self moveNode:cellNode toView:contentView];
}


#pragma mark - ASDataControllerDelegete

- (void)dataControllerBeginUpdates:(ASDataController *)dataController {
  ASDisplayNodePerformBlockOnMainThread(^{
    [_delegate rangeControllerBeginUpdates:self];
  });
}

- (void)dataControllerEndUpdates:(ASDataController *)dataController completion:(void (^)(BOOL))completion {
  ASDisplayNodePerformBlockOnMainThread(^{
    [_delegate rangeControllerEndUpdates:self completion:completion];
  });
}

- (void)dataController:(ASDataController *)dataController willInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    if ([_delegate respondsToSelector:@selector(rangeController:willInsertNodesAtIndexPaths:withAnimationOption:)]) {
      [_delegate rangeController:self willInsertNodesAtIndexPaths:indexPaths withAnimationOption:animationOption];
    }
  });
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");

  NSMutableArray *nodeSizes = [NSMutableArray arrayWithCapacity:nodes.count];
  [nodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx, BOOL *stop) {
    [nodeSizes addObject:[NSValue valueWithCGSize:node.calculatedSize]];
  }];

  ASDisplayNodePerformBlockOnMainThread(^{
    [_layoutController insertNodesAtIndexPaths:indexPaths withSizes:nodeSizes];
    [_delegate rangeController:self didInsertNodesAtIndexPaths:indexPaths withAnimationOption:animationOption];
    _rangeIsValid = NO;
  });
}

- (void)dataController:(ASDataController *)dataController willDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    if ([_delegate respondsToSelector:@selector(rangeController:willDeleteNodesAtIndexPaths:withAnimationOption:)]) {
      [_delegate rangeController:self willDeleteNodesAtIndexPaths:indexPaths withAnimationOption:animationOption];
    }
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    [_layoutController deleteNodesAtIndexPaths:indexPaths];
    [_delegate rangeController:self didDeleteNodesAtIndexPaths:indexPaths withAnimationOption:animationOption];
    _rangeIsValid = NO;
  });
}

- (void)dataController:(ASDataController *)dataController willInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    if ([_delegate respondsToSelector:@selector(rangeController:willInsertSectionsAtIndexSet:withAnimationOption:)]) {
      [_delegate rangeController:self willInsertSectionsAtIndexSet:indexSet withAnimationOption:animationOption];
    }
  });
}

- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodeAssert(sections.count == indexSet.count, @"Invalid sections");

  NSMutableArray *sectionNodeSizes = [NSMutableArray arrayWithCapacity:sections.count];

  [sections enumerateObjectsUsingBlock:^(NSArray *nodes, NSUInteger idx, BOOL *stop) {
    NSMutableArray *nodeSizes = [NSMutableArray arrayWithCapacity:nodes.count];
    [nodes enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger idx2, BOOL *stop2) {
      [nodeSizes addObject:[NSValue valueWithCGSize:node.calculatedSize]];
    }];
    [sectionNodeSizes addObject:nodeSizes];
  }];

  ASDisplayNodePerformBlockOnMainThread(^{
    [_layoutController insertSections:sectionNodeSizes atIndexSet:indexSet];
    [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet withAnimationOption:animationOption];
    _rangeIsValid = NO;
  });
}

- (void)dataController:(ASDataController *)dataController willDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    if ([_delegate respondsToSelector:@selector(rangeController:willDeleteSectionsAtIndexSet:withAnimationOption:)]) {
      [_delegate rangeController:self willDeleteSectionsAtIndexSet:indexSet withAnimationOption:animationOption];
    }
  });
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  ASDisplayNodePerformBlockOnMainThread(^{
    [_layoutController deleteSectionsAtIndexSet:indexSet];
    [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOption:animationOption];
    _rangeIsValid = NO;
  });
}

@end

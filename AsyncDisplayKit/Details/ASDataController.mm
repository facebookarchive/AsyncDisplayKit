/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDataController.h"

#import <Foundation/NSProcessInfo.h>

#import "ASAssert.h"
#import "ASCellNode.h"
#import "ASDisplayNode.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASDisplayNodeInternal.h"

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

static void *kASSizingQueueContext = &kASSizingQueueContext;

@interface ASDataController () {
  NSMutableArray *_nodes;
  NSMutableArray *_pendingBlocks;
  BOOL _asyncDataFetchingEnabled;
  BOOL _delegateWillInsertNodes;
  BOOL _delegateDidInsertNodes;
  BOOL _delegateWillDeleteNodes;
  BOOL _delegateDidDeleteNodes;
  BOOL _delegateWillInsertSections;
  BOOL _delegateDidInsertSections;
  BOOL _delegateWillDeleteSections;
  BOOL _delegateDidDeleteSections;
}

@property (atomic, assign) NSUInteger batchUpdateCounter;

@end

@implementation ASDataController

#pragma mark - Lifecycle

- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _nodes = [NSMutableArray array];
  _pendingBlocks = [NSMutableArray array];
  _batchUpdateCounter = 0;
  _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  
  return self;
}

- (void)setDelegate:(id<ASDataControllerDelegate>)delegate
{
  if (_delegate == delegate) {
    return;
  }
  
  _delegate = delegate;
  
  // Interrogate our delegate to understand its capabilities, optimizing away expensive respondsToSelector: calls later.
  _delegateWillInsertNodes    = [_delegate respondsToSelector:@selector(dataController:willInsertNodes:atIndexPaths:withAnimationOptions:)];
  _delegateDidInsertNodes     = [_delegate respondsToSelector:@selector(dataController:didInsertNodes:atIndexPaths:withAnimationOptions:)];
  _delegateWillDeleteNodes    = [_delegate respondsToSelector:@selector(dataController:willDeleteNodesAtIndexPaths:withAnimationOptions:)];
  _delegateDidDeleteNodes     = [_delegate respondsToSelector:@selector(dataController:didDeleteNodesAtIndexPaths:withAnimationOptions:)];
  _delegateWillInsertSections = [_delegate respondsToSelector:@selector(dataController:willInsertSections:atIndexSet:withAnimationOptions:)];
  _delegateDidInsertSections  = [_delegate respondsToSelector:@selector(dataController:didInsertSections:atIndexSet:withAnimationOptions:)];
  _delegateWillDeleteSections = [_delegate respondsToSelector:@selector(dataController:willDeleteSectionsAtIndexSet:withAnimationOptions:)];
  _delegateDidDeleteSections  = [_delegate respondsToSelector:@selector(dataController:didDeleteSectionsAtIndexSet:withAnimationOptions:)];
}

#pragma mark - Queue Management

+ (NSUInteger)parallelProcessorCount
{
  static NSUInteger parallelProcessorCount;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    parallelProcessorCount = [[NSProcessInfo processInfo] processorCount];
  });

  return parallelProcessorCount;
}

+ (dispatch_queue_t)sizingQueue
{
  static dispatch_queue_t sizingQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sizingQueue = dispatch_queue_create("com.facebook.AsyncDisplayKit.ASDataController.sizingQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(sizingQueue, kASSizingQueueContext, kASSizingQueueContext, NULL);
    dispatch_set_target_queue(sizingQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
  });

  return sizingQueue;
}

+ (BOOL)executingOnSizingQueue
{
  return kASSizingQueueContext == dispatch_get_specific(kASSizingQueueContext);
}

- (void)asyncUpdateDataWithBlock:(dispatch_block_t)block {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (_batchUpdateCounter) {
      [_pendingBlocks addObject:block];
    } else {
      block();
    }
  });
}

- (void)syncUpdateDataWithBlock:(dispatch_block_t)block {
  dispatch_sync(dispatch_get_main_queue(), ^{
    if (_batchUpdateCounter) {
      [_pendingBlocks addObject:block];
    } else {
      block();
    }
  });
}

- (void)performDataFetchingWithBlock:(dispatch_block_t)block {
  if (_asyncDataFetchingEnabled) {
    [_dataSource dataControllerLockDataSource];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
      block();
      [_dataSource dataControllerUnlockDataSource];
    });
  } else {
    [_dataSource dataControllerLockDataSource];
    block();
    [_dataSource dataControllerUnlockDataSource];
  }
}

#pragma mark - Initial Data Loading

- (void)initialDataLoadingWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions {
  [self performDataFetchingWithBlock:^{
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSUInteger sectionNum = [_dataSource dataControllerNumberOfSections:self];

    // insert sections
    [self insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionNum)] withAnimationOptions:0];

    for (NSUInteger i = 0; i < sectionNum; i++) {
      NSIndexPath *indexPath = [[NSIndexPath alloc] initWithIndex:i];

      NSUInteger rowNum = [_dataSource dataController:self rowsInSection:i];
      for (NSUInteger j = 0; j < rowNum; j++) {
        [indexPaths addObject:[indexPath indexPathByAddingIndex:j]];
      }
    }

    // insert elements
    [self insertRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

  }];
}

#pragma mark - Data Update

- (void)beginUpdates
{
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      _batchUpdateCounter++;
    }];
  });
}

- (void)endUpdates {
  [self endUpdatesWithCompletion:NULL];
}

- (void)endUpdatesWithCompletion:(void (^)(BOOL))completion
{
  dispatch_async([[self class] sizingQueue], ^{
    dispatch_async(dispatch_get_main_queue(), ^{
      _batchUpdateCounter--;

      if (!_batchUpdateCounter) {
        [_delegate dataControllerBeginUpdates:self];
        [_pendingBlocks enumerateObjectsUsingBlock:^(dispatch_block_t block, NSUInteger idx, BOOL *stop) {
          block();
        }];
        [_pendingBlocks removeAllObjects];
        [_delegate dataControllerEndUpdates:self completion:completion];
      }
    });
  });
}

- (void)insertSections:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performDataFetchingWithBlock:^{
    __block int nodeTotalCnt = 0;
    NSMutableArray *nodeCounts = [NSMutableArray arrayWithCapacity:indexSet.count];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
      NSUInteger cnt = [_dataSource dataController:self rowsInSection:idx];
      [nodeCounts addObject:@(cnt)];
      nodeTotalCnt += cnt;
    }];

    NSMutableArray *nodes = [NSMutableArray arrayWithCapacity:nodeTotalCnt];
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:nodeTotalCnt];

    __block NSUInteger idx = 0;
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger sectionIdx, BOOL *stop) {
      NSUInteger cnt = [nodeCounts[idx++] unsignedIntegerValue];

      for (int i = 0; i < cnt; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:sectionIdx];
        [indexPaths addObject:indexPath];

        ASCellNode *node = [_dataSource dataController:self nodeAtIndexPath:indexPath];
        [nodes addObject:node];
      }
    }];

    dispatch_async([[self class] sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:indexSet.count];
        for (NSUInteger i = 0; i < indexSet.count; i++) {
          [sectionArray addObject:[NSMutableArray array]];
        }
        [self _insertSections:sectionArray atIndexSet:indexSet withAnimationOptions:animationOptions];
      }];

      [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
    });
  }];
}

- (void)deleteSections:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, indexSet);
      
      [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];
      [self _deleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
    }];
  });
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performDataFetchingWithBlock:^{
    // We need to keep data query on data source in the calling thread.
    NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] init];
    NSMutableArray *updatedNodes = [[NSMutableArray alloc] init];

    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
      NSUInteger rowNum = [_dataSource dataController:self rowsInSection:idx];

      NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
      for (NSUInteger i = 0; i < rowNum; i++) {
        NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
        [updatedIndexPaths addObject:indexPath];
        [updatedNodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
      }
    }];

    // Dispatch to sizing queue in order to guarantee that any in-progress sizing operations from prior edits have completed.
    // For example, if an initial -reloadData call is quickly followed by -reloadSections, sizing the initial set may not be done
    // at this time.  Thus _nodes could be empty and crash in ASIndexPathsForMultidimensional[...]
    dispatch_async([ASDataController sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        // remove elements
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, sections);
        [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];
      }];

      // reinsert the elements
      [self _batchInsertNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
    });
  }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, [NSIndexSet indexSetWithIndex:section]);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, indexPaths);
      [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];

      // update the section of indexpaths
      NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:newSection];
      NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [updatedIndexPaths addObject:[sectionIndexPath indexPathByAddingIndex:[indexPath indexAtPosition:indexPath.length - 1]]];
      }];

      // Don't re-calculate size for moving
      [self _insertNodes:nodes atIndexPaths:updatedIndexPaths animationOptions:animationOptions];
    }];
  });
}

- (void)_insertNodes:(NSArray *)nodes
        atIndexPaths:(NSArray *)indexPaths
 withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (!nodes.count) {
    return;
  }

  dispatch_group_t layoutGroup = dispatch_group_create();

  for (NSUInteger j = 0; j < nodes.count && j < indexPaths.count; j += kASDataControllerSizingCountPerProcessor) {
    NSArray *subIndexPaths = [indexPaths subarrayWithRange:NSMakeRange(j, MIN(kASDataControllerSizingCountPerProcessor, indexPaths.count - j))];

    // TODO: The current implementation does not make use of different constrained sizes per node.
    // There should be a fast-path that avoids all of this object creation.
    NSMutableArray *nodeBoundSizes = [[NSMutableArray alloc] initWithCapacity:kASDataControllerSizingCountPerProcessor];
    [subIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
      [nodeBoundSizes addObject:[NSValue valueWithCGSize:[_dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath]]];
    }];

    dispatch_group_async(layoutGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [subIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        ASCellNode *node = nodes[j + idx];
        [node measure:[nodeBoundSizes[idx] CGSizeValue]];
        node.frame = CGRectMake(0.0f, 0.0f, node.calculatedSize.width, node.calculatedSize.height);
      }];
    });
  }

  dispatch_block_t block = ^{
    dispatch_group_wait(layoutGroup, DISPATCH_TIME_FOREVER);

    [self asyncUpdateDataWithBlock:^{
      // Insert finished nodes into data storage
      [self _insertNodes:nodes atIndexPaths:indexPaths animationOptions:animationOptions];
    }];
  };

  if ([ASDataController executingOnSizingQueue]) {
    block();
  } else {
    dispatch_async([ASDataController sizingQueue], block);
  }
}

- (void)_batchInsertNodes:(NSArray *)nodes
             atIndexPaths:(NSArray *)indexPaths
     withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;

  // Processing in batches
  for (NSUInteger i = 0; i < indexPaths.count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(indexPaths.count - i, blockSize));
    NSArray *batchedIndexPaths = [indexPaths subarrayWithRange:batchedRange];
    NSArray *batchedNodes = [nodes subarrayWithRange:batchedRange];

    [self _insertNodes:batchedNodes atIndexPaths:batchedIndexPaths withAnimationOptions:animationOptions];
  }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performDataFetchingWithBlock:^{
    // sort indexPath to avoid messing up the index when inserting in several batches
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    for (NSUInteger i = 0; i < sortedIndexPaths.count; i++) {
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:sortedIndexPaths[i]]];
    }

    [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  // sort indexPath in order to avoid messing up the index when deleting
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      [self _deleteNodesAtIndexPaths:sortedIndexPaths animationOptions:animationOptions];
    }];
  });
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  // Reloading requires re-fetching the data.  Load it on the current calling thread, locking the data source.
  [self performDataFetchingWithBlock:^{
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    [indexPaths sortedArrayUsingSelector:@selector(compare:)];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
    }];

    dispatch_async([ASDataController sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];
      }];

      [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
    });
  }];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, [NSArray arrayWithObject:indexPath]);
      NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
      [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];

      // Don't re-calculate size for moving
      NSArray *newIndexPaths = [NSArray arrayWithObject:newIndexPath];
      [self _insertNodes:nodes atIndexPaths:newIndexPaths animationOptions:animationOptions];
    }];
  });
}

- (void)reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions completion:(void (^)())completion
{
  [self performDataFetchingWithBlock:^{
    // Fetching data in calling thread
    NSMutableArray *updatedNodes = [[NSMutableArray alloc] init];
    NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] init];

    NSUInteger sectionNum = [_dataSource dataControllerNumberOfSections:self];
    for (NSUInteger i = 0; i < sectionNum; i++) {
      NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];

      NSUInteger rowNum = [_dataSource dataController:self rowsInSection:i];
      for (NSUInteger j = 0; j < rowNum; j++) {
        NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];
        [updatedIndexPaths addObject:indexPath];
        [updatedNodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
      }
    }

    dispatch_async([ASDataController sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        // Remove everything that existed before the reload, now that we're ready to insert replacements
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArray(_nodes);
        [self _deleteNodesAtIndexPaths:indexPaths animationOptions:animationOptions];

        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, _nodes.count)];
        [self deleteSections:indexSet withAnimationOptions:animationOptions];

        // Insert each section
        NSMutableArray *sections = [[NSMutableArray alloc] initWithCapacity:sectionNum];
        for (int i = 0; i < sectionNum; i++) {
          [sections addObject:[[NSMutableArray alloc] init]];
        }

        [self _insertSections:sections atIndexSet:[[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, sectionNum)] withAnimationOptions:animationOptions];
      }];
      
      [self _batchInsertNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];

      if (completion) {
        dispatch_async(dispatch_get_main_queue(), completion);
      }
    });
  }];
}

#pragma mark - Data Querying

- (NSUInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  return [_nodes count];
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [_nodes[section] count];
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  return _nodes[indexPath.section][indexPath.row];
}

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();

  // Make sure that any asynchronous layout operations have finished so that those nodes are present.
  // Otherwise a failure case could be:
  // - Reload section 2, deleting all current nodes in that section.
  // - New nodes are created and sizing is triggered, but they are not yet added to _nodes.
  // - This method is called and includes an indexPath in section 2.
  // - Unless we wait for the layout group to finish, we will crash with array out of bounds looking for the index in _nodes.
  // FIXME: Seralization is required here.  Diff in progress to resolve.
  
  return ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, [indexPaths sortedArrayUsingSelector:@selector(compare:)]);
}

#pragma mark - Internal Data Updating

- (void)_insertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexPaths.count == 0)
    return;
  if (_delegateWillInsertNodes)
    [_delegate dataController:self willInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(_nodes, indexPaths, nodes);
  if (_delegateDidInsertNodes)
    [_delegate dataController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
}

- (void)_deleteNodesAtIndexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexPaths.count == 0)
    return;
  if (_delegateWillDeleteNodes)
    [_delegate dataController:self willDeleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_nodes, indexPaths);
  if (_delegateDidDeleteNodes)
    [_delegate dataController:self didDeleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
}

- (void)_insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexSet.count == 0)
    return;
  if (_delegateWillInsertSections)
    [_delegate dataController:self willInsertSections:sections atIndexSet:indexSet withAnimationOptions:animationOptions];
  [_nodes insertObjects:sections atIndexes:indexSet];
  if (_delegateDidInsertSections)
    [_delegate dataController:self didInsertSections:sections atIndexSet:indexSet withAnimationOptions:animationOptions];
}

- (void)_deleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexSet.count == 0)
    return;
  if (_delegateWillDeleteSections)
    [_delegate dataController:self willDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  [_nodes removeObjectsAtIndexes:indexSet];
  if (_delegateDidDeleteSections)
    [_delegate dataController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
}

#pragma mark - Dealloc

- (void)dealloc {
  ASDisplayNodeAssertMainThread();
  [_nodes enumerateObjectsUsingBlock:^(NSMutableArray *section, NSUInteger sectionIndex, BOOL *stop) {
    [section enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger rowIndex, BOOL *stop) {
      if (node.isNodeLoaded) {
        if (node.layerBacked) {
          [node.layer removeFromSuperlayer];
        } else {
          [node.view removeFromSuperview];
        }
      }
    }];
  }];
}

@end

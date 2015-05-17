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

#define INSERT_NODES(multidimensionalArray, indexPath, elements, animationOption) \
{ \
  if ([_delegate respondsToSelector:@selector(dataController:willInsertNodes:atIndexPaths:withAnimationOption:)]) { \
    [_delegate dataController:self willInsertNodes:elements atIndexPaths:indexPath withAnimationOption:animationOption]; \
  } \
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(multidimensionalArray, indexPath, elements); \
  if ([_delegate respondsToSelector:@selector(dataController:didInsertNodes:atIndexPaths:withAnimationOption:)]) { \
    [_delegate dataController:self didInsertNodes:elements atIndexPaths:indexPath withAnimationOption:animationOption]; \
  } \
}

#define DELETE_NODES(multidimensionalArray, indexPath, animationOption) \
{ \
  if ([_delegate respondsToSelector:@selector(dataController:willDeleteNodesAtIndexPaths:withAnimationOption:)]) { \
    [_delegate dataController:self willDeleteNodesAtIndexPaths:indexPath withAnimationOption:animationOption]; \
  } \
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(multidimensionalArray, indexPath); \
  if ([_delegate respondsToSelector:@selector(dataController:didDeleteNodesAtIndexPaths:withAnimationOption:)]) { \
    [_delegate dataController:self didDeleteNodesAtIndexPaths:indexPath withAnimationOption:animationOption]; \
  } \
}

#define INSERT_SECTIONS(multidimensionalArray, indexSet, sections, animationOption) \
{ \
  if ([_delegate respondsToSelector:@selector(dataController:willInsertSections:atIndexSet:withAnimationOption:)]) { \
    [_delegate dataController:self willInsertSections:sections atIndexSet:indexSet withAnimationOption:animationOption]; \
  } \
  [multidimensionalArray insertObjects:sections atIndexes:indexSet]; \
  if ([_delegate respondsToSelector:@selector(dataController:didInsertSections:atIndexSet:withAnimationOption:)]) { \
    [_delegate dataController:self didInsertSections:sections atIndexSet:indexSet withAnimationOption:animationOption]; \
  } \
}

#define DELETE_SECTIONS(multidimensionalArray, indexSet, animationOption) \
{ \
  if ([_delegate respondsToSelector:@selector(dataController:willDeleteSectionsAtIndexSet:withAnimationOption:)]) { \
    [_delegate dataController:self willDeleteSectionsAtIndexSet:indexSet withAnimationOption:animationOption]; \
  } \
  [multidimensionalArray removeObjectsAtIndexes:indexSet]; \
  if ([_delegate respondsToSelector:@selector(dataController:didDeleteSectionsAtIndexSet:withAnimationOption:)]) { \
    [_delegate dataController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOption:animationOption]; \
  } \
}

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

static void *kASSizingQueueContext = &kASSizingQueueContext;

@interface ASDataController () {
  NSMutableArray *_nodes;
  NSMutableArray *_pendingBlocks;
  BOOL _asyncDataFetchingEnabled;
}

@property (atomic, assign) NSUInteger batchUpdateCounter;

@end

@implementation ASDataController

- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled {
  if (self = [super init]) {
    _nodes = [NSMutableArray array];
    _pendingBlocks = [NSMutableArray array];
    _batchUpdateCounter = 0;
    _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  }

  return self;
}

#pragma mark - Utils

+ (NSUInteger)parallelProcessorCount {
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

+ (BOOL)isSizingQueue {
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

- (void)initialDataLoadingWithAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  [self performDataFetchingWithBlock:^{
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSUInteger sectionNum = [_dataSource dataControllerNumberOfSections:self];

    // insert sections
    [self insertSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionNum)] withAnimationOption:0];

    for (NSUInteger i = 0; i < sectionNum; i++) {
      NSIndexPath *indexPath = [[NSIndexPath alloc] initWithIndex:i];

      NSUInteger rowNum = [_dataSource dataController:self rowsInSection:i];
      for (NSUInteger j = 0; j < rowNum; j++) {
        [indexPaths addObject:[indexPath indexPathByAddingIndex:j]];
      }
    }

    // insert elements
    [self insertRowsAtIndexPaths:indexPaths withAnimationOption:animationOption];

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

- (void)insertSections:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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
        INSERT_SECTIONS(_nodes , indexSet, sectionArray, animationOption);
      }];

      [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOption];
    });
  }];
}

- (void)deleteSections:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, indexSet);
      
      DELETE_NODES(_nodes, indexPaths, animationOption);
      DELETE_SECTIONS(_nodes, indexSet, animationOption);
    }];
  });
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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

    dispatch_async([ASDataController sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        // remove elements
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, sections);
        DELETE_NODES(_nodes, indexPaths, animationOption);
      }];

      // reinsert the elements
      [self _batchInsertNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOption];
    });
  }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, [NSIndexSet indexSetWithIndex:section]);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, indexPaths);
      DELETE_NODES(_nodes, indexPaths, animationOption);

      // update the section of indexpaths
      NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:newSection];
      NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [updatedIndexPaths addObject:[sectionIndexPath indexPathByAddingIndex:[indexPath indexAtPosition:indexPath.length - 1]]];
      }];

      // Don't re-calculate size for moving
      INSERT_NODES(_nodes, updatedIndexPaths, nodes, animationOption);
    }];
  });
}

- (void)_insertNodes:(NSArray *)nodes
        atIndexPaths:(NSArray *)indexPaths
 withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  if (!nodes.count) {
    return;
  }

  dispatch_group_t layoutGroup = dispatch_group_create();

  for (NSUInteger j = 0; j < nodes.count && j < indexPaths.count; j += kASDataControllerSizingCountPerProcessor) {
    NSArray *subIndexPaths = [indexPaths subarrayWithRange:NSMakeRange(j, MIN(kASDataControllerSizingCountPerProcessor, indexPaths.count - j))];

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
      // updating the cells
      INSERT_NODES(_nodes, indexPaths, nodes, animationOption);
    }];
  };

  if ([ASDataController isSizingQueue]) {
    block();
  } else {
    dispatch_async([ASDataController sizingQueue], block);
  }
}

- (void)_batchInsertNodes:(NSArray *)nodes
             atIndexPaths:(NSArray *)indexPaths
     withAnimationOptions:(ASDataControllerAnimationOptions)animationOption
{
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;

  // Processing in batches
  for (NSUInteger i = 0; i < indexPaths.count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(indexPaths.count - i, blockSize));
    NSArray *batchedIndexPaths = [indexPaths subarrayWithRange:batchedRange];
    NSArray *batchedNodes = [nodes subarrayWithRange:batchedRange];

    [self _insertNodes:batchedNodes atIndexPaths:batchedIndexPaths withAnimationOption:animationOption];
  }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  [self performDataFetchingWithBlock:^{
    // sort indexPath to avoid messing up the index when inserting in several batches
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    for (NSUInteger i = 0; i < sortedIndexPaths.count; i++) {
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:sortedIndexPaths[i]]];
    }

    [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOption];
  }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  // sort indexPath in order to avoid messing up the index when deleting
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      DELETE_NODES(_nodes, sortedIndexPaths, animationOption);
    }];
  });
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  [self performDataFetchingWithBlock:^{
    // The reloading operation required reloading the data
    // Loading data in the calling thread
    NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    [indexPaths sortedArrayUsingSelector:@selector(compare:)];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
    }];

    dispatch_async([ASDataController sizingQueue], ^{
      [self syncUpdateDataWithBlock:^{
        DELETE_NODES(_nodes, indexPaths, animationOption);
      }];

      [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOption];
    });
  }];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, [NSArray arrayWithObject:indexPath]);
      NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
      DELETE_NODES(_nodes, indexPaths, animationOption);

      // Don't re-calculate size for moving
      NSArray *newIndexPaths = [NSArray arrayWithObject:newIndexPath];
      INSERT_NODES(_nodes, newIndexPaths, nodes, animationOption);
    }];
  });
}

- (void)reloadDataWithAnimationOption:(ASDataControllerAnimationOptions)animationOption completion:(void (^)())completion
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

        NSArray *indexPaths = ASIndexPathsForMultidimensionalArray(_nodes);
        DELETE_NODES(_nodes, indexPaths, animationOption);

        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, _nodes.count)];
        DELETE_SECTIONS(_nodes, indexSet, animationOption);


        // Insert section

        NSMutableArray *sections = [[NSMutableArray alloc] initWithCapacity:sectionNum];
        for (int i = 0; i < sectionNum; i++) {
          [sections addObject:[[NSMutableArray alloc] init]];
        }

        INSERT_SECTIONS(_nodes, [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, sectionNum)], sections, animationOption);

      }];
      
      [self _batchInsertNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOption];

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
  return ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, [indexPaths sortedArrayUsingSelector:@selector(compare:)]);
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

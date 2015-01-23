//  Copyright 2004-present Facebook. All Rights Reserved.

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

//
// The background update is not fully supported yet, although it is trivial to fix it. The underline
// problem is we need to do the profiling between the main thread updating and background updating,
// and then decided which way to go.
//
// For background update, we could avoid the multi-dimensinonal array operation (insertion / deletion)
// on main thread. However, the sideback is we need to dispatch_sync to lock main thread for data query,
// although it is running on a concurrent queue and should be fast enough.
//
// For main thread update, we need to do the multi-dimensional operations (insertion / deletion) on
// main thread, but we will gain the performance in data query. Considering data query is much more
// frequent than data updating, so we keep it on main thread for the initial version.
//
//
#define ENABLE_BACKGROUND_UPDATE 0

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

static void *kASSizingQueueContext = &kASSizingQueueContext;
static void *kASDataUpdatingQueueContext = &kASDataUpdatingQueueContext;

@interface ASDataController () {
  NSMutableArray *_nodes;
}

@property (atomic, assign) NSUInteger batchUpdateCounter;

@end

@implementation ASDataController

- (instancetype)init {
  if (self = [super init]) {
    _nodes = [NSMutableArray array];
    _batchUpdateCounter = 0;
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

/**
 * Concurrent queue for query / updating the cached data.
 * The data query is more frequent than the data updating, so we use dispatch_sync for reading, and dispatch_barrier_async for writing.
 */
+ (dispatch_queue_t)dataUpdatingQueue
{
  static dispatch_queue_t dataUpdatingQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    dataUpdatingQueue = dispatch_queue_create("com.facebook.AsyncDisplayKit.ASDataController.dataUpdatingQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_set_specific(dataUpdatingQueue, kASDataUpdatingQueueContext, kASDataUpdatingQueueContext, NULL);
  });

  return dataUpdatingQueue;
}

+ (BOOL)isDataUpdatingQueue {
  return kASDataUpdatingQueueContext == dispatch_get_specific(kASDataUpdatingQueueContext);
}

- (void)asyncUpdateDataWithBlock:(dispatch_block_t)block {
#if ENABLE_BACKGROUND_UPDATE
  dispatch_barrier_async([ASDataController dataUpdatingQueue], ^{
    block();
  });
#else
  dispatch_async(dispatch_get_main_queue(), ^{
    block();
  });
#endif
}

- (void)syncUpdateDataWithBlock:(dispatch_block_t)block {
#if ENABLE_BACKGROUND_UPDATE
  dispatch_barrier_sync([ASDataController dataUpdatingQueue], ^{
    block();
  });
#else
  dispatch_sync(dispatch_get_main_queue(), ^{
    block();
  });
#endif
}

- (void)queryDataWithBlock:(dispatch_block_t)block {
#if ENABLE_BACKGROUND_UPDATE
  if ([ASDataController isDataUpdatingQueue]) {
    block();
  } else {
    dispatch_sync([ASDataController dataUpdatingQueue], ^{
      block();
    });
  }
#else
  ASDisplayNodeAssertMainThread();
  block();
#endif
}

#pragma mark - Initial Data Loading

- (void)initialDataLoadingWithAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
}

#pragma mark - Data Update

- (void)beginUpdates {
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      _batchUpdateCounter++;
      [_delegate dataControllerBeginUpdates:self];
    }];
  });
}

- (void)endUpdates {
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      _batchUpdateCounter--;
      [_delegate dataControllerEndUpdates:self];
    }];
  });
}

- (void)insertSections:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
}

- (void)deleteSections:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  dispatch_async([[self class] sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_nodes, indexSet);
      
      DELETE_NODES(_nodes, indexPaths, animationOption);
      DELETE_SECTIONS(_nodes, indexSet, animationOption);
    }];
  });
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
 withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
     withAnimationOptions:(ASDataControllerAnimationOptions)animationOption {
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;

  // Processing in batches
  for (NSUInteger i = 0; i < indexPaths.count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(indexPaths.count - i, blockSize));
    NSArray *batchedIndexPaths = [indexPaths subarrayWithRange:batchedRange];
    NSArray *batchedNodes = [nodes subarrayWithRange:batchedRange];

    [self _insertNodes:batchedNodes atIndexPaths:batchedIndexPaths withAnimationOption:animationOption];
  }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  // sort indexPath to avoid messing up the index when inserting in several batches
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
  NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
  for (NSUInteger i = 0; i < sortedIndexPaths.count; i++) {
    [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:sortedIndexPaths[i]]];
  }

  [self _batchInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOption];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
  // sort indexPath in order to avoid messing up the index when deleting
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

  dispatch_async([ASDataController sizingQueue], ^{
    [self asyncUpdateDataWithBlock:^{
      DELETE_NODES(_nodes, sortedIndexPaths, animationOption);
    }];
  });
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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

- (void)reloadDataWithAnimationOption:(ASDataControllerAnimationOptions)animationOption {
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
  });
}

#pragma mark - Data Querying

- (NSUInteger)numberOfSections {
  __block NSUInteger sectionNum;

  [self queryDataWithBlock:^{
    sectionNum = [_nodes count];
  }];

  return sectionNum;
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section {
  __block NSUInteger rowNum;

  [self queryDataWithBlock:^{
    rowNum = [_nodes[section] count];
  }];

  return rowNum;
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath {
  __block ASCellNode *node;

  [self queryDataWithBlock:^{
    node = _nodes[indexPath.section][indexPath.row];
  }];

  return node;
}

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths {
  __block NSArray *arr = nil;

  [self queryDataWithBlock:^{
    arr = ASFindElementsInMultidimensionalArrayAtIndexPaths(_nodes, indexPaths);
  }];

  return arr;
}

@end

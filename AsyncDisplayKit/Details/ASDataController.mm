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
  NSMutableArray *_completedNodes;            // Main thread only.  External data access can immediately query this.
  NSMutableArray *_editingNodes;              // Modified on _editingTransactionQueue only.  Updates propogated to _completedNodes.
  
  NSMutableArray *_pendingEditCommandBlocks;  // To be run on the main thread.  Handles begin/endUpdates tracking.
  NSOperationQueue *_editingTransactionQueue; // Serial background queue.  Dispatches concurrent layout and manages _editingNodes.
  
  BOOL _asyncDataFetchingEnabled;
  BOOL _delegateDidInsertNodes;
  BOOL _delegateDidDeleteNodes;
  BOOL _delegateDidInsertSections;
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
  
  _completedNodes = [NSMutableArray array];
  _editingNodes = [NSMutableArray array];

  _pendingEditCommandBlocks = [NSMutableArray array];
  
  _editingTransactionQueue = [[NSOperationQueue alloc] init];
  _editingTransactionQueue.maxConcurrentOperationCount = 1; // Serial queue
  _editingTransactionQueue.name = @"org.AsyncDisplayKit.ASDataController.editingTransactionQueue";
  
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
  _delegateDidInsertNodes     = [_delegate respondsToSelector:@selector(dataController:didInsertNodes:atIndexPaths:withAnimationOptions:)];
  _delegateDidDeleteNodes     = [_delegate respondsToSelector:@selector(dataController:didDeleteNodesAtIndexPaths:withAnimationOptions:)];
  _delegateDidInsertSections  = [_delegate respondsToSelector:@selector(dataController:didInsertSections:atIndexSet:withAnimationOptions:)];
  _delegateDidDeleteSections  = [_delegate respondsToSelector:@selector(dataController:didDeleteSectionsAtIndexSet:withAnimationOptions:)];
}

+ (NSUInteger)parallelProcessorCount
{
  static NSUInteger parallelProcessorCount;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    parallelProcessorCount = [[NSProcessInfo processInfo] processorCount];
  });

  return parallelProcessorCount;
}

#pragma mark - Cell Layout

- (void)_layoutNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"Cell node layout must be initiated from edit transaction queue");
  
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
  
  // Block the _editingTransactionQueue from executing a new edit transaction until layout is done & _editingNodes array is updated.
  dispatch_group_wait(layoutGroup, DISPATCH_TIME_FOREVER);
  
  // Insert finished nodes into data storage
  [self _insertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
}

- (void)_batchLayoutNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;
  
  // Processing in batches
  for (NSUInteger i = 0; i < indexPaths.count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(indexPaths.count - i, blockSize));
    NSArray *batchedIndexPaths = [indexPaths subarrayWithRange:batchedRange];
    NSArray *batchedNodes = [nodes subarrayWithRange:batchedRange];
    
    [self _layoutNodes:batchedNodes atIndexPaths:batchedIndexPaths withAnimationOptions:animationOptions];
  }
}

#pragma mark - Internal Data Querying + Editing

- (void)_insertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexPaths.count == 0)
    return;
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(_editingNodes, indexPaths, nodes);
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSMutableArray *completedNodes = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(_editingNodes);
  
  ASDisplayNodePerformBlockOnMainThread(^{
    _completedNodes = completedNodes;
    if (_delegateDidInsertNodes)
      [_delegate dataController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)_deleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexPaths.count == 0)
    return;
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_editingNodes, indexPaths);

  ASDisplayNodePerformBlockOnMainThread(^{
    ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_completedNodes, indexPaths);
    if (_delegateDidDeleteNodes)
      [_delegate dataController:self didDeleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
  });
}

- (void)_insertSections:(NSMutableArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexSet.count == 0)
    return;
  [_editingNodes insertObjects:sections atIndexes:indexSet];
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSArray *sectionsForCompleted = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(sections);
  
  ASDisplayNodePerformBlockOnMainThread(^{
    [_completedNodes insertObjects:sectionsForCompleted atIndexes:indexSet];
    if (_delegateDidInsertSections)
      [_delegate dataController:self didInsertSections:sections atIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

- (void)_deleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  if (indexSet.count == 0)
    return;
  [_editingNodes removeObjectsAtIndexes:indexSet];
  ASDisplayNodePerformBlockOnMainThread(^{
    [_completedNodes removeObjectsAtIndexes:indexSet];
    if (_delegateDidDeleteSections)
      [_delegate dataController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  });
}

#pragma mark - Initial Load & Full Reload (External API)

- (void)initialDataLoadingWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [self accessDataSourceWithBlock:^{
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
  }];
}

- (void)reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions completion:(void (^)())completion
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [self accessDataSourceWithBlock:^{
      NSUInteger sectionCount = [_dataSource dataControllerNumberOfSections:self];
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromEntireDataSourceWithMutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        // Remove everything that existed before the reload, now that we're ready to insert replacements
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArray(_editingNodes);
        [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
        
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, _editingNodes.count)];
        [self _deleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
        
        // Insert each section
        NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
        for (int i = 0; i < sectionCount; i++) {
          [sections addObject:[[NSMutableArray alloc] init]];
        }
        
        [self _insertSections:sections atIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)] withAnimationOptions:animationOptions];
        
        [self _batchLayoutNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
        
        if (completion) {
          dispatch_async(dispatch_get_main_queue(), completion);
        }
      }];
    }];
  }];
}

#pragma mark - Data Source Access (Calling _dataSource)

- (void)accessDataSourceWithBlock:(dispatch_block_t)block
{
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

- (void)_populateFromDataSourceWithSectionIndexSet:(NSIndexSet *)indexSet mutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = [_dataSource dataController:self rowsInSection:idx];
    
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = 0; i < rowNum; i++) {
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
      [indexPaths addObject:indexPath];
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
    }
  }];
}

- (void)_populateFromEntireDataSourceWithMutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  NSUInteger sectionNum = [_dataSource dataControllerNumberOfSections:self];
  for (NSUInteger i = 0; i < sectionNum; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    
    NSUInteger rowNum = [_dataSource dataController:self rowsInSection:i];
    for (NSUInteger j = 0; j < rowNum; j++) {
      NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];
      [indexPaths addObject:indexPath];
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
    }
  }
}


#pragma mark - Batching (External API)

- (void)beginUpdates
{
  // Begin queuing up edit calls that happen on the main thread.
  // This will prevent further operations from being scheduled on _editingTransactionQueue.
  // It's fine if there is an in-flight operation on _editingTransactionQueue,
  // as once the command queue is unpaused, each edit command will wait for the _editingTransactionQueue to be flushed.
  _batchUpdateCounter++;
}

- (void)endUpdates
{
  [self endUpdatesWithCompletion:NULL];
}

- (void)endUpdatesWithCompletion:(void (^)(BOOL))completion
{
  _batchUpdateCounter--;

  if (_batchUpdateCounter == 0) {
    [_delegate dataControllerBeginUpdates:self];
    // Running these commands may result in blocking on an _editingTransactionQueue operation that started even before -beginUpdates.
    // Each subsequent command in the queue will also wait on the full asynchronous completion of the prior command's edit transaction.
    [_pendingEditCommandBlocks enumerateObjectsUsingBlock:^(dispatch_block_t block, NSUInteger idx, BOOL *stop) {
      block();
    }];
    [_pendingEditCommandBlocks removeAllObjects];

    [_delegate dataControllerEndUpdates:self completion:completion];
  }
}

- (void)performEditCommandWithBlock:(void (^)(void))block
{
  // This method needs to block the thread and synchronously perform the operation if we are not
  // queuing commands for begin/endUpdates.  If we are queuing, it needs to return immediately.
  if (_batchUpdateCounter == 0) {
    block();
  } else {
    [_pendingEditCommandBlocks addObject:block];
  }
}

#pragma mark - Section Editing (External API)

- (void)insertSections:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [self accessDataSourceWithBlock:^{
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:indexSet mutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:indexSet.count];
        for (NSUInteger i = 0; i < indexSet.count; i++) {
          [sectionArray addObject:[NSMutableArray array]];
        }
        
        [self _insertSections:sectionArray atIndexSet:indexSet withAnimationOptions:animationOptions];
        [self _batchLayoutNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)deleteSections:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [_editingTransactionQueue addOperationWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes, indexSet);
      
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
      [self _deleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
    }];
  }];
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [self accessDataSourceWithBlock:^{
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:sections mutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];

      // Dispatch to sizing queue in order to guarantee that any in-progress sizing operations from prior edits have completed.
      // For example, if an initial -reloadData call is quickly followed by -reloadSections, sizing the initial set may not be done
      // at this time.  Thus _editingNodes could be empty and crash in ASIndexPathsForMultidimensional[...]
      
      [_editingTransactionQueue addOperationWithBlock:^{
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes, sections);
        [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
        
        // reinsert the elements
        [self _batchLayoutNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      // remove elements
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes, [NSIndexSet indexSetWithIndex:section]);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes, indexPaths);
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

      // update the section of indexpaths
      NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:newSection];
      NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [updatedIndexPaths addObject:[sectionIndexPath indexPathByAddingIndex:[indexPath indexAtPosition:indexPath.length - 1]]];
      }];

      // Don't re-calculate size for moving
      [self _insertNodes:nodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

#pragma mark - Row Editing (External API)

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [self accessDataSourceWithBlock:^{
      // sort indexPath to avoid messing up the index when inserting in several batches
      NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
      NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      for (NSUInteger i = 0; i < sortedIndexPaths.count; i++) {
        [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:sortedIndexPaths[i]]];
      }
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self _batchLayoutNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    // sort indexPath in order to avoid messing up the index when deleting
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

    [_editingTransactionQueue addOperationWithBlock:^{
      [self _deleteNodesAtIndexPaths:sortedIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    // Reloading requires re-fetching the data.  Load it on the current calling thread, locking the data source.
    [self accessDataSourceWithBlock:^{
      NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      [indexPaths sortedArrayUsingSelector:@selector(compare:)];
      [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
      }];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
        [self _batchLayoutNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes, [NSArray arrayWithObject:indexPath]);
      NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

      // Don't re-calculate size for moving
      NSArray *newIndexPaths = [NSArray arrayWithObject:newIndexPath];
      [self _insertNodes:nodes atIndexPaths:newIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

#pragma mark - Data Querying (External API)

- (NSUInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  return [_completedNodes count];
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [_completedNodes[section] count];
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  return _completedNodes[indexPath.section][indexPath.row];
}

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  return ASFindElementsInMultidimensionalArrayAtIndexPaths(_completedNodes, [indexPaths sortedArrayUsingSelector:@selector(compare:)]);
}

- (NSArray *)completedNodes
{
  ASDisplayNodeAssertMainThread();
  return _completedNodes;
}

#pragma mark - Dealloc

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  [_completedNodes enumerateObjectsUsingBlock:^(NSMutableArray *section, NSUInteger sectionIndex, BOOL *stop) {
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

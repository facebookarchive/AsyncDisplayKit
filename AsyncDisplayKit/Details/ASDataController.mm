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
#import "ASFlowLayoutController.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASMainSerialQueue.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASThread.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

NSString * const ASDataControllerRowNodeKind = @"_ASDataControllerRowNodeKind";

static void *kASSizingQueueContext = &kASSizingQueueContext;

@interface ASDataController () {
  NSMutableDictionary *_completedNodes;       // Main thread only.  External data access can immediately query this if _externalCompletedNodes is unavailable.
  NSMutableDictionary *_editingNodes;         // Modified on _editingTransactionQueue only.  Updates propogated to _completedNodes.
  
  ASMainSerialQueue *_mainSerialQueue;
  
  NSMutableArray *_pendingEditCommandBlocks;  // To be run on the main thread.  Handles begin/endUpdates tracking.
  NSOperationQueue *_editingTransactionQueue; // Serial background queue.  Dispatches concurrent layout and manages _editingNodes.
  
  BOOL _asyncDataFetchingEnabled;

  BOOL _delegateDidInsertNodes;
  BOOL _delegateDidReloadNodes;
  BOOL _delegateDidDeleteNodes;
  BOOL _delegateDidMoveNode;
  BOOL _delegateDidInsertSections;
  BOOL _delegateDidDeleteSections;
  BOOL _delegateDidReloadSections;
  BOOL _delegateDidMoveSection;
  BOOL _delegateDidReloadData;
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
  
  _completedNodes = [NSMutableDictionary dictionary];
  _editingNodes = [NSMutableDictionary dictionary];

  _completedNodes[ASDataControllerRowNodeKind] = [NSMutableArray array];
  _editingNodes[ASDataControllerRowNodeKind] = [NSMutableArray array];
  
  _mainSerialQueue = [[ASMainSerialQueue alloc] init];
  
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
  _delegateDidDeleteNodes     = [_delegate respondsToSelector:@selector(dataController:didDeleteNodes:atIndexPaths:withAnimationOptions:)];
  _delegateDidReloadNodes     = [_delegate respondsToSelector:@selector(dataController:didReloadNodes:atIndexPaths:withAnimationOptions:)];
  _delegateDidMoveNode        = [_delegate respondsToSelector:@selector(dataController:didMoveNodeAtIndexPath:toIndexPath:)];
  _delegateDidInsertSections  = [_delegate respondsToSelector:@selector(dataController:didInsertSectionsAtIndexSet:withAnimationOptions:)];
  _delegateDidReloadSections  = [_delegate respondsToSelector:@selector(dataController:didReloadSectionsAtIndexSet:withAnimationOptions:)];
  _delegateDidDeleteSections  = [_delegate respondsToSelector:@selector(dataController:didDeleteSectionsAtIndexSet:withAnimationOptions:)];
  _delegateDidMoveSection     = [_delegate respondsToSelector:@selector(dataController:didMoveSection:toSection:)];
  _delegateDidReloadData      = [_delegate respondsToSelector:@selector(dataControllerDidReloadData:)];
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

- (void)layoutAndInsertFromNodeBlocks:(NSArray<ASCellNodeBlock> *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths completion:(void (^)(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths))completionBlock
{
  [self _layoutNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths];
    if (completionBlock) {
      completionBlock(nodes, indexPaths);
    }
  }];
}

- (void)layoutLoadedNodes:(NSArray<ASCellNode *> *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
  NSAssert(NSThread.isMainThread, @"Main thread layout must be on the main thread.");
  
  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, __unused BOOL * stop) {
    ASCellNode *node = nodes[idx];
    if (node.isNodeLoaded) {
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
      [self _layoutNode:node withConstrainedSize:constrainedSize];
    }
  }];
}

/**
 * Measure and layout the given node with the constrained size range.
 */
- (void)_layoutNode:(ASCellNode *)node withConstrainedSize:(ASSizeRange)constrainedSize
{
  [node measureWithSizeRange:constrainedSize];
  node.frame = CGRectMake(0.0f, 0.0f, node.calculatedSize.width, node.calculatedSize.height);
}

- (void)_layoutNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock
{
  if (!nodes.count) {
      if (completionBlock) {
          completionBlock(nodes, indexPaths);
      }
      return;
  }

  NSUInteger nodeCount = nodes.count;
  NSMutableArray<ASCellNode *> *allocatedNodes = [NSMutableArray<ASCellNode *> arrayWithCapacity:nodeCount];
  dispatch_group_t layoutGroup = dispatch_group_create();
  ASSizeRange *nodeBoundSizes = (ASSizeRange *)malloc(sizeof(ASSizeRange) * nodeCount);

  for (NSUInteger j = 0; j < nodes.count && j < indexPaths.count; j += kASDataControllerSizingCountPerProcessor) {
    NSInteger batchCount = MIN(kASDataControllerSizingCountPerProcessor, indexPaths.count - j);

    __block NSArray *subarray;
    // Allocate nodes concurrently.
    dispatch_block_t allocationBlock = ^{
      __strong ASCellNode **allocatedNodeBuffer = (__strong ASCellNode **)calloc(batchCount, sizeof(ASCellNode *));
      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      dispatch_apply(batchCount, queue, ^(size_t i) {
        unsigned long k = j + i;
        ASCellNodeBlock cellBlock = nodes[k];
        ASCellNode *node = cellBlock();
        ASDisplayNodeAssertNotNil(node, @"Node block created nil node");
        allocatedNodeBuffer[i] = node;
        if (!node.isNodeLoaded) {
          nodeBoundSizes[k] = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPaths[k]];
        }
      });
      subarray = [[NSArray alloc] initWithObjects:allocatedNodeBuffer count:batchCount];

      // Nil out buffer indexes to allow arc to free the stored cells.
      for (int i = 0; i < batchCount; i++) {
        allocatedNodeBuffer[i] = nil;
      }
      free(allocatedNodeBuffer);
    };

    if (ASDisplayNodeThreadIsMain()) {
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        allocationBlock();
        dispatch_semaphore_signal(sema);
      });
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
      [self layoutLoadedNodes:subarray ofKind:kind atIndexPaths:[indexPaths subarrayWithRange:NSMakeRange(j, batchCount)]];
    } else {
      allocationBlock();
      [_mainSerialQueue performBlockOnMainThread:^{
        [self layoutLoadedNodes:subarray ofKind:kind atIndexPaths:[indexPaths subarrayWithRange:NSMakeRange(j, batchCount)]];
      }];
    }

    [allocatedNodes addObjectsFromArray:subarray];

    dispatch_group_async(layoutGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      for (NSUInteger k = j; k < j + batchCount; k++) {
        ASCellNode *node = allocatedNodes[k];
        // Only measure nodes whose views aren't loaded, since we're in the background.
        // We should already have measured loaded nodes before we left the main thread, using layoutLoadedNodes:ofKind:atIndexPaths:
        if (!node.isNodeLoaded) {
          [self _layoutNode:node withConstrainedSize:nodeBoundSizes[k]];
        }
      }
    });
  }

  // Block the _editingTransactionQueue from executing a new edit transaction until layout is done & _editingNodes array is updated.
  dispatch_group_wait(layoutGroup, DISPATCH_TIME_FOREVER);
  free(nodeBoundSizes);

  if (completionBlock) {
    completionBlock(allocatedNodes, indexPaths);
  }
}

- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return [_dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath];
}

#pragma mark - External Data Querying + Editing

- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths
{
  if (indexPaths.count == 0)
    return;

  LOG(@"insertNodes:%@ ofKind:%@", nodes, kind);
  NSMutableArray *editingNodes = _editingNodes[kind];
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths, nodes);
  _editingNodes[kind] = editingNodes;
}

- (NSArray *)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths
{
  if (indexPaths.count == 0) {
    return @[];
  }

  LOG(@"_deleteNodesAtIndexPaths:%@ ofKind:%@,", indexPaths, kind);
  NSMutableArray *editingNodes = _editingNodes[kind];
  NSArray *deletedNodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes[kind], indexPaths);
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths);
  _editingNodes[kind] = editingNodes;
  return deletedNodes;
}

- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet{
  if (indexSet.count == 0)
    return;

  LOG(@"insertSections:%@ ofKind:%@", sections, kind);
  if (_editingNodes[kind] == nil) {
    _editingNodes[kind] = [NSMutableArray array];
  }
  
  [_editingNodes[kind] insertObjects:sections atIndexes:indexSet];
}

- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet
{
  if (indexSet.count == 0)
    return;

  LOG(@"deleteSectionsOfKind:%@", kind);
  [_editingNodes[kind] removeObjectsAtIndexes:indexSet];
}

- (void)moveSection:(NSInteger)section ofKind:(NSString *)kind toSection:(NSInteger)newSection
{
  NSArray *movedSection = _editingNodes[kind][section];
  [_editingNodes[kind] removeObjectAtIndex:section];
  [_editingNodes[kind] insertObject:movedSection atIndex:newSection];
}

- (void)commitChangesToNodesOfKind:(NSString *)kind withCompletion:(void (^)())completionBlock
{
  NSMutableArray *completedNodes = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(_editingNodes[kind]);

  [_mainSerialQueue performBlockOnMainThread:^{
    _completedNodes[kind] = completedNodes;
    if (completionBlock) {
      completionBlock();
    }
  }];
}

#pragma mark - Reload (External API)

- (void)reloadDataWithCompletion:(void (^)())completion
{
  [self _reloadDataSynchronously:NO completion:completion];
}

- (void)reloadDataImmediately
{
  [self _reloadDataSynchronously:YES completion:nil];
}

- (void)_reloadDataSynchronously:(BOOL)synchronously completion:(void (^)())completion
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [self accessDataSourceSynchronously:synchronously withBlock:^{
      NSUInteger sectionCount = [_dataSource numberOfSectionsInDataController:self];
      NSMutableArray *updatedNodeBlocks = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromEntireDataSourceWithMutableNodes:updatedNodeBlocks mutableIndexPaths:updatedIndexPaths];

      // Allow subclasses to perform setup before going into the edit transaction
      [self prepareForReloadData];
      
      void (^transactionBlock)() = ^{
        LOG(@"Edit Transaction - reloadData");

        [self willReloadData];

        // Insert sections
        NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
        for (int i = 0; i < sectionCount; i++) {
          [sections addObject:[[NSMutableArray alloc] init]];
        }
        _editingNodes[ASDataControllerRowNodeKind] = sections;

        [self layoutAndInsertFromNodeBlocks:updatedNodeBlocks ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
          [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
              if (_delegateDidReloadData) {
                  [_delegate dataControllerDidReloadData:self];
              }
              if (completion) {
                  completion();
              }
          }];
        }];
      };
      
      if (synchronously) {
        transactionBlock();
      } else {
        [_editingTransactionQueue addOperationWithBlock:transactionBlock];
      }
    }];
  }];
}

#pragma mark - Data Source Access (Calling _dataSource)

/**
 * Safely locks access to the data source and executes the given block, unlocking once complete.
 *
 * @discussion When `asyncDataFetching` is enabled, the block is executed on a background thread.
 */
- (void)accessDataSourceWithBlock:(dispatch_block_t)block
{
  [self accessDataSourceSynchronously:NO withBlock:block];
}

- (void)accessDataSourceSynchronously:(BOOL)synchronously withBlock:(dispatch_block_t)block
{
  if (!synchronously && _asyncDataFetchingEnabled) {
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

/**
 * Fetches row nodes and their specified index paths for the provided sections from the data source.
 *
 * @discussion Results are stored in the passed mutable arrays.
 */
- (void)_populateFromDataSourceWithSectionIndexSet:(NSIndexSet *)indexSet mutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = [_dataSource dataController:self rowsInSection:idx];
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = 0; i < rowNum; i++) {
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
      [indexPaths addObject:indexPath];
      [nodes addObject:[_dataSource dataController:self nodeBlockAtIndexPath:indexPath]];
    }
  }];
}

/**
 * Fetches row nodes and their specified index paths for all sections from the data source.
 *
 * @discussion Results are stored in the passed mutable arrays.
 */
- (void)_populateFromEntireDataSourceWithMutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  NSUInteger sectionNum = [_dataSource numberOfSectionsInDataController:self];
  for (NSUInteger i = 0; i < sectionNum; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    NSUInteger rowNum = [_dataSource dataController:self rowsInSection:i];
    for (NSUInteger j = 0; j < rowNum; j++) {
      NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];
      [indexPaths addObject:indexPath];
      [nodes addObject:[_dataSource dataController:self nodeBlockAtIndexPath:indexPath]];
    }
  }
}


#pragma mark - Batching (External API)

- (void)beginUpdates
{
  [_editingTransactionQueue waitUntilAllOperationsAreFinished];
  // Begin queuing up edit calls that happen on the main thread.
  // This will prevent further operations from being scheduled on _editingTransactionQueue.
  _batchUpdateCounter++;
}

- (void)endUpdates
{
  [self endUpdatesAnimated:YES completion:nil];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  _batchUpdateCounter--;

  if (_batchUpdateCounter == 0 && _pendingEditCommandBlocks.count > 0) {
    LOG(@"endUpdatesWithCompletion - beginning");

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [_mainSerialQueue performBlockOnMainThread:^{
      [_delegate dataControllerBeginUpdates:self];
    }];

    // Running these commands may result in blocking on an _editingTransactionQueue operation that started even before -beginUpdates.
    // Each subsequent command in the queue will also wait on the full asynchronous completion of the prior command's edit transaction.
    LOG(@"endUpdatesWithCompletion - %zd blocks to run", _pendingEditCommandBlocks.count);
    [_pendingEditCommandBlocks enumerateObjectsUsingBlock:^(dispatch_block_t block, NSUInteger idx, BOOL *stop) {
      LOG(@"endUpdatesWithCompletion - running block #%zd", idx);
      block();
    }];
    [_pendingEditCommandBlocks removeAllObjects];

    [_editingTransactionQueue addOperationWithBlock:^{
      [_mainSerialQueue performBlockOnMainThread:^{
        [_delegate dataController:self endUpdatesAnimated:animated completion:completion];
      }];
    }];
  }
}

/**
 * Queues the given operation until an `endUpdates` synchronize update is completed.
 *
 * If this method is called outside of a begin/endUpdates batch update, the block is
 * executed immediately.
 */
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

- (void)insertSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - insertSections: %@", sections);
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [self accessDataSourceWithBlock:^{
      NSMutableArray *updatedNodeBlocks = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:sections mutableNodes:updatedNodeBlocks mutableIndexPaths:updatedIndexPaths];

      [self prepareForInsertSections:sections];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self willInsertSections:sections];

        LOG(@"Edit Transaction - insertSections: %@", sections);
        NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
        for (NSUInteger i = 0; i < sections.count; i++) {
          [sectionArray addObject:[NSMutableArray array]];
        }

        [self insertSections:sectionArray ofKind:ASDataControllerRowNodeKind atIndexSet:sections];

        [self layoutAndInsertFromNodeBlocks:updatedNodeBlocks ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
          [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
              if (_delegateDidInsertSections)
                  [_delegate dataController:self didInsertSectionsAtIndexSet:sections withAnimationOptions:animationOptions];
          }];
        }];
      }];
    }];
  }];
}

- (void)deleteSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - deleteSections: %@", sections);
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [_editingTransactionQueue addOperationWithBlock:^{
      [self willDeleteSections:sections];

      // remove elements
      LOG(@"Edit Transaction - deleteSections: %@", sections);

      [self deleteSectionsOfKind:ASDataControllerRowNodeKind atIndexSet:sections];
      [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
        if (_delegateDidDeleteSections)
          [_delegate dataController:self didDeleteSectionsAtIndexSet:sections withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - reloadSections: %@", sections);
    
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [self accessDataSourceWithBlock:^{
      NSMutableArray *updatedNodeBlocks = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:sections mutableNodes:updatedNodeBlocks mutableIndexPaths:updatedIndexPaths];

      [self prepareForReloadSections:sections];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self willReloadSections:sections];

        // clear sections
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
          _editingNodes[ASDataControllerRowNodeKind][idx] = [[NSMutableArray alloc] init];
        }];

        [self layoutAndInsertFromNodeBlocks:updatedNodeBlocks ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
          [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
              if (_delegateDidReloadSections)
                  [_delegate dataController:self didReloadSectionsAtIndexSet:sections withAnimationOptions:animationOptions];
          }];
        }];
      }];
    }];
  }];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - moveSection");

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      [self willMoveSection:section toSection:newSection];
      
      LOG(@"Edit Transaction - moveSection");
      [self moveSection:section ofKind:ASDataControllerRowNodeKind toSection:newSection];
      [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
        if (_delegateDidMoveSection) {
          [_delegate dataController:self didMoveSection:section toSection:newSection];
        }
      }];
    }];
  }];
}


#pragma mark - Backing store manipulation optional hooks (Subclass API)

- (void)prepareForReloadData
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willReloadData
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)prepareForInsertSections:(NSIndexSet *)sections
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willInsertSections:(NSIndexSet *)sections
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willDeleteSections:(NSIndexSet *)sections
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)prepareForReloadSections:(NSIndexSet *)sections
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willReloadSections:(NSIndexSet *)sections
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

#pragma mark - Row Editing (External API)

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - insertRows: %@", indexPaths);
    
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [self accessDataSourceWithBlock:^{
      // sort indexPath to avoid messing up the index when inserting in several batches
      NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
      NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      for (NSUInteger i = 0; i < sortedIndexPaths.count; i++) {
        [nodes addObject:[_dataSource dataController:self nodeBlockAtIndexPath:sortedIndexPaths[i]]];
      }

      [_editingTransactionQueue addOperationWithBlock:^{
        LOG(@"Edit Transaction - insertRows: %@", indexPaths);
        [self layoutAndInsertFromNodeBlocks:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
          [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
            if (_delegateDidInsertNodes)
              [_delegate dataController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
          }];
        }];
      }];
    }];
  }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - deleteRows: %@", indexPaths);

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    // sort indexPath in order to avoid messing up the index when deleting
    // FIXME: Shouldn't deletes be sorted in descending order?
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

    [_editingTransactionQueue addOperationWithBlock:^{
      LOG(@"Edit Transaction - deleteRows: %@", indexPaths);
      NSArray *deletedNodes = [self deleteNodesOfKind:ASDataControllerRowNodeKind atIndexPaths:sortedIndexPaths];
      [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
        if (_delegateDidDeleteNodes)
          [_delegate dataController:self didDeleteNodes:deletedNodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
      }];
    }];
  }];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - reloadRows: %@", indexPaths);

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    // Reloading requires re-fetching the data.  Load it on the current calling thread, locking the data source.
    [self accessDataSourceWithBlock:^{
      NSMutableArray *nodeBlocks = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      
      // FIXME: This doesn't currently do anything
      // FIXME: Shouldn't deletes be sorted in descending order?
      [indexPaths sortedArrayUsingSelector:@selector(compare:)];
      
      for (NSIndexPath *indexPath in indexPaths) {
        [nodeBlocks addObject:[_dataSource dataController:self nodeBlockAtIndexPath:indexPath]];
      }

      [_editingTransactionQueue addOperationWithBlock:^{
        LOG(@"Edit Transaction - reloadRows: %@", indexPaths);
        [self deleteNodesOfKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths];
        [self layoutAndInsertFromNodeBlocks:nodeBlocks ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
          [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
            if (_delegateDidReloadNodes)
              [_delegate dataController:self didReloadNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
          }];
        }];
      }];
    }];
  }];
}

- (void)relayoutAllNodes
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - relayoutRows");
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    // Can't relayout right away because _completedNodes may not be up-to-date,
    // i.e there might be some nodes that were measured using the old constrained size but haven't been added to _completedNodes
    // (see _layoutNodes:atIndexPaths:withAnimationOptions:).
    [_editingTransactionQueue addOperationWithBlock:^{
      [_mainSerialQueue performBlockOnMainThread:^{
        for (NSString *kind in [_completedNodes keyEnumerator]) {
          [self _relayoutNodesOfKind:kind];
        }
      }];
    }];
  }];
}

- (void)_relayoutNodesOfKind:(NSString *)kind
{
  ASDisplayNodeAssertMainThread();
  NSArray *nodes = [self completedNodesOfKind:kind];
  if (!nodes.count) {
    return;
  }
  
  [self accessDataSourceWithBlock:^{
    [nodes enumerateObjectsUsingBlock:^(NSMutableArray *section, NSUInteger sectionIndex, BOOL *stop) {
      [section enumerateObjectsUsingBlock:^(ASCellNode *node, NSUInteger rowIndex, BOOL *stop) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
        ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
        ASLayout *layout = [node measureWithSizeRange:constrainedSize];
        node.frame = CGRectMake(0.0f, 0.0f, layout.size.width, layout.size.height);
      }];
    }];
  }];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - moveRow: %@ > %@", indexPath, newIndexPath);
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      LOG(@"Edit Transaction - moveRow: %@ > %@", indexPath, newIndexPath);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes[ASDataControllerRowNodeKind], [NSArray arrayWithObject:indexPath]);
      [self deleteNodesOfKind:ASDataControllerRowNodeKind atIndexPaths:@[indexPath]];

      // Don't re-calculate size for moving
      [self insertNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:@[newIndexPath]];
      [self commitChangesToNodesOfKind:ASDataControllerRowNodeKind withCompletion:^{
        if (_delegateDidMoveNode) {
          [_delegate dataController:self didMoveNodeAtIndexPath:indexPath toIndexPath:newIndexPath];
        }
      }];
    }];
  }];
}

#pragma mark - Data Querying (Subclass API)

- (NSMutableDictionary *)editingNode{
  return _editingNodes;
}

- (NSMutableArray *)completedNodesOfKind:(NSString *)kind
{
  return _completedNodes[kind];
}

#pragma mark - Data Querying (External API)

- (NSUInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  return [[self completedNodes] count];
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section
{
  ASDisplayNodeAssertMainThread();
  NSArray *completedNodes = [self completedNodes];
  return (section < completedNodes.count) ? [completedNodes[section] count] : 0;
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  
  NSArray *completedNodes = [self completedNodes];
  NSInteger section = indexPath.section;
  NSInteger row = indexPath.row;
  ASCellNode *node = nil;
  
  if (section >= 0 && row >= 0 && section < completedNodes.count) {
    NSArray *completedNodesSection = completedNodes[section];
    if (row < completedNodesSection.count) {
      node = completedNodesSection[row];
    }
  }
  
  return node;
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;
{
  ASDisplayNodeAssertMainThread();

  NSArray *nodes = [self completedNodes];
  NSUInteger numberOfNodes = nodes.count;
  
  // Loop through each section to look for the cellNode
  for (NSUInteger i = 0; i < numberOfNodes; i++) {
    NSArray *sectionNodes = nodes[i];
    NSUInteger cellIndex = [sectionNodes indexOfObjectIdenticalTo:cellNode];
    if (cellIndex != NSNotFound) {
      return [NSIndexPath indexPathForRow:cellIndex inSection:i];
    }
  }
  
  return nil;
}

- (NSArray *)nodesAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  return ASFindElementsInMultidimensionalArrayAtIndexPaths((NSMutableArray *)[self completedNodes], [indexPaths sortedArrayUsingSelector:@selector(compare:)]);
}

- (NSArray *)completedNodes
{
  ASDisplayNodeAssertMainThread();
  return _completedNodes[ASDataControllerRowNodeKind];
}

#pragma mark - Dealloc

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  [_completedNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    [nodes enumerateObjectsUsingBlock:^(NSMutableArray *section, NSUInteger sectionIndex, BOOL *stop) {
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
  }];
}

@end

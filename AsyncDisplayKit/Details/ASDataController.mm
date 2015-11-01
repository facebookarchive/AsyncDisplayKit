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
#import "ASInternalHelpers.h"
#import "ASLayout.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

NSString * const ASDataControllerRowNodeKind = @"_ASDataControllerRowNodeKind";

static void *kASSizingQueueContext = &kASSizingQueueContext;

@interface ASDataController () {
  NSMutableArray *_externalCompletedNodes;    // Main thread only.  External data access can immediately query this if available.
  NSMutableDictionary *_completedNodes;       // Main thread only.  External data access can immediately query this if _externalCompletedNodes is unavailable.
  NSMutableDictionary *_editingNodes;         // Modified on _editingTransactionQueue only.  Updates propogated to _completedNodes.
  
  
  
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
  
  _completedNodes = [NSMutableDictionary dictionary];
  _editingNodes = [NSMutableDictionary dictionary];

  _completedNodes[ASDataControllerRowNodeKind] = [NSMutableArray array];
  _editingNodes[ASDataControllerRowNodeKind] = [NSMutableArray array];
  
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

- (void)batchLayoutNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock
{
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;
  
  // Processing in batches
  for (NSUInteger i = 0; i < indexPaths.count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(indexPaths.count - i, blockSize));
    NSArray *batchedIndexPaths = [indexPaths subarrayWithRange:batchedRange];
    NSArray *batchedNodes = [nodes subarrayWithRange:batchedRange];
    
    [self _layoutNodes:batchedNodes ofKind:kind atIndexPaths:batchedIndexPaths completion:completionBlock];
  }
}

- (void)layoutLoadedNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths {
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

/**
 * Measures and defines the layout for each node in optimized batches on an editing queue, inserting the results into the backing store.
 */
- (void)_batchLayoutNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self batchLayoutNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    // Insert finished nodes into data storage
    [self _insertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

- (void)_layoutNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock
{
  if (!nodes.count) {
    return;
  }
  
  dispatch_group_t layoutGroup = dispatch_group_create();
  ASSizeRange *nodeBoundSizes = (ASSizeRange *)malloc(sizeof(ASSizeRange) * nodes.count);
  for (NSUInteger j = 0; j < nodes.count && j < indexPaths.count; j += kASDataControllerSizingCountPerProcessor) {
    NSInteger batchCount = MIN(kASDataControllerSizingCountPerProcessor, indexPaths.count - j);
    
    for (NSUInteger k = j; k < j + batchCount; k++) {
      ASCellNode *node = nodes[k];
      if (!node.isNodeLoaded) {
        nodeBoundSizes[k] = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPaths[k]];
      }
    }
    
    dispatch_group_async(layoutGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      for (NSUInteger k = j; k < j + batchCount; k++) {
        ASCellNode *node = nodes[k];
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
    completionBlock(nodes, indexPaths);
  }
}

- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return [_dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath];
}

#pragma mark - External Data Querying + Editing

- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock
{
  if (indexPaths.count == 0)
    return;

  NSMutableArray *editingNodes = _editingNodes[kind];
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths, nodes);
  _editingNodes[kind] = editingNodes;
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSMutableArray *completedNodes = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(editingNodes);
  
  ASPerformBlockOnMainThread(^{
    _completedNodes[kind] = completedNodes;
    if (completionBlock) {
      completionBlock(nodes, indexPaths);
    }
  });
}

- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(void (^)(NSArray *nodes, NSArray *indexPaths))completionBlock
{
  if (indexPaths.count == 0) {
    return;
  }

  LOG(@"_deleteNodesAtIndexPaths:%@ ofKind:%@, full index paths in _editingNodes = %@", indexPaths, kind, ASIndexPathsForMultidimensionalArray(_editingNodes[kind]));
  NSMutableArray *editingNodes = _editingNodes[kind];
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths);
  _editingNodes[kind] = editingNodes;

  ASPerformBlockOnMainThread(^{
    NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_completedNodes[kind], indexPaths);
    ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_completedNodes[kind], indexPaths);
    if (completionBlock) {
      completionBlock(nodes, indexPaths);
    }
  });
}

- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock
{
  if (indexSet.count == 0)
    return;

  if (_editingNodes[kind] == nil) {
    _editingNodes[kind] = [NSMutableArray array];
  }
  
  [_editingNodes[kind] insertObjects:sections atIndexes:indexSet];
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSArray *sectionsForCompleted = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(sections);
  
  ASPerformBlockOnMainThread(^{
    [_completedNodes[kind] insertObjects:sectionsForCompleted atIndexes:indexSet];
    if (completionBlock) {
      completionBlock(sections, indexSet);
    }
  });
}

- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock
{
  if (indexSet.count == 0)
    return;
  [_editingNodes[kind] removeObjectsAtIndexes:indexSet];
  ASPerformBlockOnMainThread(^{
    [_completedNodes[kind] removeObjectsAtIndexes:indexSet];
    if (completionBlock) {
      completionBlock(indexSet);
    }
  });
}

#pragma mark - Internal Data Querying + Editing

/**
 * Inserts the specified nodes into the given index paths and notifies the delegate of newly inserted nodes.
 *
 * @discussion Nodes are first inserted into the editing store, then the completed store is replaced by a deep copy
 * of the editing nodes. The delegate is invoked on the main thread.
 */
- (void)_insertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self insertNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    if (_delegateDidInsertNodes)
      [_delegate dataController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

/**
 * Removes the specified nodes at the given index paths and notifies the delegate of the nodes removed.
 *
 * @discussion Nodes are first removed from the editing store then removed from the completed store on the main thread.
 * Once the backing stores are consistent, the delegate is invoked on the main thread.
 */
- (void)_deleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self deleteNodesOfKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    if (_delegateDidDeleteNodes)
      [_delegate dataController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

/**
 * Inserts sections, represented as arrays, into the backing store at the given indicies and notifies the delegate.
 *
 * @discussion The section arrays are inserted into the editing store, then a deep copy of the sections are inserted
 * in the completed store on the main thread. The delegate is invoked on the main thread.
 */
- (void)_insertSections:(NSMutableArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self insertSections:sections ofKind:ASDataControllerRowNodeKind atIndexSet:indexSet completion:^(NSArray *sections, NSIndexSet *indexSet) {
    if (_delegateDidInsertSections)
      [_delegate dataController:self didInsertSections:sections atIndexSet:indexSet withAnimationOptions:animationOptions];
  }];
}

/**
 * Removes sections at the given indicies from the backing store and notifies the delegate.
 *
 * @discussion Section array are first removed from the editing store, then the associated section in the completed
 * store is removed on the main thread. The delegate is invoked on the main thread.
 */
- (void)_deleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self deleteSectionsOfKind:ASDataControllerRowNodeKind atIndexSet:indexSet completion:^(NSIndexSet *indexSet) {
    if (_delegateDidDeleteSections)
      [_delegate dataController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  }];
}

#pragma mark - Initial Load & Full Reload (External API)

- (void)initialDataLoadingWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [self accessDataSourceWithBlock:^{
      NSMutableArray *indexPaths = [NSMutableArray array];
      NSUInteger sectionNum = [_dataSource numberOfSectionsInDataController:self];

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
  [self _reloadDataWithAnimationOptions:animationOptions synchronously:NO completion:completion];
}

- (void)reloadDataImmediatelyWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self _reloadDataWithAnimationOptions:animationOptions synchronously:YES completion:nil];
}

- (void)_reloadDataWithAnimationOptions:(ASDataControllerAnimationOptions)animationOptions synchronously:(BOOL)synchronously completion:(void (^)())completion
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    [self accessDataSourceSynchronously:synchronously withBlock:^{
      NSUInteger sectionCount = [_dataSource numberOfSectionsInDataController:self];
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromEntireDataSourceWithMutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];
      
      // Measure nodes whose views are loaded before we leave the main thread
      [self layoutLoadedNodes:updatedNodes ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths];

      // Allow subclasses to perform setup before going into the edit transaction
      [self prepareForReloadData];
      
      void (^transactionBlock)() = ^{
        LOG(@"Edit Transaction - reloadData");
        
        // Remove everything that existed before the reload, now that we're ready to insert replacements
        NSArray *indexPaths = ASIndexPathsForMultidimensionalArray(_editingNodes[ASDataControllerRowNodeKind]);
        [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
        
        NSMutableArray *editingNodes = _editingNodes[ASDataControllerRowNodeKind];
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, editingNodes.count)];
        [self _deleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
        
        [self willReloadData];
        
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
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
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
      [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
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

  if (_batchUpdateCounter == 0) {
    LOG(@"endUpdatesWithCompletion - beginning");

    [_editingTransactionQueue addOperationWithBlock:^{
      ASPerformBlockOnMainThread(^{
        // Deep copy _completedNodes to _externalCompletedNodes.
        // Any external queries from now on will be done on _externalCompletedNodes, to guarantee data consistency with the delegate.
        _externalCompletedNodes = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(_completedNodes[ASDataControllerRowNodeKind]);

        LOG(@"endUpdatesWithCompletion - begin updates call to delegate");
        [_delegate dataControllerBeginUpdates:self];
      });
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
      ASPerformBlockOnMainThread(^{
        // Now that the transaction is done, _completedNodes can be accessed externally again.
        _externalCompletedNodes = nil;
        
        LOG(@"endUpdatesWithCompletion - calling delegate end");
        [_delegate dataController:self endUpdatesAnimated:animated completion:completion];
      });
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
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:sections mutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];
      
      // Measure nodes whose views are loaded before we leave the main thread
      [self layoutLoadedNodes:updatedNodes ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths];

      [self prepareForInsertSections:sections];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self willInsertSections:sections];

        LOG(@"Edit Transaction - insertSections: %@", sections);
        NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
        for (NSUInteger i = 0; i < sections.count; i++) {
          [sectionArray addObject:[NSMutableArray array]];
        }
        
        [self _insertSections:sectionArray atIndexSet:sections withAnimationOptions:animationOptions];
        [self _batchLayoutNodes:updatedNodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
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
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes[ASDataControllerRowNodeKind], sections);
      
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
      [self _deleteSectionsAtIndexSet:sections withAnimationOptions:animationOptions];
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
      NSMutableArray *updatedNodes = [NSMutableArray array];
      NSMutableArray *updatedIndexPaths = [NSMutableArray array];
      [self _populateFromDataSourceWithSectionIndexSet:sections mutableNodes:updatedNodes mutableIndexPaths:updatedIndexPaths];

      // Dispatch to sizing queue in order to guarantee that any in-progress sizing operations from prior edits have completed.
      // For example, if an initial -reloadData call is quickly followed by -reloadSections, sizing the initial set may not be done
      // at this time.  Thus _editingNodes could be empty and crash in ASIndexPathsForMultidimensional[...]
      
      // Measure nodes whose views are loaded before we leave the main thread
      [self layoutLoadedNodes:updatedNodes ofKind:ASDataControllerRowNodeKind atIndexPaths:updatedIndexPaths];

      [self prepareForReloadSections:sections];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        [self willReloadSections:sections];

        NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes[ASDataControllerRowNodeKind], sections);
        
        LOG(@"Edit Transaction - reloadSections: updatedIndexPaths: %@, indexPaths: %@, _editingNodes: %@", updatedIndexPaths, indexPaths, ASIndexPathsForMultidimensionalArray(_editingNodes[ASDataControllerRowNodeKind]));
        
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
    LOG(@"Edit Command - moveSection");

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      [self willMoveSection:section toSection:newSection];

      // remove elements
      
      LOG(@"Edit Transaction - moveSection");
      
      NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet(_editingNodes[ASDataControllerRowNodeKind], [NSIndexSet indexSetWithIndex:section]);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes[ASDataControllerRowNodeKind], indexPaths);
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

      // update the section of indexpaths
      NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:newSection];
      NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      for (NSIndexPath *indexPath in indexPaths) {
        [updatedIndexPaths addObject:[sectionIndexPath indexPathByAddingIndex:[indexPath indexAtPosition:indexPath.length - 1]]];
      }

      // Don't re-calculate size for moving
      [self _insertNodes:nodes atIndexPaths:updatedIndexPaths withAnimationOptions:animationOptions];
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
        [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:sortedIndexPaths[i]]];
      }
      
      // Measure nodes whose views are loaded before we leave the main thread
      [self layoutLoadedNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths];
      
      [_editingTransactionQueue addOperationWithBlock:^{
        LOG(@"Edit Transaction - insertRows: %@", indexPaths);
        [self _batchLayoutNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
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
      [self _deleteNodesAtIndexPaths:sortedIndexPaths withAnimationOptions:animationOptions];
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
      NSMutableArray *nodes = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
      
      // FIXME: This doesn't currently do anything
      // FIXME: Shouldn't deletes be sorted in descending order?
      [indexPaths sortedArrayUsingSelector:@selector(compare:)];
      
      for (NSIndexPath *indexPath in indexPaths) {
        [nodes addObject:[_dataSource dataController:self nodeAtIndexPath:indexPath]];
      }
      
      // Measure nodes whose views are loaded before we leave the main thread
      [self layoutLoadedNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths];

      [_editingTransactionQueue addOperationWithBlock:^{
        LOG(@"Edit Transaction - reloadRows: %@", indexPaths);
        [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
        [self _batchLayoutNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
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
      ASPerformBlockOnMainThread(^{
        for (NSString *kind in [_completedNodes keyEnumerator]) {
          [self _relayoutNodesOfKind:kind];
        }
      });
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

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - moveRow: %@ > %@", indexPath, newIndexPath);
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      LOG(@"Edit Transaction - moveRow: %@ > %@", indexPath, newIndexPath);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes[ASDataControllerRowNodeKind], [NSArray arrayWithObject:indexPath]);
      NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

      // Don't re-calculate size for moving
      NSArray *newIndexPaths = [NSArray arrayWithObject:newIndexPath];
      [self _insertNodes:nodes atIndexPaths:newIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

#pragma mark - Data Querying (Subclass API)

- (NSArray *)indexPathsForEditingNodesOfKind:(NSString *)kind
{
  return _editingNodes[kind] != nil ? ASIndexPathsForMultidimensionalArray(_editingNodes[kind]) : nil;
}

- (NSMutableArray *)editingNodesOfKind:(NSString *)kind
{
  return _editingNodes[kind] != nil ? _editingNodes[kind] : [NSMutableArray array];
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
  return [[self completedNodes][section] count];
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  return [self completedNodes][indexPath.section][indexPath.row];
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

/// Returns nodes that can be queried externally. _externalCompletedNodes is used if available, _completedNodes otherwise.
- (NSArray *)completedNodes
{
  ASDisplayNodeAssertMainThread();
  return _externalCompletedNodes != nil ? _externalCompletedNodes : _completedNodes[ASDataControllerRowNodeKind];
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

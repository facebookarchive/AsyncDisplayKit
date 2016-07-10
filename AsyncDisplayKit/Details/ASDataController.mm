//
//  ASDataController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDataController.h"

#import "ASAssert.h"
#import "ASCellNode.h"
#import "ASEnvironmentInternal.h"
#import "ASLayout.h"
#import "ASMainSerialQueue.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASThread.h"
#import "ASIndexedNodeContext.h"
#import "ASDataController+Subclasses.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;

NSString * const ASDataControllerRowNodeKind = @"_ASDataControllerRowNodeKind";

@interface ASDataController () {
  NSMutableArray *_externalCompletedNodes;    // Main thread only.  External data access can immediately query this if available.
  NSMutableDictionary *_completedNodes;       // Main thread only.  External data access can immediately query this if _externalCompletedNodes is unavailable.
  NSMutableDictionary *_editingNodes;         // Modified on _editingTransactionQueue only.  Updates propagated to _completedNodes.
  
  ASMainSerialQueue *_mainSerialQueue;
  
  NSMutableArray *_pendingEditCommandBlocks;  // To be run on the main thread.  Handles begin/endUpdates tracking.
  NSOperationQueue *_editingTransactionQueue; // Serial background queue.  Dispatches concurrent layout and manages _editingNodes.
  
  BOOL _initialReloadDataHasBeenCalled;

  BOOL _delegateDidInsertNodes;
  BOOL _delegateDidDeleteNodes;
  BOOL _delegateDidInsertSections;
  BOOL _delegateDidDeleteSections;
}

@property (atomic, assign) NSUInteger batchUpdateCounter;

@end

@implementation ASDataController

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  ASDisplayNodeAssert(![self isMemberOfClass:[ASDataController class]], @"ASDataController is an abstract class and should not be instantiated. Instantiate a subclass instead.");
  
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

- (void)batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts ofKind:(NSString *)kind completion:(ASDataControllerCompletionBlock)completionBlock
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  NSUInteger blockSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;
  NSUInteger count = contexts.count;
  
  // Processing in batches
  for (NSUInteger i = 0; i < count; i += blockSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(count - i, blockSize));
    NSArray<ASIndexedNodeContext *> *batchedContexts = [contexts subarrayWithRange:batchedRange];
    [self _layoutNodesFromContexts:batchedContexts ofKind:kind completion:completionBlock];
  }
}

- (void)layoutLoadedNodes:(NSArray<ASCellNode *> *)nodes fromContexts:(NSArray<ASIndexedNodeContext *> *)contexts ofKind:(NSString *)kind
{
  NSAssert(ASDisplayNodeThreadIsMain(), @"Layout of loaded nodes must happen on the main thread.");
  ASDisplayNodeAssertTrue(nodes.count == contexts.count);
  
  [self _layoutNodes:nodes fromContexts:contexts atIndexesOfRange:NSMakeRange(0, nodes.count) ofKind:kind];
}

/**
 * Measure and layout the given node with the constrained size range.
 */
- (void)_layoutNode:(ASCellNode *)node withConstrainedSize:(ASSizeRange)constrainedSize
{
  CGRect frame = CGRectZero;
  frame.size = [node measureWithSizeRange:constrainedSize].size;
  node.frame = frame;
}

/**
 * Measures and defines the layout for each node in optimized batches on an editing queue, inserting the results into the backing store.
 */
- (void)_batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  [self batchLayoutNodesFromContexts:contexts ofKind:ASDataControllerRowNodeKind completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
    // Insert finished nodes into data storage
    [self _insertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

/**
 * Perform measurement and layout of loaded or unloaded nodes based if they will be layed out on main thread or not
 */
- (void)_layoutNodes:(NSArray<ASCellNode *> *)nodes fromContexts:(NSArray<ASIndexedNodeContext *> *)contexts atIndexesOfRange:(NSRange)range ofKind:(NSString *)kind
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] != _editingTransactionQueue, @"%@ should not be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  if (_dataSource == nil) {
    return;
  }
  
  // For any given layout pass that occurs, this method will be called at least twice, once on the main thread and
  // the background, to result in complete coverage of both loaded and unloaded nodes
  BOOL isMainThread = ASDisplayNodeThreadIsMain();
  for (NSUInteger k = range.location; k < NSMaxRange(range); k++) {
    ASCellNode *node = nodes[k];
    // Only nodes that are loaded should be layout on the main thread
    if (node.isNodeLoaded == isMainThread) {
      ASIndexedNodeContext *context = contexts[k];
      [self _layoutNode:node withConstrainedSize:context.constrainedSize];
    }
  }
}

- (void)_layoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts ofKind:(NSString *)kind completion:(ASDataControllerCompletionBlock)completionBlock
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  if (!contexts.count || _dataSource == nil) {
    return;
  }

  NSUInteger nodeCount = contexts.count;
  NSMutableArray<ASCellNode *> *allocatedNodes = [NSMutableArray<ASCellNode *> arrayWithCapacity:nodeCount];
  dispatch_group_t layoutGroup = dispatch_group_create();

  for (NSUInteger j = 0; j < nodeCount; j += kASDataControllerSizingCountPerProcessor) {
    NSInteger batchCount = MIN(kASDataControllerSizingCountPerProcessor, nodeCount - j);
    
    // Allocate nodes concurrently.
    __block NSArray *subarrayOfContexts;
    __block NSArray *subarrayOfNodes;
    dispatch_block_t allocationBlock = ^{
      __strong ASIndexedNodeContext **allocatedContextBuffer = (__strong ASIndexedNodeContext **)calloc(batchCount, sizeof(ASIndexedNodeContext *));
      __strong ASCellNode **allocatedNodeBuffer = (__strong ASCellNode **)calloc(batchCount, sizeof(ASCellNode *));
      dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
      dispatch_apply(batchCount, queue, ^(size_t i) {
        unsigned long k = j + i;
        ASIndexedNodeContext *context = contexts[k];
        ASCellNode *node = [context allocateNode];
        if (node == nil) {
          ASDisplayNodeAssertNotNil(node, @"Node block created nil node; %@, %@", self, self.dataSource);
          node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
        }
        allocatedNodeBuffer[i] = node;
        allocatedContextBuffer[i] = context;
      });
      subarrayOfNodes = [NSArray arrayWithObjects:allocatedNodeBuffer count:batchCount];
      subarrayOfContexts = [NSArray arrayWithObjects:allocatedContextBuffer count:batchCount];
      // Nil out buffer indexes to allow arc to free the stored cells.
      for (int i = 0; i < batchCount; i++) {
        allocatedContextBuffer[i] = nil;
        allocatedNodeBuffer[i] = nil;
      }
      free(allocatedContextBuffer);
      free(allocatedNodeBuffer);
    };
    
    // Run the allocation block to concurrently create the cell nodes.  Then, handle layout for nodes that are already loaded
    // (e.g. the dataSource may have provided cells that have been used before), which must do layout on the main thread.
    NSRange batchRange = NSMakeRange(0, batchCount);
    if (ASDisplayNodeThreadIsMain()) {
      dispatch_semaphore_t sema = dispatch_semaphore_create(0);
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        allocationBlock();
        dispatch_semaphore_signal(sema);
      });
      dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
      
      [self _layoutNodes:subarrayOfNodes fromContexts:subarrayOfContexts atIndexesOfRange:batchRange ofKind:kind];
    } else {
      allocationBlock();
      [_mainSerialQueue performBlockOnMainThread:^{
        [self _layoutNodes:subarrayOfNodes fromContexts:subarrayOfContexts atIndexesOfRange:batchRange ofKind:kind];
      }];
    }

    [allocatedNodes addObjectsFromArray:subarrayOfNodes];

    dispatch_group_async(layoutGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      // We should already have measured loaded nodes before we left the main thread. Layout the remaining ones on a background thread.
      NSRange asyncBatchRange = NSMakeRange(j, batchCount);
      [self _layoutNodes:allocatedNodes fromContexts:contexts atIndexesOfRange:asyncBatchRange ofKind:kind];
    });
  }

  // Block the _editingTransactionQueue from executing a new edit transaction until layout is done & _editingNodes array is updated.
  dispatch_group_wait(layoutGroup, DISPATCH_TIME_FOREVER);
  
  if (completionBlock) {
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:nodeCount];
    for (ASIndexedNodeContext *context in contexts) {
      [indexPaths addObject:context.indexPath];
    }

    completionBlock(allocatedNodes, indexPaths);
  }
}

- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return [_dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath];
}

#pragma mark - External Data Querying + Editing

- (void)insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock
{
  if (!indexPaths.count || _dataSource == nil) {
    return;
  }

  NSMutableArray *editingNodes = _editingNodes[kind];
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths, nodes);
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSMutableArray *completedNodes = ASTwoDimensionalArrayDeepMutableCopy(editingNodes);
  
  [_mainSerialQueue performBlockOnMainThread:^{
    _completedNodes[kind] = completedNodes;
    if (completionBlock) {
      completionBlock(nodes, indexPaths);
    }
  }];
}

- (void)deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths completion:(ASDataControllerCompletionBlock)completionBlock
{
  if (!indexPaths.count || _dataSource == nil) {
    return;
  }

  LOG(@"_deleteNodesAtIndexPaths:%@ ofKind:%@, full index paths in _editingNodes = %@", indexPaths, kind, ASIndexPathsForTwoDimensionalArray(_editingNodes[kind]));
  NSMutableArray *editingNodes = _editingNodes[kind];
  ASDeleteElementsInMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths);
  _editingNodes[kind] = editingNodes;

  [_mainSerialQueue performBlockOnMainThread:^{
    NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_completedNodes[kind], indexPaths);
    ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_completedNodes[kind], indexPaths);
    if (completionBlock) {
      completionBlock(nodes, indexPaths);
    }
  }];
}

- (void)insertSections:(NSMutableArray *)sections ofKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSArray *sections, NSIndexSet *indexSet))completionBlock
{
  if (!indexSet.count|| _dataSource == nil) {
    return;
  }

  if (_editingNodes[kind] == nil) {
    _editingNodes[kind] = [NSMutableArray array];
  }
  
  [_editingNodes[kind] insertObjects:sections atIndexes:indexSet];
  
  // Deep copy is critical here, or future edits to the sub-arrays will pollute state between _editing and _complete on different threads.
  NSArray *sectionsForCompleted = ASTwoDimensionalArrayDeepMutableCopy(sections);
  
  [_mainSerialQueue performBlockOnMainThread:^{
    [_completedNodes[kind] insertObjects:sectionsForCompleted atIndexes:indexSet];
    if (completionBlock) {
      completionBlock(sections, indexSet);
    }
  }];
}

- (void)deleteSectionsOfKind:(NSString *)kind atIndexSet:(NSIndexSet *)indexSet completion:(void (^)(NSIndexSet *indexSet))completionBlock
{
  if (!indexSet.count || _dataSource == nil) {
    return;
  }
  
  [_editingNodes[kind] removeObjectsAtIndexes:indexSet];
  [_mainSerialQueue performBlockOnMainThread:^{
    [_completedNodes[kind] removeObjectsAtIndexes:indexSet];
    if (completionBlock) {
      completionBlock(indexSet);
    }
  }];
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
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  [self insertNodes:nodes ofKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    ASDisplayNodeAssertMainThread();
    
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
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  [self deleteNodesOfKind:ASDataControllerRowNodeKind atIndexPaths:indexPaths completion:^(NSArray *nodes, NSArray *indexPaths) {
    ASDisplayNodeAssertMainThread();
    
    if (_delegateDidDeleteNodes)
      [_delegate dataController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }];
}

/**
 * Inserts sections, represented as arrays, into the backing store at the given indices and notifies the delegate.
 *
 * @discussion The section arrays are inserted into the editing store, then a deep copy of the sections are inserted
 * in the completed store on the main thread. The delegate is invoked on the main thread.
 */
- (void)_insertSections:(NSMutableArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  [self insertSections:sections ofKind:ASDataControllerRowNodeKind atIndexSet:indexSet completion:^(NSArray *sections, NSIndexSet *indexSet) {
    ASDisplayNodeAssertMainThread();
    
    if (_delegateDidInsertSections)
      [_delegate dataController:self didInsertSections:sections atIndexSet:indexSet withAnimationOptions:animationOptions];
  }];
}

/**
 * Removes sections at the given indices from the backing store and notifies the delegate.
 *
 * @discussion Section array are first removed from the editing store, then the associated section in the completed
 * store is removed on the main thread. The delegate is invoked on the main thread.
 */
- (void)_deleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert([NSOperationQueue currentQueue] == _editingTransactionQueue, @"%@ must be called on the editing transaction queue", NSStringFromSelector(_cmd));
  
  [self deleteSectionsOfKind:ASDataControllerRowNodeKind atIndexSet:indexSet completion:^(NSIndexSet *indexSet) {
    ASDisplayNodeAssertMainThread();
    
    if (_delegateDidDeleteSections)
      [_delegate dataController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
  }];
}

#pragma mark - Initial Load & Full Reload (External API)

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
  _initialReloadDataHasBeenCalled = YES;
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];

    NSUInteger sectionCount = [_dataSource numberOfSectionsInDataController:self];
    NSIndexSet *sectionIndexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
    NSArray<ASIndexedNodeContext *> *contexts = [self _populateFromDataSourceWithSectionIndexSet:sectionIndexSet];

    // Allow subclasses to perform setup before going into the edit transaction
    [self prepareForReloadData];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      LOG(@"Edit Transaction - reloadData");
      
      // Remove everything that existed before the reload, now that we're ready to insert replacements
      NSMutableArray *editingNodes = _editingNodes[ASDataControllerRowNodeKind];
      NSUInteger editingNodesSectionCount = editingNodes.count;
      
      if (editingNodesSectionCount) {
        NSIndexSet *indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, editingNodesSectionCount)];
        [self _deleteNodesAtIndexPaths:ASIndexPathsForTwoDimensionalArray(editingNodes) withAnimationOptions:animationOptions];
        [self _deleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
      }
      
      [self willReloadData];
      
      // Insert empty sections
      NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
      for (int i = 0; i < sectionCount; i++) {
        [sections addObject:[[NSMutableArray alloc] init]];
      }
      [self _insertSections:sections atIndexSet:sectionIndexSet withAnimationOptions:animationOptions];

      [self _batchLayoutNodesFromContexts:contexts withAnimationOptions:animationOptions];

      if (completion) {
        dispatch_async(dispatch_get_main_queue(), completion);
      }
    }];
    if (synchronously) {
      [self waitUntilAllUpdatesAreCommitted];
    }
  }];
}

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_batchUpdateCounter == 0, @"Should not be called between beginUpdate or endUpdate");
  
  // This should never be called in a batch update, return immediately therefore
  if (_batchUpdateCounter > 0) { return; }
  
  [_editingTransactionQueue waitUntilAllOperationsAreFinished];
  
  // Schedule block in main serial queue to wait until all operations are finished that are
  // where scheduled while waiting for the _editingTransactionQueue to finish
  [_mainSerialQueue performBlockOnMainThread:^{
    ASDisplayNodeAssert(_editingTransactionQueue.operationCount == 0, @"No operation should be in the _editingTransactionQueue anymore");
  }];
}

#pragma mark - Data Source Access (Calling _dataSource)

/**
 * Fetches row contexts for the provided sections from the data source.
 */
- (NSArray<ASIndexedNodeContext *> *)_populateFromDataSourceWithSectionIndexSet:(NSIndexSet *)indexSet
{
  ASDisplayNodeAssertMainThread();
  
  id<ASEnvironment> environment = [self.environmentDelegate dataControllerEnvironment];
  ASEnvironmentTraitCollection environmentTraitCollection = environment.environmentTraitCollection;
  
  NSMutableArray<ASIndexedNodeContext *> *contexts = [NSMutableArray array];
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger sectionIndex, BOOL *stop) {
    NSUInteger rowNum = [_dataSource dataController:self rowsInSection:sectionIndex];
    for (NSUInteger i = 0; i < rowNum; i++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:sectionIndex];
      ASCellNodeBlock nodeBlock = [_dataSource dataController:self nodeBlockAtIndexPath:indexPath];
      
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:ASDataControllerRowNodeKind atIndexPath:indexPath];
      [contexts addObject:[[ASIndexedNodeContext alloc] initWithNodeBlock:nodeBlock
                                                                indexPath:indexPath
                                                          constrainedSize:constrainedSize
                                               environmentTraitCollection:environmentTraitCollection]];
    }
  }];
  return contexts;
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
      [_mainSerialQueue performBlockOnMainThread:^{
        // Deep copy _completedNodes to _externalCompletedNodes.
        // Any external queries from now on will be done on _externalCompletedNodes, to guarantee data consistency with the delegate.
        _externalCompletedNodes = ASTwoDimensionalArrayDeepMutableCopy(_completedNodes[ASDataControllerRowNodeKind]);

        LOG(@"endUpdatesWithCompletion - begin updates call to delegate");
        [_delegate dataControllerBeginUpdates:self];
      }];
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
        // Now that the transaction is done, _completedNodes can be accessed externally again.
        _externalCompletedNodes = nil;
        
        LOG(@"endUpdatesWithCompletion - calling delegate end");
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
  if (!_initialReloadDataHasBeenCalled) {
    return;
  }
  
  // If we have never performed a reload, there is no value in executing edit operations as the initial
  // reload will directly re-query the latest state of the datasource - so completely skip the block in this case.
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
    
    NSArray<ASIndexedNodeContext *> *contexts = [self _populateFromDataSourceWithSectionIndexSet:sections];

    [self prepareForInsertSections:sections];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      [self willInsertSections:sections];

      LOG(@"Edit Transaction - insertSections: %@", sections);
      NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
      for (NSUInteger i = 0; i < sections.count; i++) {
        [sectionArray addObject:[NSMutableArray array]];
      }

      [self _insertSections:sectionArray atIndexSet:sections withAnimationOptions:animationOptions];
      
      [self _batchLayoutNodesFromContexts:contexts withAnimationOptions:animationOptions];
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
  ASDisplayNodeAssert(NO, @"ASDataController does not support %@. Call this on ASChangeSetDataController the reload will be broken into delete & insert.", NSStringFromSelector(_cmd));
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

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)prepareForInsertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willInsertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)prepareForDeleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  // Optional template hook for subclasses (See ASDataController+Subclasses.h)
}

- (void)willDeleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
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

    // Sort indexPath to avoid messing up the index when inserting in several batches
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<ASIndexedNodeContext *> *contexts = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];

    id<ASEnvironment> environment = [self.environmentDelegate dataControllerEnvironment];
    ASEnvironmentTraitCollection environmentTraitCollection = environment.environmentTraitCollection;
    
    for (NSIndexPath *indexPath in sortedIndexPaths) {
      ASCellNodeBlock nodeBlock = [_dataSource dataController:self nodeBlockAtIndexPath:indexPath];
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:ASDataControllerRowNodeKind atIndexPath:indexPath];
      [contexts addObject:[[ASIndexedNodeContext alloc] initWithNodeBlock:nodeBlock
                                                                indexPath:indexPath
                                                          constrainedSize:constrainedSize
                                               environmentTraitCollection:environmentTraitCollection]];
    }

    [self prepareForInsertRowsAtIndexPaths:indexPaths];

    [_editingTransactionQueue addOperationWithBlock:^{
      [self willInsertRowsAtIndexPaths:indexPaths];

      LOG(@"Edit Transaction - insertRows: %@", indexPaths);
      [self _batchLayoutNodesFromContexts:contexts withAnimationOptions:animationOptions];
    }];
  }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - deleteRows: %@", indexPaths);

    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    // Sort indexPath in order to avoid messing up the index when deleting in several batches.
    // FIXME: Shouldn't deletes be sorted in descending order?
    NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(compare:)];

    [self prepareForDeleteRowsAtIndexPaths:sortedIndexPaths];

    [_editingTransactionQueue addOperationWithBlock:^{
      [self willDeleteRowsAtIndexPaths:sortedIndexPaths];

      LOG(@"Edit Transaction - deleteRows: %@", indexPaths);
      [self _deleteNodesAtIndexPaths:sortedIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(NO, @"ASDataController does not support %@. Call this on ASChangeSetDataController and the reload will be broken into delete & insert.", NSStringFromSelector(_cmd));
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
        for (NSString *kind in _completedNodes) {
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
  
  NSUInteger sectionIndex = 0;
  for (NSMutableArray *section in nodes) {
    NSUInteger rowIndex = 0;
    for (ASCellNode *node in section) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
      CGRect frame = CGRectZero;
      frame.size = [node measureWithSizeRange:constrainedSize].size;
      node.frame = frame;
      rowIndex += 1;
    }
    sectionIndex += 1;
  }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    LOG(@"Edit Command - moveRow: %@ > %@", indexPath, newIndexPath);
    [_editingTransactionQueue waitUntilAllOperationsAreFinished];
    
    [_editingTransactionQueue addOperationWithBlock:^{
      LOG(@"Edit Transaction - moveRow: %@ > %@", indexPath, newIndexPath);
      NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths(_editingNodes[ASDataControllerRowNodeKind], @[indexPath]);
      NSArray *indexPaths = @[indexPath];
      [self _deleteNodesAtIndexPaths:indexPaths withAnimationOptions:animationOptions];

      // Don't re-calculate size for moving
      NSArray *newIndexPaths = @[newIndexPath];
      [self _insertNodes:nodes atIndexPaths:newIndexPaths withAnimationOptions:animationOptions];
    }];
  }];
}

#pragma mark - Data Querying (Subclass API)

- (NSArray *)indexPathsForEditingNodesOfKind:(NSString *)kind
{
  return _editingNodes[kind] != nil ? ASIndexPathsForTwoDimensionalArray(_editingNodes[kind]) : nil;
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
  
  NSInteger section = 0;
  // Loop through each section to look for the cellNode
  for (NSArray *sectionNodes in [self completedNodes]) {
    NSUInteger item = [sectionNodes indexOfObjectIdenticalTo:cellNode];
    if (item != NSNotFound) {
      return [NSIndexPath indexPathForItem:item inSection:section];
    }
    section += 1;
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
  return _externalCompletedNodes ? : _completedNodes[ASDataControllerRowNodeKind];
}

#pragma mark - Dealloc

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  [_completedNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *sections, BOOL *stop) {
    for (NSArray *section in sections) {
      for (ASCellNode *node in section) {
        if (node.isNodeLoaded) {
          if (node.layerBacked) {
            [node.layer removeFromSuperlayer];
          } else {
            [node.view removeFromSuperview];
          }
        }
      }
    }
  }];
}

@end

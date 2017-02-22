//
//  ASDataController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDataController.h>

#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASMainSerialQueue.h>
#import <AsyncDisplayKit/ASMultidimensionalArrayUtils.h>
#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASIndexedNodeContext.h>
#import <AsyncDisplayKit/ASDispatch.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

#define AS_MEASURE_AVOIDED_DATACONTROLLER_WORK 0

#define RETURN_IF_NO_DATASOURCE(val) if (_dataSource == nil) { return val; }
#define ASSERT_ON_EDITING_QUEUE ASDisplayNodeAssertNotNil(dispatch_get_specific(&kASDataControllerEditingQueueKey), @"%@ must be called on the editing transaction queue.", NSStringFromSelector(_cmd))

#define ASNodeContextTwoDimensionalMutableArray  NSMutableArray<NSMutableArray<ASIndexedNodeContext *> *>
#define ASNodeContextTwoDimensionalArray         NSArray<NSArray<ASIndexedNodeContext *> *>

// Dictionary with each entry is a pair of "kind" key and two dimensional array of node contexts
#define ASNodeContextTwoDimensionalDictionary         NSDictionary<NSString *, ASNodeContextTwoDimensionalArray *>
// Mutable dictionary with each entry is a pair of "kind" key and two dimensional array of node contexts
#define ASNodeContextTwoDimensionalMutableDictionary  NSMutableDictionary<NSString *, ASNodeContextTwoDimensionalMutableArray *>

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;
const static char * kASDataControllerEditingQueueKey = "kASDataControllerEditingQueueKey";
const static char * kASDataControllerEditingQueueContext = "kASDataControllerEditingQueueContext";

NSString * const ASDataControllerRowNodeKind = @"_ASDataControllerRowNodeKind";
NSString * const ASCollectionInvalidUpdateException = @"ASCollectionInvalidUpdateException";

typedef void (^ASDataControllerCompletionBlock)(NSArray<ASIndexedNodeContext *> *contexts, NSArray<ASCellNode *> *nodes);

#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
@interface ASDataController (AvoidedWorkMeasuring)
+ (void)_didLayoutNode;
+ (void)_expectToInsertNodes:(NSUInteger)count;
@end
#endif

@interface ASDataController () {
  ASNodeContextTwoDimensionalMutableDictionary *_nodeContexts;       // Main thread only. These are in the dataSource's index space.
  ASNodeContextTwoDimensionalDictionary *_completedNodeContexts;        // Main thread only. These are in the UIKit's index space.
  
  NSInteger _nextSectionID;
  NSMutableArray<ASSection *> *_sections;
  
  BOOL _itemCountsFromDataSourceAreValid;     // Main thread only.
  std::vector<NSInteger> _itemCountsFromDataSource;         // Main thread only.
  
  ASMainSerialQueue *_mainSerialQueue;

  dispatch_queue_t _editingTransactionQueue;  // Serial background queue.  Dispatches concurrent layout and manages _editingNodes.
  dispatch_group_t _editingTransactionGroup;     // Group of all edit transaction blocks. Useful for waiting.
  
  BOOL _initialReloadDataHasBeenCalled;

  struct {
    unsigned int supplementaryNodeKindsInSections:1;
    unsigned int supplementaryNodesOfKindInSection:1;
    unsigned int supplementaryNodeBlockOfKindAtIndexPath:1;
    unsigned int constrainedSizeForSupplementaryNodeOfKindAtIndexPath:1;
    unsigned int contextForSection:1;
  } _dataSourceFlags;
}

@end

@implementation ASDataController

#pragma mark - Lifecycle

- (instancetype)initWithDataSource:(id<ASDataControllerSource>)dataSource eventLog:(ASEventLog *)eventLog
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _dataSource = dataSource;
  
  _dataSourceFlags.supplementaryNodeKindsInSections = [_dataSource respondsToSelector:@selector(dataController:supplementaryNodeKindsInSections:)];
  _dataSourceFlags.supplementaryNodesOfKindInSection = [_dataSource respondsToSelector:@selector(dataController:supplementaryNodesOfKind:inSection:)];
  _dataSourceFlags.supplementaryNodeBlockOfKindAtIndexPath = [_dataSource respondsToSelector:@selector(dataController:supplementaryNodeBlockOfKind:atIndexPath:)];
  _dataSourceFlags.constrainedSizeForSupplementaryNodeOfKindAtIndexPath = [_dataSource respondsToSelector:@selector(dataController:constrainedSizeForSupplementaryNodeOfKind:atIndexPath:)];
  _dataSourceFlags.contextForSection = [_dataSource respondsToSelector:@selector(dataController:contextForSection:)];
  
#if ASEVENTLOG_ENABLE
  _eventLog = eventLog;
#endif
  
  _nodeContexts = [NSMutableDictionary dictionary];
  
  _nextSectionID = 0;
  _sections = [NSMutableArray array];
  
  _mainSerialQueue = [[ASMainSerialQueue alloc] init];
  
  const char *queueName = [[NSString stringWithFormat:@"org.AsyncDisplayKit.ASDataController.editingTransactionQueue:%p", self] cStringUsingEncoding:NSASCIIStringEncoding];
  _editingTransactionQueue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
  dispatch_queue_set_specific(_editingTransactionQueue, &kASDataControllerEditingQueueKey, &kASDataControllerEditingQueueContext, NULL);
  _editingTransactionGroup = dispatch_group_create();
  
  return self;
}

- (instancetype)init
{
  ASDisplayNodeFailAssert(@"Failed to call designated initializer.");
  id<ASDataControllerSource> fakeDataSource = nil;
  ASEventLog *eventLog = nil;
  return [self initWithDataSource:fakeDataSource eventLog:eventLog];
}

+ (NSUInteger)parallelProcessorCount
{
  static NSUInteger parallelProcessorCount;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    parallelProcessorCount = [[NSProcessInfo processInfo] activeProcessorCount];
  });

  return parallelProcessorCount;
}

#pragma mark - Cell Layout

- (void)batchLayoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts batchSize:(NSInteger)batchSize batchCompletion:(ASDataControllerCompletionBlock)batchCompletionHandler
{
  ASSERT_ON_EDITING_QUEUE;
#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
    [ASDataController _expectToInsertNodes:contexts.count];
#endif
  
  if (contexts.count == 0 || _dataSource == nil) {
    batchCompletionHandler(@[], @[]);
    return;
  }

  ASProfilingSignpostStart(2, _dataSource);
  
  if (batchSize == 0) {
    batchSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;
  }
  NSUInteger count = contexts.count;
  
  // Processing in batches
  for (NSUInteger i = 0; i < count; i += batchSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(count - i, batchSize));
    NSArray<ASIndexedNodeContext *> *batchedContexts = [contexts subarrayWithRange:batchedRange];
    NSArray<ASCellNode *> *nodes = [self _layoutNodesFromContexts:batchedContexts];
    batchCompletionHandler(batchedContexts, nodes);
  }
  
  ASProfilingSignpostEnd(2, _dataSource);
}

/**
 * Measure and layout the given node with the constrained size range.
 */
- (void)_layoutNode:(ASCellNode *)node withConstrainedSize:(ASSizeRange)constrainedSize
{
  ASDisplayNodeAssert(ASSizeRangeHasSignificantArea(constrainedSize), @"Attempt to layout cell node with invalid size range %@", NSStringFromASSizeRange(constrainedSize));

  CGRect frame = CGRectZero;
  frame.size = [node layoutThatFits:constrainedSize].size;
  node.frame = frame;
}

- (NSArray<ASCellNode *> *)_layoutNodesFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts
{
  ASSERT_ON_EDITING_QUEUE;
  
  NSUInteger nodeCount = contexts.count;
  if (!nodeCount || _dataSource == nil) {
    return @[];
  }

  __strong ASCellNode **allocatedNodeBuffer = (__strong ASCellNode **)calloc(nodeCount, sizeof(ASCellNode *));

  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  ASDispatchApply(nodeCount, queue, 0, ^(size_t i) {
    RETURN_IF_NO_DATASOURCE();

    // Allocate the node.
    ASIndexedNodeContext *context = contexts[i];
    ASCellNode *node = context.node;
    if (node == nil) {
      ASDisplayNodeAssertNotNil(node, @"Node block created nil node; %@, %@", self, self.dataSource);
      node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
    }

    // Layout the node if the size range is valid.
    ASSizeRange sizeRange = context.constrainedSize;
    if (ASSizeRangeHasSignificantArea(sizeRange)) {
      [self _layoutNode:node withConstrainedSize:sizeRange];
    }

#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
    [ASDataController _didLayoutNode];
#endif
    allocatedNodeBuffer[i] = node;
  });

  BOOL canceled = _dataSource == nil;

  // Create nodes array
  NSArray *nodes = canceled ? nil : [NSArray arrayWithObjects:allocatedNodeBuffer count:nodeCount];
  
  // Nil out buffer indexes to allow arc to free the stored cells.
  for (int i = 0; i < nodeCount; i++) {
    allocatedNodeBuffer[i] = nil;
  }
  free(allocatedNodeBuffer);

  return nodes;
}

#pragma mark - Data Source Access (Calling _dataSource)

- (NSArray<NSIndexPath *> *)_allIndexPathsForNodeContextsOfKind:(NSString *)kind inSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  
  if (sections.count == 0 || _dataSource == nil) {
    return @[];
  }
  
  NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    std::vector<NSInteger> counts = [self itemCountsFromDataSource];
    [sections enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      for (NSUInteger sectionIndex = range.location; sectionIndex < NSMaxRange(range); sectionIndex++) {
        NSUInteger itemCount = counts[sectionIndex];
        for (NSUInteger i = 0; i < itemCount; i++) {
          [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:sectionIndex]];
        }
      }
    }];
  } else if (_dataSourceFlags.supplementaryNodesOfKindInSection) {
    [sections enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      for (NSUInteger sectionIndex = range.location; sectionIndex < NSMaxRange(range); sectionIndex++) {
        NSUInteger itemCount = [_dataSource dataController:self supplementaryNodesOfKind:kind inSection:sectionIndex];
        for (NSUInteger i = 0; i < itemCount; i++) {
          [indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:sectionIndex]];
        }
      }
    }];
  }
  
  return indexPaths;
}

/**
 * Agressively repopulates supplementary nodes of all kinds for sections that contains some given index paths.
 *
 * @param originalIndexPaths The index paths belongs to sections whose supplementary nodes need to be repopulated.
 * @param environment The trait environment needed to initialize contexts
 */
- (void)_repopulateSupplementaryNodesForAllSectionsContainingIndexPaths:(NSArray<NSIndexPath *> *)originalIndexPaths
                                                            environment:(id<ASTraitEnvironment>)environment
{
  ASDisplayNodeAssertMainThread();
  
  if (originalIndexPaths.count ==  0) {
    return;
  }
  
  // Get all the sections that need to be repopulated
  NSIndexSet *sectionIndexes = [NSIndexSet as_sectionsFromIndexPaths:originalIndexPaths];
  for (NSString *kind in [self supplementaryKindsInSections:sectionIndexes]) {
    // TODO: Would it make more sense to do _nodeContexts enumerateKeysAndObjectsUsingBlock: for this removal step?
    // That way we are sure we removed all the old supplementaries, even if that kind isn't present anymore.
    
    // Step 1: Remove all existing contexts of this kind in these sections
    [_nodeContexts[kind] enumerateObjectsAtIndexes:sectionIndexes options:0 usingBlock:^(NSMutableArray<ASIndexedNodeContext *> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      [obj removeAllObjects];
    }];
    // Step 2: populate new contexts for all index paths in these sections
    [self _insertNodeContextsOfKind:kind forSections:sectionIndexes environment:environment];
  }
}

/**
 * Inserts new node contexts of a certain kind for some sections
 *
 * @param kind The kind of the node contexts, e.g ASDataControllerRowNodeKind
 * @param sections The sections that should be populated by new contexts
 * @param environment The trait environment needed to initialize contexts
 */
- (void)_insertNodeContextsOfKind:(NSString *)kind
                      forSections:(NSIndexSet *)sections
                      environment:(id<ASTraitEnvironment>)environment
{
  ASDisplayNodeAssertMainThread();
  
  if (sections.count == 0 || _dataSource == nil) {
    return;
  }
  
  NSArray<NSIndexPath *> *indexPaths = [self _allIndexPathsForNodeContextsOfKind:kind inSections:sections];
  [self _insertNodeContextsOfKind:kind atIndexPaths:indexPaths environment:environment];
}

/**
 * Inserts new node contexts of a certain kind at some index paths
 *
 * @param kind The kind of the node contexts, e.g ASDataControllerRowNodeKind
 * @param indexPaths The index paths at which new contexts should be populated
 * @param environment The trait environment needed to initialize contexts
 */
- (void)_insertNodeContextsOfKind:(NSString *)kind
                     atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                      environment:(id<ASTraitEnvironment>)environment
{
  ASDisplayNodeAssertMainThread();
  
  if (indexPaths.count == 0 || _dataSource == nil) {
    return;
  }
  
  BOOL isRowKind = [kind isEqualToString:ASDataControllerRowNodeKind];
  if (!isRowKind && !_dataSourceFlags.supplementaryNodeBlockOfKindAtIndexPath) {
    // Populating supplementary contexts but data source doesn't support.
    return;
  }
  
  LOG(@"Populating node contexts of kind: %@, for index paths: %@", kind, indexPaths);
  NSMutableArray<ASIndexedNodeContext *> *contexts = [NSMutableArray arrayWithCapacity:indexPaths.count];
  for (NSIndexPath *indexPath in indexPaths) {
    ASCellNodeBlock nodeBlock;
    if (isRowKind) {
      nodeBlock = [_dataSource dataController:self nodeBlockAtIndexPath:indexPath];
    } else {
      nodeBlock = [_dataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
    }
    
    ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
    [contexts addObject:[[ASIndexedNodeContext alloc] initWithNodeBlock:nodeBlock
                                               supplementaryElementKind:isRowKind ? nil : kind
                                                        constrainedSize:constrainedSize
                                                            environment:environment]];
  }
  
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(_nodeContexts[kind], indexPaths, contexts);
}

- (void)invalidateDataSourceItemCounts
{
  ASDisplayNodeAssertMainThread();
  _itemCountsFromDataSourceAreValid = NO;
}

- (std::vector<NSInteger>)itemCountsFromDataSource
{
  ASDisplayNodeAssertMainThread();
  if (NO == _itemCountsFromDataSourceAreValid) {
    id<ASDataControllerSource> source = self.dataSource;
    NSInteger sectionCount = [source numberOfSectionsInDataController:self];
    std::vector<NSInteger> newCounts;
    newCounts.reserve(sectionCount);
    for (NSInteger i = 0; i < sectionCount; i++) {
      newCounts.push_back([source dataController:self rowsInSection:i]);
    }
    _itemCountsFromDataSource = newCounts;
    _itemCountsFromDataSourceAreValid = YES;
  }
  return _itemCountsFromDataSource;
}

- (NSArray<NSString *> *)supplementaryKindsInSections:(NSIndexSet *)sections
{
  if (_dataSourceFlags.supplementaryNodeKindsInSections) {
    return [_dataSource dataController:self supplementaryNodeKindsInSections:sections];
  }
  
  return @[];
}

- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    return [_dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath];
  }
  
  if (_dataSourceFlags.constrainedSizeForSupplementaryNodeOfKindAtIndexPath){
    return [_dataSource dataController:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
  }
  
  ASDisplayNodeAssert(NO, @"Unknown constrained size for node of kind %@ by data source %@", kind, _dataSource);
  return ASSizeRangeZero;
}

#pragma mark - Batching (External API)

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  
  dispatch_group_wait(_editingTransactionGroup, DISPATCH_TIME_FOREVER);
  
  // Schedule block in main serial queue to wait until all operations are finished that are
  // where scheduled while waiting for the _editingTransactionQueue to finish
  [_mainSerialQueue performBlockOnMainThread:^{ }];
}

- (void)updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  
  if (changeSet.includesReloadData) {
    _initialReloadDataHasBeenCalled = YES;
  }
  
  dispatch_group_wait(_editingTransactionGroup, DISPATCH_TIME_FOREVER);
  
  /**
   * If the initial reloadData has not been called, just bail because we don't have
   * our old data source counts.
   * See ASUICollectionViewTests.testThatIssuingAnUpdateBeforeInitialReloadIsUnacceptable
   * For the issue that UICollectionView has that we're choosing to workaround.
   */
  if (!_initialReloadDataHasBeenCalled) {
    [changeSet executeCompletionHandlerWithFinished:YES];
    return;
  }
  
  [self invalidateDataSourceItemCounts];
  
  ASDataControllerLogEvent(self, @"triggeredUpdate: %@", changeSet);
#if ASEVENTLOG_ENABLE
  NSString *changeSetDescription = ASObjectDescriptionMakeTiny(changeSet);
  [changeSet addCompletionHandler:^(BOOL finished) {
    ASDataControllerLogEvent(self, @"finishedUpdate: %@", changeSetDescription);
  }];
#endif
  
  // Attempt to mark the update completed. This is when update validation will occur inside the changeset.
  // If an invalid update exception is thrown, we catch it and inject our "validationErrorSource" object,
  // which is the table/collection node's data source, into the exception reason to help debugging.
  @try {
    [changeSet markCompletedWithNewItemCounts:[self itemCountsFromDataSource]];
  } @catch (NSException *e) {
    id responsibleDataSource = self.validationErrorSource;
    if (e.name == ASCollectionInvalidUpdateException && responsibleDataSource != nil) {
      [NSException raise:ASCollectionInvalidUpdateException format:@"%@: %@", [responsibleDataSource class], e.reason];
    } else {
      @throw e;
    }
  }
  
  // Step 1: update _sections and _nodeContexts.
  // After this step, those properties are up-to-date with dataSource's index space.
  [self _updateSectionContextsWithChangeSet:changeSet];
  //TODO If _nodeContexts is the same, use a fast path
  [self _updateNodeContextsWithChangeSet:changeSet];
  
  // Prepare loadingNodeContexts to be used in editing queue. Deep copy is critical here,
  // or future edits to the sub-arrays will pollute state between _nodeContexts
  // and _completedNodeContexts on different threads.
  ASNodeContextTwoDimensionalDictionary *loadingNodeContexts = [ASDataController deepImmutableCopyOfNodeContextsDictionary:_nodeContexts];
  
  dispatch_group_async(_editingTransactionGroup, _editingTransactionQueue, ^{
    // Step 2: Layout **all** new node contexts without batching in background.
    // This step doesn't change any internal state.
    NSArray<ASIndexedNodeContext *> *unloadedContexts = [ASDataController unloadedNodeContextsFromDictionary:loadingNodeContexts];
    // TODO layout in batches, esp reloads
    [self batchLayoutNodesFromContexts:unloadedContexts batchSize:unloadedContexts.count batchCompletion:^(id, id) {
      ASSERT_ON_EDITING_QUEUE;
      [_mainSerialQueue performBlockOnMainThread:^{
        [_delegate dataController:self willUpdateWithChangeSet:changeSet];
        
        // Because loadingNodeContexts is immutable, it can be safely assigned to _loadNodeContexts instead of deep copied.
        _completedNodeContexts = loadingNodeContexts;
        
        // Step 3: Now that _completedNodeContexts is ready, call delegate and then UICollectionView/UITableView to update using the original change set.
        [_delegate dataController:self didUpdateWithChangeSet:changeSet];
      }];
    }];
  });
}

/**
 * Update _sections based on the given change set.
 * After this method returns, _sections will be up-to-date with dataSource.
 */
- (void)_updateSectionContextsWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  
  if (!_dataSourceFlags.contextForSection) {
    return;
  }
  
  if (changeSet.includesReloadData) {
    [_sections removeAllObjects];
    
    NSUInteger sectionCount = [self itemCountsFromDataSource].size();
    NSIndexSet *sectionIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
    [self _insertSectionContextsForSections:sectionIndexes];
    // Return immediately because reloadData can't be used in conjuntion with other updates.
    return;
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeDelete]) {
    [_sections removeObjectsAtIndexes:change.indexSet];
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertSectionContextsForSections:change.indexSet];
  }
}

- (void)_insertSectionContextsForSections:(NSIndexSet *)sectionIndexes
{
  ASDisplayNodeAssertMainThread();
  
  if (!_dataSourceFlags.contextForSection) {
    return;
  }
  
  [sectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    id<ASSectionContext> context = [_dataSource dataController:self contextForSection:idx];
    ASSection *section = [[ASSection alloc] initWithSectionID:_nextSectionID context:context];
    [_sections insertObject:section atIndex:idx];
    _nextSectionID++;
  }];
}

/**
 * Update _nodeContexts based on the given change set.
 * After this method returns, _nodeContexts will be up-to-date with dataSource's index space.
 *
 * @param changeSet The change set to be processed
 */
- (void)_updateNodeContextsWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  
  __weak id<ASTraitEnvironment> environment = [self.environmentDelegate dataControllerEnvironment];
  
  if (changeSet.includesReloadData) {
    [_nodeContexts removeAllObjects];
    
    NSUInteger sectionCount = [self itemCountsFromDataSource].size();
    if (sectionCount > 0) {
      NSIndexSet *sectionIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
      [self _insertNodeContextsForSections:sectionIndexes environment:environment];
    }
    // Return immediately because reloadData can't be used in conjuntion with other updates.
    return;
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeDelete]) {
    // FIXME: change.indexPaths is in descending order but ASDeleteElementsInMultidimensionalArrayAtIndexPaths() expects them to be in ascending order
    NSArray *sortedIndexPaths = [change.indexPaths sortedArrayUsingSelector:@selector(compare:)];
    ASDeleteElementsInMultidimensionalArrayAtIndexPaths(_nodeContexts[ASDataControllerRowNodeKind], sortedIndexPaths);
    // Aggressively repopulate supplementary nodes (#1773 & #1629)
    [self _repopulateSupplementaryNodesForAllSectionsContainingIndexPaths:change.indexPaths
                                                              environment:environment];
  }

  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeDelete]) {
    NSIndexSet *sectionIndexes = change.indexSet;
    NSMutableArray<NSString *> *kinds = [NSMutableArray arrayWithObject:ASDataControllerRowNodeKind];
    [kinds addObjectsFromArray:[self supplementaryKindsInSections:sectionIndexes]];
    for (NSString *kind in kinds) {
      [_nodeContexts[kind] removeObjectsAtIndexes:sectionIndexes];
    }
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertNodeContextsForSections:change.indexSet environment:environment];
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertNodeContextsOfKind:ASDataControllerRowNodeKind atIndexPaths:change.indexPaths environment:environment];
    // Aggressively reload supplementary nodes (#1773 & #1629)
    [self _repopulateSupplementaryNodesForAllSectionsContainingIndexPaths:change.indexPaths
                                                              environment:environment];
  }
}

- (void)_insertNodeContextsForSections:(NSIndexSet *)originalSectionIndexes environment:(id<ASTraitEnvironment>)environment
{
  ASDisplayNodeAssertMainThread();
  
  if (originalSectionIndexes.count == 0 || _dataSource == nil) {
    return;
  }
  
  NSMutableArray<NSString *> *kinds = [NSMutableArray arrayWithObject:ASDataControllerRowNodeKind];
  [kinds addObjectsFromArray:[self supplementaryKindsInSections:originalSectionIndexes]];
  
  for (NSString *kind in kinds) {
    NSIndexSet *sectionIndexes = originalSectionIndexes;
    // Step 1: Ensure _nodeContexts has enough space for new contexts
    NSMutableArray *nodeContextsOfKind = _nodeContexts[kind];
    if (nodeContextsOfKind == nil) {
      nodeContextsOfKind = [NSMutableArray array];
      _nodeContexts[kind] = nodeContextsOfKind;
      
      // TODO If this is a new kind, agressively populate contexts for all sections including ones that are not inside the originalSectionIndexes.
      if (sectionIndexes.lastIndex > 0) {
        sectionIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionIndexes.lastIndex + 1)];
      }
    }
    NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sectionIndexes.count];
    for (NSUInteger i = 0; i < sectionIndexes.count; i++) {
      [sectionArray addObject:[NSMutableArray array]];
    }
    [nodeContextsOfKind insertObjects:sectionArray atIndexes:sectionIndexes];
    // Step 2: Populate new contexts for all sections
    [self _insertNodeContextsOfKind:kind forSections:sectionIndexes environment:environment];
  }
}

#pragma mark - Relayout

- (void)relayoutAllNodes
{
  ASDisplayNodeAssertMainThread();
  if (!_initialReloadDataHasBeenCalled) {
    return;
  }
  
  LOG(@"Edit Command - relayoutRows");
  dispatch_group_wait(_editingTransactionGroup, DISPATCH_TIME_FOREVER);
  
  // Can't relayout right away because _completedNodeContexts may not be up-to-date,
  // i.e there might be some nodes that were measured using the old constrained size but haven't been added to _completedNodeContexts
  dispatch_group_async(_editingTransactionGroup, _editingTransactionQueue, ^{
    [_mainSerialQueue performBlockOnMainThread:^{
      for (NSString *kind in _completedNodeContexts) {
        [self _relayoutNodesOfKind:kind];
      }
    }];
  });
}

- (void)_relayoutNodesOfKind:(NSString *)kind
{
  ASDisplayNodeAssertMainThread();
  NSArray *contexts = _completedNodeContexts[kind];
  if (!contexts.count) {
    return;
  }
  
  NSUInteger sectionIndex = 0;
  for (NSMutableArray *section in contexts) {
    NSUInteger rowIndex = 0;
    for (ASIndexedNodeContext *context in section) {
      RETURN_IF_NO_DATASOURCE();
      NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
      if (ASSizeRangeHasSignificantArea(constrainedSize)) {
        context.constrainedSize = constrainedSize;

        // Node may not be allocated yet (e.g node virtualization or same size optimization)
        // Call context.nodeIfAllocated here to avoid immature node allocation and layout
        ASCellNode *node = context.nodeIfAllocated;
        if (node) {
          [self _layoutNode:node withConstrainedSize:constrainedSize];
        }
      }
      rowIndex += 1;
    }
    sectionIndex += 1;
  }
}

#pragma mark - Data Querying (External API)

- (NSUInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  return [_nodeContexts[ASDataControllerRowNodeKind] count];
}

- (NSUInteger)numberOfRowsInSection:(NSUInteger)section
{
  ASDisplayNodeAssertMainThread();
  NSArray *contextSections = _nodeContexts[ASDataControllerRowNodeKind];
  return (section < contextSections.count) ? [contextSections[section] count] : 0;
}

- (NSUInteger)completedNumberOfSections
{
  ASDisplayNodeAssertMainThread();
  return [_completedNodeContexts[ASDataControllerRowNodeKind] count];
}

- (NSUInteger)completedNumberOfRowsInSection:(NSUInteger)section
{
  ASDisplayNodeAssertMainThread();
  NSArray *completedNodes = _completedNodeContexts[ASDataControllerRowNodeKind];
  return (section < completedNodes.count) ? [completedNodes[section] count] : 0;
}

- (ASCellNode *)nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  if (indexPath == nil) {
    return nil;
  }
  
  ASIndexedNodeContext *context = ASGetElementInTwoDimensionalArray(_nodeContexts[ASDataControllerRowNodeKind],
                                                                    indexPath);
  // Note: Node may not be allocated and laid out yet (e.g node virtualization or same size optimization)
  // In that case, calling context.node here will force an allocation
  return context.node;
}

- (ASCellNode *)nodeAtCompletedIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  if (indexPath == nil) {
    return nil;
  }

  ASIndexedNodeContext *context = ASGetElementInTwoDimensionalArray(_completedNodeContexts[ASDataControllerRowNodeKind],
                                                                    indexPath);
  // Note: Node may not be allocated and laid out yet (e.g node virtualization or same size optimization)
  // TODO: Force synchronous allocation and layout pass in that case?
  return context.node;
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode;
{
  ASDisplayNodeAssertMainThread();
  return [self _indexPathForNode:cellNode inContexts:_nodeContexts];
}

- (NSIndexPath *)completedIndexPathForNode:(ASCellNode *)cellNode
{
  ASDisplayNodeAssertMainThread();
  return [self _indexPathForNode:cellNode inContexts:_completedNodeContexts];
}

- (NSIndexPath *)_indexPathForNode:(ASCellNode *)cellNode inContexts:(ASNodeContextTwoDimensionalDictionary *)contexts
{
  ASDisplayNodeAssertMainThread();
  if (cellNode == nil) {
    return nil;
  }

  NSString *kind = cellNode.supplementaryElementKind ?: ASDataControllerRowNodeKind;
  ASNodeContextTwoDimensionalArray *sections = contexts[kind];

  // Check if the cached index path is still correct.
  NSIndexPath *indexPath = cellNode.cachedIndexPath;
  if (indexPath != nil) {
    ASIndexedNodeContext *context = ASGetElementInTwoDimensionalArray(sections, indexPath);
    // Use nodeIfAllocated to avoid accidental node allocation and layout
    if (context.nodeIfAllocated == cellNode) {
      return indexPath;
    } else {
      indexPath = nil;
    }
  }

  // Loop through each section to look for the node context
  NSInteger sectionIdx = 0;
  for (NSArray<ASIndexedNodeContext *> *section in sections) {
    NSUInteger item = [section indexOfObjectPassingTest:^BOOL(ASIndexedNodeContext * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      return obj.nodeIfAllocated == cellNode;
    }];
    if (item != NSNotFound) {
      indexPath = [NSIndexPath indexPathForItem:item inSection:sectionIdx];
      break;
    }
    sectionIdx += 1;
  }
  cellNode.cachedIndexPath = indexPath;
  return indexPath;
}

/// Returns nodes that can be queried externally.
- (NSArray *)completedNodes
{
  ASDisplayNodeAssertMainThread();
  ASNodeContextTwoDimensionalArray *sections = _completedNodeContexts[ASDataControllerRowNodeKind];
  NSMutableArray<NSMutableArray<ASCellNode *> *> *completedNodes = [NSMutableArray arrayWithCapacity:sections.count];
  for (NSArray<ASIndexedNodeContext *> *section in sections) {
    NSMutableArray<ASCellNode *> *nodesInSection = [NSMutableArray arrayWithCapacity:section.count];
    for (ASIndexedNodeContext *context in section) {
      // Note: Node may not be allocated and laid out yet (e.g node virtualization or same size optimization)
      // TODO: Force synchronous allocation and layout pass in that case?
      [nodesInSection addObject:context.node];
    }
    [completedNodes addObject:nodesInSection];
  }
  return completedNodes;
}

- (void)moveCompletedNodeAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  // TODO Revisit this after native move support. Need to update **both**
  // _nodeContexts and _completedNodeContexts through a proper threading tunnel.
  ASMoveElementInTwoDimensionalArray(_nodeContexts[ASDataControllerRowNodeKind], indexPath, newIndexPath);
}

#pragma mark - External supplementary store and section context querying

- (ASCellNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  if (kind == nil || indexPath == nil) {
    return nil;
  }
  
  ASIndexedNodeContext *context = ASGetElementInTwoDimensionalArray(_completedNodeContexts[kind], indexPath);
  // Note: Node may not be allocated and laid out yet (e.g node virtualization or same size optimization)
  // TODO: Force synchronous allocation and layout pass in that case?
  return context.node;
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertTrue(section >= 0 && section < _sections.count);
  return _sections[section].context;
}

#pragma mark - Node contexts dictionary

//TODO Move this to somewhere else?
+ (ASNodeContextTwoDimensionalDictionary *)deepImmutableCopyOfNodeContextsDictionary:(ASNodeContextTwoDimensionalDictionary *)originalDict
{
  ASNodeContextTwoDimensionalMutableDictionary *deepCopy = [NSMutableDictionary dictionaryWithCapacity:originalDict.count];
  [originalDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull kind, ASNodeContextTwoDimensionalArray * _Nonnull obj, BOOL * _Nonnull stop) {
    deepCopy[kind] = (ASNodeContextTwoDimensionalMutableArray *)ASTwoDimensionalArrayDeepMutableCopy(obj);
  }];
  return deepCopy;
}

+ (NSArray<ASIndexedNodeContext *> *)unloadedNodeContextsFromDictionary:(ASNodeContextTwoDimensionalDictionary *)dict
{
  NSMutableArray<ASIndexedNodeContext *> *unloadedContexts = [NSMutableArray array];
  [dict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull kind, ASNodeContextTwoDimensionalArray * _Nonnull allSections, BOOL * _Nonnull stop) {
    [allSections enumerateObjectsUsingBlock:^(NSArray<ASIndexedNodeContext *> * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
      [section enumerateObjectsUsingBlock:^(ASIndexedNodeContext * _Nonnull context, NSUInteger idx, BOOL * _Nonnull stop) {
        ASCellNode *node = context.nodeIfAllocated;
        if (node == nil || node.calculatedLayout == nil) [unloadedContexts addObject:context];
      }];
    }];
  }];
  return unloadedContexts;
}

@end

#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK

static volatile int64_t _totalExpectedItems = 0;
static volatile int64_t _totalMeasuredNodes = 0;

@implementation ASDataController (WorkMeasuring)

+ (void)_didLayoutNode
{
    int64_t measured = OSAtomicIncrement64(&_totalMeasuredNodes);
    int64_t expected = _totalExpectedItems;
    if (measured % 20 == 0 || measured == expected) {
        NSLog(@"Data controller avoided work (underestimated): %lld / %lld", measured, expected);
    }
}

+ (void)_expectToInsertNodes:(NSUInteger)count
{
    OSAtomicAdd64((int64_t)count, &_totalExpectedItems);
}

@end
#endif

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
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext.h>
#import <AsyncDisplayKit/ASDispatch.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASMainSerialQueue.h>
#import <AsyncDisplayKit/ASMutableElementMap.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/ASSection.h>

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

#define AS_MEASURE_AVOIDED_DATACONTROLLER_WORK 0

#define RETURN_IF_NO_DATASOURCE(val) if (_dataSource == nil) { return val; }
#define ASSERT_ON_EDITING_QUEUE ASDisplayNodeAssertNotNil(dispatch_get_specific(&kASDataControllerEditingQueueKey), @"%@ must be called on the editing transaction queue.", NSStringFromSelector(_cmd))

const static NSUInteger kASDataControllerSizingCountPerProcessor = 5;
const static char * kASDataControllerEditingQueueKey = "kASDataControllerEditingQueueKey";
const static char * kASDataControllerEditingQueueContext = "kASDataControllerEditingQueueContext";

NSString * const ASDataControllerRowNodeKind = @"_ASDataControllerRowNodeKind";
NSString * const ASCollectionInvalidUpdateException = @"ASCollectionInvalidUpdateException";

typedef void (^ASDataControllerCompletionBlock)(NSArray<ASCollectionElement *> *elements, NSArray<ASCellNode *> *nodes);

#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
@interface ASDataController (AvoidedWorkMeasuring)
+ (void)_didLayoutNode;
+ (void)_expectToInsertNodes:(NSUInteger)count;
@end
#endif

@interface ASDataController () {
  id<ASDataControllerLayoutDelegate> _layoutDelegate;

  NSInteger _nextSectionID;
  
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
    unsigned int constrainedSizeForNodeAtIndexPath:1;
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
  _dataSourceFlags.constrainedSizeForNodeAtIndexPath = [_dataSource respondsToSelector:@selector(dataController:constrainedSizeForNodeAtIndexPath:)];
  _dataSourceFlags.constrainedSizeForSupplementaryNodeOfKindAtIndexPath = [_dataSource respondsToSelector:@selector(dataController:constrainedSizeForSupplementaryNodeOfKind:atIndexPath:)];
  _dataSourceFlags.contextForSection = [_dataSource respondsToSelector:@selector(dataController:contextForSection:)];
  
#if ASEVENTLOG_ENABLE
  _eventLog = eventLog;
#endif

  _visibleMap = _pendingMap = [[ASElementMap alloc] init];
  
  _nextSectionID = 0;
  
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

- (id<ASDataControllerLayoutDelegate>)layoutDelegate
{
  ASDisplayNodeAssertMainThread();
  return _layoutDelegate;
}

- (void)setLayoutDelegate:(id<ASDataControllerLayoutDelegate>)layoutDelegate
{
  ASDisplayNodeAssertMainThread();
  if (layoutDelegate != _layoutDelegate) {
    _layoutDelegate = layoutDelegate;
  }
}

#pragma mark - Cell Layout

- (void)batchAllocateNodesFromElements:(NSArray<ASCollectionElement *> *)elements andLayout:(BOOL)shouldLayout batchSize:(NSInteger)batchSize batchCompletion:(ASDataControllerCompletionBlock)batchCompletionHandler
{
  ASSERT_ON_EDITING_QUEUE;
#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
    [ASDataController _expectToInsertNodes:elements.count];
#endif
  
  if (elements.count == 0 || _dataSource == nil) {
    batchCompletionHandler(@[], @[]);
    return;
  }

  ASProfilingSignpostStart(2, _dataSource);
  
  if (batchSize == 0) {
    batchSize = [[ASDataController class] parallelProcessorCount] * kASDataControllerSizingCountPerProcessor;
  }
  NSUInteger count = elements.count;
  
  // Processing in batches
  for (NSUInteger i = 0; i < count; i += batchSize) {
    NSRange batchedRange = NSMakeRange(i, MIN(count - i, batchSize));
    NSArray<ASCollectionElement *> *batchedElements = [elements subarrayWithRange:batchedRange];
    NSArray<ASCellNode *> *nodes = [self _allocateNodesFromElements:batchedElements andLayout:shouldLayout];
    batchCompletionHandler(batchedElements, nodes);
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

// TODO Is returned array still needed? Can it be removed?
- (NSArray<ASCellNode *> *)_allocateNodesFromElements:(NSArray<ASCollectionElement *> *)elements andLayout:(BOOL)shouldLayout
{
  ASSERT_ON_EDITING_QUEUE;
  
  NSUInteger nodeCount = elements.count;
  if (!nodeCount || _dataSource == nil) {
    return @[];
  }

  __strong ASCellNode **allocatedNodeBuffer = (__strong ASCellNode **)calloc(nodeCount, sizeof(ASCellNode *));

  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  ASDispatchApply(nodeCount, queue, 0, ^(size_t i) {
    RETURN_IF_NO_DATASOURCE();

    // Allocate the node.
    ASCollectionElement *context = elements[i];
    ASCellNode *node = context.node;
    if (node == nil) {
      ASDisplayNodeAssertNotNil(node, @"Node block created nil node; %@, %@", self, self.dataSource);
      node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
    }
    
    if (shouldLayout) {
      // Layout the node if the size range is valid.
      ASSizeRange sizeRange = context.constrainedSize;
      if (ASSizeRangeHasSignificantArea(sizeRange)) {
        [self _layoutNode:node withConstrainedSize:sizeRange];
      }

#if AS_MEASURE_AVOIDED_DATACONTROLLER_WORK
      [ASDataController _didLayoutNode];
#endif
    }

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

- (NSArray<NSIndexPath *> *)_allIndexPathsForItemsOfKind:(NSString *)kind inSections:(NSIndexSet *)sections
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
 * @param map The element map into which to apply the change.
 * @param indexPaths The index paths belongs to sections whose supplementary nodes need to be repopulated.
 * @param changeSet The changeset that triggered this repopulation.
 * @param owningNode The node that owns the new elements.
 * @param traitCollection The trait collection needed to initialize elements
 * @param indexPathsAreNew YES if index paths are "after the update," NO otherwise.
 * @param shouldFetchSizeRanges Whether constrained sizes should be fetched from data source
 */
- (void)_repopulateSupplementaryNodesIntoMap:(ASMutableElementMap *)map
             forSectionsContainingIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                                   changeSet:(_ASHierarchyChangeSet *)changeSet
                                  owningNode:(ASDisplayNode *)owningNode
                             traitCollection:(ASPrimitiveTraitCollection)traitCollection
                            indexPathsAreNew:(BOOL)indexPathsAreNew
                       shouldFetchSizeRanges:(BOOL)shouldFetchSizeRanges
{
  ASDisplayNodeAssertMainThread();

  if (indexPaths.count ==  0) {
    return;
  }

  // Remove all old supplementaries from these sections
  NSIndexSet *oldSections = [NSIndexSet as_sectionsFromIndexPaths:indexPaths];
  [map removeSupplementaryElementsInSections:oldSections];

  // Add in new ones with the new kinds.
  NSIndexSet *newSections;
  if (indexPathsAreNew) {
    newSections = oldSections;
  } else {
    newSections = [oldSections as_indexesByMapping:^NSUInteger(NSUInteger oldSection) {
      return [changeSet newSectionForOldSection:oldSection];
    }];
  }

  for (NSString *kind in [self supplementaryKindsInSections:newSections]) {
    [self _insertElementsIntoMap:map kind:kind forSections:newSections owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
  }
}

/**
 * Inserts new elements of a certain kind for some sections
 *
 * @param kind The kind of the elements, e.g ASDataControllerRowNodeKind
 * @param sections The sections that should be populated by new elements
 * @param owningNode The node that owns the new elements.
 * @param traitCollection The trait collection needed to initialize elements
 * @param shouldFetchSizeRanges Whether constrained sizes should be fetched from data source
 */
- (void)_insertElementsIntoMap:(ASMutableElementMap *)map
                          kind:(NSString *)kind
                   forSections:(NSIndexSet *)sections
                    owningNode:(ASDisplayNode *)owningNode
               traitCollection:(ASPrimitiveTraitCollection)traitCollection
         shouldFetchSizeRanges:(BOOL)shouldFetchSizeRanges
{
  ASDisplayNodeAssertMainThread();
  
  if (sections.count == 0 || _dataSource == nil) {
    return;
  }
  
  NSArray<NSIndexPath *> *indexPaths = [self _allIndexPathsForItemsOfKind:kind inSections:sections];
  [self _insertElementsIntoMap:map kind:kind atIndexPaths:indexPaths owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
}

/**
 * Inserts new elements of a certain kind at some index paths
 *
 * @param map The map to insert the elements into.
 * @param kind The kind of the elements, e.g ASDataControllerRowNodeKind
 * @param indexPaths The index paths at which new elements should be populated
 * @param owningNode The node that owns the new elements.
 * @param traitCollection The trait collection needed to initialize elements
 * @param shouldFetchSizeRanges Whether constrained sizes should be fetched from data source
 */
- (void)_insertElementsIntoMap:(ASMutableElementMap *)map
                          kind:(NSString *)kind
                  atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                    owningNode:(ASDisplayNode *)owningNode
               traitCollection:(ASPrimitiveTraitCollection)traitCollection
         shouldFetchSizeRanges:(BOOL)shouldFetchSizeRanges
{
  ASDisplayNodeAssertMainThread();
  
  if (indexPaths.count == 0 || _dataSource == nil) {
    return;
  }
  
  BOOL isRowKind = [kind isEqualToString:ASDataControllerRowNodeKind];
  if (!isRowKind && !_dataSourceFlags.supplementaryNodeBlockOfKindAtIndexPath) {
    // Populating supplementary elements but data source doesn't support.
    return;
  }
  
  LOG(@"Populating elements of kind: %@, for index paths: %@", kind, indexPaths);
  for (NSIndexPath *indexPath in indexPaths) {
    ASCellNodeBlock nodeBlock;
    if (isRowKind) {
      nodeBlock = [_dataSource dataController:self nodeBlockAtIndexPath:indexPath];
    } else {
      nodeBlock = [_dataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
    }
    
    ASSizeRange constrainedSize;
    if (shouldFetchSizeRanges) {
      constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
    }
    
    ASCollectionElement *element = [[ASCollectionElement alloc] initWithNodeBlock:nodeBlock
                                                         supplementaryElementKind:isRowKind ? nil : kind
                                                                  constrainedSize:constrainedSize
                                                                       owningNode:owningNode
                                                                  traitCollection:traitCollection];
    [map insertElement:element atIndexPath:indexPath];
  }
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

- (ASSizeRange)constrainedSizeForElement:(ASCollectionElement *)element inElementMap:(ASElementMap *)map
{
  ASDisplayNodeAssertMainThread();
  NSString *kind = element.supplementaryElementKind ?: ASDataControllerRowNodeKind;
  NSIndexPath *indexPath = [map indexPathForElement:element];
  return [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
}


- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  
  id<ASDataControllerSource> dataSource = _dataSource;
  if (dataSource == nil) {
    return ASSizeRangeZero;
  }
  
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    ASDisplayNodeAssert(_dataSourceFlags.constrainedSizeForNodeAtIndexPath, @"-dataController:constrainedSizeForNodeAtIndexPath: must also be implemented");
    return [dataSource dataController:self constrainedSizeForNodeAtIndexPath:indexPath];
  }
  
  if (_dataSourceFlags.constrainedSizeForSupplementaryNodeOfKindAtIndexPath){
    return [dataSource dataController:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
  }
  
  ASDisplayNodeAssert(NO, @"Unknown constrained size for node of kind %@ by data source %@", kind, dataSource);
  return ASSizeRangeZero;
}

#pragma mark - Batching (External API)

- (void)waitUntilAllUpdatesAreCommitted
{
  // Schedule block in main serial queue to wait until all operations are finished that are
  // where scheduled while waiting for the _editingTransactionQueue to finish
  [self _scheduleBlockOnMainSerialQueue:^{ }];
}

- (void)updateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  
  if (changeSet.includesReloadData) {
    _initialReloadDataHasBeenCalled = YES;
  }
  
  dispatch_group_wait(_editingTransactionGroup, DISPATCH_TIME_FOREVER);
  
  // If the initial reloadData has not been called, just bail because we don't have our old data source counts.
  // See ASUICollectionViewTests.testThatIssuingAnUpdateBeforeInitialReloadIsUnacceptable
  // for the issue that UICollectionView has that we're choosing to workaround.
  if (!_initialReloadDataHasBeenCalled) {
    [changeSet executeCompletionHandlerWithFinished:YES];
    return;
  }
  
  [self invalidateDataSourceItemCounts];
  
  // Log events
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
  
  // Since we waited for _editingTransactionGroup at the beginning of this method, at this point we can guarantee that _pendingMap equals to _visibleMap.
  // So if the change set is empty, we don't need to modify data and can safely schedule to notify the delegate.
  if (changeSet.isEmpty) {
    [_mainSerialQueue performBlockOnMainThread:^{
      [_delegate dataController:self willUpdateWithChangeSet:changeSet];
      [_delegate dataController:self didUpdateWithChangeSet:changeSet];
    }];
    return;
  }

  // Mutable copy of current data.
  ASMutableElementMap *mutableMap = [_pendingMap mutableCopy];
  
  BOOL canDelegateLayout = (_layoutDelegate != nil);

  // Step 1: Update the mutable copies to match the data source's state
  [self _updateSectionContextsInMap:mutableMap changeSet:changeSet];
  __weak id<ASTraitEnvironment> environment = [self.environmentDelegate dataControllerEnvironment];
  __weak ASDisplayNode *owningNode = (ASDisplayNode *)environment; // This is gross!
  ASPrimitiveTraitCollection existingTraitCollection = [environment primitiveTraitCollection];
  [self _updateElementsInMap:mutableMap changeSet:changeSet owningNode:owningNode traitCollection:existingTraitCollection shouldFetchSizeRanges:(! canDelegateLayout)];
  
  // Step 2: Clone the new data
  ASElementMap *newMap = [mutableMap copy];
  _pendingMap = newMap;
  
  // Step 3: Ask layout delegate for contexts
  id layoutContext = nil;
  if (canDelegateLayout) {
    layoutContext = [_layoutDelegate layoutContextWithElements:newMap];
  }
  
  dispatch_group_async(_editingTransactionGroup, _editingTransactionQueue, ^{
    // Step 4: Allocate and layout elements if can't delegate
    NSArray<ASCollectionElement *> *elementsToProcess;
    if (canDelegateLayout) {
      // Allocate all nodes before handling them to the layout delegate.
      // In the future, we may want to let the delegate drive allocation as well.
      elementsToProcess = ASArrayByFlatMapping(newMap,
                                               ASCollectionElement *element,
                                               (element.nodeIfAllocated == nil ? element : nil));
    } else {
      elementsToProcess = ASArrayByFlatMapping(newMap,
                                               ASCollectionElement *element,
                                               (element.nodeIfAllocated.calculatedLayout == nil ? element : nil));
    }
    
    [self batchAllocateNodesFromElements:elementsToProcess andLayout:(! canDelegateLayout) batchSize:elementsToProcess.count batchCompletion:^(NSArray<ASCollectionElement *> *elements, NSArray<ASCellNode *> *nodes) {
      ASSERT_ON_EDITING_QUEUE;

      if (canDelegateLayout) {
        [_layoutDelegate prepareLayoutWithContext:layoutContext];
      }
      
      [_mainSerialQueue performBlockOnMainThread:^{
        [_delegate dataController:self willUpdateWithChangeSet:changeSet];

        // Step 5: Deploy the new data as "completed" and inform delegate
        _visibleMap = newMap;
        
        [_delegate dataController:self didUpdateWithChangeSet:changeSet];
      }];
    }];
  });
}

/**
 * Update sections based on the given change set.
 */
- (void)_updateSectionContextsInMap:(ASMutableElementMap *)map changeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  
  if (!_dataSourceFlags.contextForSection) {
    return;
  }
  
  if (changeSet.includesReloadData) {
    [map removeAllSectionContexts];
    
    NSUInteger sectionCount = [self itemCountsFromDataSource].size();
    NSIndexSet *sectionIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
    [self _insertSectionContextsIntoMap:map indexes:sectionIndexes];
    // Return immediately because reloadData can't be used in conjuntion with other updates.
    return;
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeDelete]) {
    [map removeSectionContextsAtIndexes:change.indexSet];
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertSectionContextsIntoMap:map indexes:change.indexSet];
  }
}

- (void)_insertSectionContextsIntoMap:(ASMutableElementMap *)map indexes:(NSIndexSet *)sectionIndexes
{
  ASDisplayNodeAssertMainThread();
  
  if (!_dataSourceFlags.contextForSection) {
    return;
  }
  
  [sectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    id<ASSectionContext> context = [_dataSource dataController:self contextForSection:idx];
    ASSection *section = [[ASSection alloc] initWithSectionID:_nextSectionID context:context];
    [map insertSection:section atIndex:idx];
    _nextSectionID++;
  }];
}

/**
 * Update elements based on the given change set.
 */
- (void)_updateElementsInMap:(ASMutableElementMap *)map
                   changeSet:(_ASHierarchyChangeSet *)changeSet
                  owningNode:(ASDisplayNode *)owningNode
             traitCollection:(ASPrimitiveTraitCollection)traitCollection
       shouldFetchSizeRanges:(BOOL)shouldFetchSizeRanges
{
  ASDisplayNodeAssertMainThread();

  if (changeSet.includesReloadData) {
    [map removeAllElements];
    
    NSUInteger sectionCount = [self itemCountsFromDataSource].size();
    if (sectionCount > 0) {
      NSIndexSet *sectionIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)];
      [self _insertElementsIntoMap:map sections:sectionIndexes owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
    }
    // Return immediately because reloadData can't be used in conjuntion with other updates.
    return;
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeDelete]) {
    [map removeItemsAtIndexPaths:change.indexPaths];
    // Aggressively repopulate supplementary nodes (#1773 & #1629)
    [self _repopulateSupplementaryNodesIntoMap:map forSectionsContainingIndexPaths:change.indexPaths
                                     changeSet:changeSet
                                    owningNode:owningNode
                               traitCollection:traitCollection
                              indexPathsAreNew:NO
                         shouldFetchSizeRanges:shouldFetchSizeRanges];
  }

  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeDelete]) {
    NSIndexSet *sectionIndexes = change.indexSet;
    [map removeSupplementaryElementsInSections:sectionIndexes];
    [map removeSectionsOfItems:sectionIndexes];
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertElementsIntoMap:map sections:change.indexSet owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeInsert]) {
    [self _insertElementsIntoMap:map kind:ASDataControllerRowNodeKind atIndexPaths:change.indexPaths owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
    // Aggressively reload supplementary nodes (#1773 & #1629)
    [self _repopulateSupplementaryNodesIntoMap:map forSectionsContainingIndexPaths:change.indexPaths
                                     changeSet:changeSet
                                    owningNode:owningNode
                               traitCollection:traitCollection
                              indexPathsAreNew:YES
                         shouldFetchSizeRanges:shouldFetchSizeRanges];
  }
}

- (void)_insertElementsIntoMap:(ASMutableElementMap *)map
                      sections:(NSIndexSet *)sectionIndexes
                    owningNode:(ASDisplayNode *)owningNode
               traitCollection:(ASPrimitiveTraitCollection)traitCollection
         shouldFetchSizeRanges:(BOOL)shouldFetchSizeRanges
{
  ASDisplayNodeAssertMainThread();
  
  if (sectionIndexes.count == 0 || _dataSource == nil) {
    return;
  }

  // Items
  [map insertEmptySectionsOfItemsAtIndexes:sectionIndexes];
  [self _insertElementsIntoMap:map kind:ASDataControllerRowNodeKind forSections:sectionIndexes owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];

  // Supplementaries
  for (NSString *kind in [self supplementaryKindsInSections:sectionIndexes]) {
    // Step 2: Populate new elements for all sections
    [self _insertElementsIntoMap:map kind:kind forSections:sectionIndexes owningNode:owningNode traitCollection:traitCollection shouldFetchSizeRanges:shouldFetchSizeRanges];
  }
}

#pragma mark - Relayout

- (void)relayoutNodes:(id<NSFastEnumeration>)nodes nodesSizeChanged:(NSMutableArray *)nodesSizesChanged
{
  NSParameterAssert(nodesSizesChanged);
  
  ASDisplayNodeAssertMainThread();
  if (!_initialReloadDataHasBeenCalled) {
    return;
  }
  
  for (ASCellNode *node in nodes) {
    ASSizeRange constrainedSize = [self constrainedSizeForElement:node.collectionElement inElementMap:_pendingMap];
    [self _layoutNode:node withConstrainedSize:constrainedSize];
    BOOL matchesSize = [_dataSource dataController:self presentedSizeForElement:node.collectionElement matchesSize:node.frame.size];
    if (! matchesSize) {
      [nodesSizesChanged addObject:node];
    }
  }
}

- (void)relayoutAllNodes
{
  ASDisplayNodeAssertMainThread();
  if (!_initialReloadDataHasBeenCalled) {
    return;
  }
  
  // Can't relayout right away because _visibleMap may not be up-to-date,
  // i.e there might be some nodes that were measured using the old constrained size but haven't been added to _visibleMap
  LOG(@"Edit Command - relayoutRows");
  [self _scheduleBlockOnMainSerialQueue:^{
    [self _relayoutAllNodes];
  }];
}

- (void)_relayoutAllNodes
{
  ASDisplayNodeAssertMainThread();
  for (ASCollectionElement *element in _visibleMap) {
    ASSizeRange constrainedSize = [self constrainedSizeForElement:element inElementMap:_visibleMap];
    if (ASSizeRangeHasSignificantArea(constrainedSize)) {
      element.constrainedSize = constrainedSize;

      // Node may not be allocated yet (e.g node virtualization or same size optimization)
      // Call context.nodeIfAllocated here to avoid immature node allocation and layout
      ASCellNode *node = element.nodeIfAllocated;
      if (node) {
        [self _layoutNode:node withConstrainedSize:constrainedSize];
      }
    }
  }
}

# pragma mark - ASPrimitiveTraitCollection

- (void)environmentDidChange
{
  ASPerformBlockOnMainThread(^{
    if (!_initialReloadDataHasBeenCalled) {
      return;
    }

    // Can't update the trait collection right away because _visibleMap may not be up-to-date,
    // i.e there might be some elements that were allocated using the old trait collection but haven't been added to _visibleMap
    [self _scheduleBlockOnMainSerialQueue:^{
      ASPrimitiveTraitCollection newTraitCollection = [[_environmentDelegate dataControllerEnvironment] primitiveTraitCollection];
      for (ASCollectionElement *element in _visibleMap) {
        element.traitCollection = newTraitCollection;
      }
    }];
  });
}

# pragma mark - Helper methods

- (void)_scheduleBlockOnMainSerialQueue:(dispatch_block_t)block
{
  ASDisplayNodeAssertMainThread();
  dispatch_group_wait(_editingTransactionGroup, DISPATCH_TIME_FOREVER);
  [_mainSerialQueue performBlockOnMainThread:block];
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

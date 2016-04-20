/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionDataController.h"

#import "ASAssert.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASCellNode.h"
#import "ASDisplayNodeInternal.h"
#import "ASDataController+Subclasses.h"
#import "ASIndexedNodeContext.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

@interface ASCollectionDataController () {
  BOOL _dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath;
}

- (id<ASCollectionDataControllerSource>)collectionDataSource;

@end

@implementation ASCollectionDataController {
  NSMutableDictionary<NSString *, NSMutableArray<ASIndexedNodeContext *> *> *_pendingContexts;
}

- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  self = [super initWithAsyncDataFetching:asyncDataFetchingEnabled];
  if (self != nil) {
    _pendingContexts = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)prepareForReloadData
{
  for (NSString *kind in [self supplementaryKinds]) {
    LOG(@"Populating elements of kind: %@", kind);
    NSMutableArray<ASIndexedNodeContext *> *contexts = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withMutableContexts:contexts];
    _pendingContexts[kind] = contexts;
  }
}

- (void)willReloadData
{
  [_pendingContexts enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray<ASIndexedNodeContext *> *contexts, BOOL *stop) {
    // Remove everything that existed before the reload, now that we're ready to insert replacements
    NSArray *indexPaths = [self indexPathsForEditingNodesOfKind:kind];
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    
    NSArray *editingNodes = [self editingNodesOfKind:kind];
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, editingNodes.count)];
    [self deleteSectionsOfKind:kind atIndexSet:indexSet completion:nil];
    
    // Insert each section
    NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryNodeOfKind:kind];
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    for (int i = 0; i < sectionCount; i++) {
      [sections addObject:[NSMutableArray array]];
    }
    [self insertSections:sections ofKind:kind atIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)] completion:nil];
    
    [self batchLayoutNodesFromContexts:contexts ofKind:kind completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
    }];
    [_pendingContexts removeObjectForKey:kind];
  }];
}

- (void)prepareForInsertSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    LOG(@"Populating elements of kind: %@, for sections: %@", kind, sections);
    NSMutableArray<ASIndexedNodeContext *> *contexts = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableContexts:contexts];
    _pendingContexts[kind] = contexts;
  }
}

- (void)willInsertSections:(NSIndexSet *)sections
{
  [_pendingContexts enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray<ASIndexedNodeContext *> *contexts, BOOL *stop) {
    NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
    for (NSUInteger i = 0; i < sections.count; i++) {
      [sectionArray addObject:[NSMutableArray array]];
    }
    
    [self insertSections:sectionArray ofKind:kind atIndexSet:sections completion:nil];
    [self batchLayoutNodesFromContexts:contexts ofKind:kind completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
    }];
    [_pendingContexts removeObjectForKey:kind];
  }];
}

- (void)willDeleteSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet([self editingNodesOfKind:kind], sections);
    
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    [self deleteSectionsOfKind:kind atIndexSet:sections completion:nil];
  }
}

- (void)prepareForReloadSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    NSMutableArray<ASIndexedNodeContext *> *contexts = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableContexts:contexts];
    _pendingContexts[kind] = contexts;
  }
}

- (void)willReloadSections:(NSIndexSet *)sections
{
  [_pendingContexts enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray<ASIndexedNodeContext *> *contexts, BOOL *stop) {
    NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet([self editingNodesOfKind:kind], sections);
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    // reinsert the elements
    [self batchLayoutNodesFromContexts:contexts ofKind:kind completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
    }];
    [_pendingContexts removeObjectForKey:kind];
  }];
}

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  for (NSString *kind in [self supplementaryKinds]) {
    NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet([self editingNodesOfKind:kind], [NSIndexSet indexSetWithIndex:section]);
    NSArray *nodes = ASFindElementsInMultidimensionalArrayAtIndexPaths([self editingNodesOfKind:kind], indexPaths);
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    
    // update the section of indexpaths
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:newSection];
    NSMutableArray *updatedIndexPaths = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
      [updatedIndexPaths addObject:[sectionIndexPath indexPathByAddingIndex:[indexPath indexAtPosition:indexPath.length - 1]]];
    }];
    [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
  }
}

- (void)_populateSupplementaryNodesOfKind:(NSString *)kind withMutableContexts:(NSMutableArray<ASIndexedNodeContext *> *)contexts
{
  NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryNodeOfKind:kind];
  for (NSUInteger i = 0; i < sectionCount; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    NSUInteger rowCount = [self.collectionDataSource dataController:self supplementaryNodesOfKind:kind inSection:i];
    for (NSUInteger j = 0; j < rowCount; j++) {
      NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];

      ASCellNodeBlock supplementaryCellBlock;
      if (_dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath) {
        supplementaryCellBlock = [self.collectionDataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
      } else {
        ASCellNode *supplementaryNode = [self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath];
        supplementaryCellBlock = ^{ return supplementaryNode; };
      }
      
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
      ASIndexedNodeContext *context = [[ASIndexedNodeContext alloc] initWithNodeBlock:supplementaryCellBlock
                                                                            indexPath:indexPath
                                                                      constrainedSize:constrainedSize];
      [contexts addObject:context];
    }
  }
}

- (void)_populateSupplementaryNodesOfKind:(NSString *)kind withSections:(NSIndexSet *)sections mutableContexts:(NSMutableArray<ASIndexedNodeContext *> *)contexts
{
  [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = [self.collectionDataSource dataController:self supplementaryNodesOfKind:kind inSection:idx];
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = 0; i < rowNum; i++) {
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];

      ASCellNodeBlock supplementaryCellBlock;
      if (_dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath) {
        supplementaryCellBlock = [self.collectionDataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
      } else {
        ASCellNode *supplementaryNode = [self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath];
        supplementaryCellBlock = ^{ return supplementaryNode; };
      }
      
      ASSizeRange constrainedSize = [self constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
      ASIndexedNodeContext *context = [[ASIndexedNodeContext alloc] initWithNodeBlock:supplementaryCellBlock
                                                                            indexPath:indexPath
                                                                        constrainedSize:constrainedSize];
      [contexts addObject:context];
    }
  }];
}

#pragma mark - Sizing query

- (ASSizeRange)constrainedSizeForNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  if ([kind isEqualToString:ASDataControllerRowNodeKind]) {
    return [super constrainedSizeForNodeOfKind:kind atIndexPath:indexPath];
  } else {
    return [self.collectionDataSource dataController:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
  }
}

#pragma mark - External supplementary store querying

- (ASCellNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  NSArray *nodesOfKind = [self completedNodesOfKind:kind];
  NSInteger section = indexPath.section;
  if (section < nodesOfKind.count) {
    NSArray *nodesOfKindInSection = nodesOfKind[section];
    NSInteger itemIndex = indexPath.item;
    if (itemIndex < nodesOfKindInSection.count) {
      return nodesOfKindInSection[itemIndex];
    }
  }
  ASDisplayNodeAssert(NO, @"Supplementary node should exist.  Kind = %@, indexPath = %@, collectionDataSource = %@", kind, indexPath, self.collectionDataSource);
  return [[ASCellNode alloc] init];
}

#pragma mark - Private Helpers

- (NSArray *)supplementaryKinds
{
  return [self.collectionDataSource supplementaryNodeKindsInDataController:self];
}

- (id<ASCollectionDataControllerSource>)collectionDataSource
{
  return (id<ASCollectionDataControllerSource>)self.dataSource;
}

- (void)setDataSource:(id<ASDataControllerSource>)dataSource
{
  [super setDataSource:dataSource];
  _dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath = [self.collectionDataSource respondsToSelector:@selector(dataController:supplementaryNodeBlockOfKind:atIndexPath:)];

  ASDisplayNodeAssertTrue(_dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath || [self.collectionDataSource respondsToSelector:@selector(dataController:supplementaryNodeOfKind:atIndexPath:)]);
}

@end
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

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

@interface ASCollectionDataController () {
  BOOL _dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath;
}

- (id<ASCollectionDataControllerSource>)collectionDataSource;

@end

@implementation ASCollectionDataController {
  NSMutableDictionary<NSString *, NSMutableArray<ASCellNode *> *> *_pendingNodes;
  NSMutableDictionary<NSString *, NSMutableArray<NSIndexPath *> *> *_pendingIndexPaths;
}

- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  self = [super initWithAsyncDataFetching:asyncDataFetchingEnabled];
  if (self != nil) {
    _pendingNodes = [NSMutableDictionary dictionary];
    _pendingIndexPaths = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)prepareForReloadData
{
  for (NSString *kind in [self supplementaryKinds]) {
    LOG(@"Populating elements of kind: %@", kind);
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSMutableArray *nodes = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withMutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
  }
}

- (void)willReloadData
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    // Insert sections
    NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryNodeOfKind:kind];
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    for (int i = 0; i < sectionCount; i++) {
      [sections addObject:[NSMutableArray array]];
    }
    self.editingNode[kind] = sections;

    [self layoutAndInsertFromNodeBlocks:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self commitChangesToNodesOfKind:kind withCompletion:nil];
    }];
  }];

  [_pendingNodes removeAllObjects];
  [_pendingIndexPaths removeAllObjects];
}

- (void)prepareForInsertSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    LOG(@"Populating elements of kind: %@, for sections: %@", kind, sections);
    NSMutableArray *nodes = [NSMutableArray array];
    NSMutableArray *indexPaths = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
  }
}

- (void)willInsertSections:(NSIndexSet *)sections
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
    for (NSUInteger i = 0; i < sections.count; i++) {
      [sectionArray addObject:[NSMutableArray array]];
    }

    [self insertSections:sectionArray ofKind:kind atIndexSet:sections];
    [self layoutAndInsertFromNodeBlocks:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self commitChangesToNodesOfKind:kind withCompletion:nil];
    }];
  }];

  [_pendingNodes removeAllObjects];
  [_pendingIndexPaths removeAllObjects];
}

- (void)willDeleteSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    [self deleteSectionsOfKind:kind atIndexSet:sections];
    [self commitChangesToNodesOfKind:kind withCompletion:nil];
  }
}

- (void)prepareForReloadSections:(NSIndexSet *)sections
{
  for (NSString *kind in [self supplementaryKinds]) {
    NSMutableArray *nodes = [NSMutableArray array];
    NSMutableArray *indexPaths = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
  }
}

- (void)willReloadSections:(NSIndexSet *)sections
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    // clear sections
    [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      self.editingNode[kind][idx] = [[NSMutableArray alloc] init];
    }];
    // reinsert the elements
    [self layoutAndInsertFromNodeBlocks:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:^(NSArray<ASCellNode *> *nodes, NSArray<NSIndexPath *> *indexPaths) {
      [self commitChangesToNodesOfKind:kind withCompletion:nil];
    }];
  }];

  [_pendingNodes removeAllObjects];
  [_pendingIndexPaths removeAllObjects];
}

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  for (NSString *kind in [self supplementaryKinds]) {
    [self moveSection:section ofKind:kind toSection:newSection];
    [self commitChangesToNodesOfKind:kind withCompletion:nil];
  }
}

- (void)_populateSupplementaryNodesOfKind:(NSString *)kind withMutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryNodeOfKind:kind];
  for (NSUInteger i = 0; i < sectionCount; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    NSUInteger rowCount = [self.collectionDataSource dataController:self supplementaryNodesOfKind:kind inSection:i];
    for (NSUInteger j = 0; j < rowCount; j++) {
      NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];
      [indexPaths addObject:indexPath];
      ASCellNodeBlock supplementaryCellBlock;
      if (_dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath) {
        supplementaryCellBlock = [self.collectionDataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
      } else {
        ASCellNode *supplementaryNode = [self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath];
        supplementaryCellBlock = ^{ return supplementaryNode; };
      }
      [nodes addObject:supplementaryCellBlock];
    }
  }
}

- (void)_populateSupplementaryNodesOfKind:(NSString *)kind withSections:(NSIndexSet *)sections mutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = [self.collectionDataSource dataController:self supplementaryNodesOfKind:kind inSection:idx];
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = 0; i < rowNum; i++) {
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
      [indexPaths addObject:indexPath];
      ASCellNodeBlock supplementaryCellBlock;
      if (_dataSourceImplementsSupplementaryNodeBlockOfKindAtIndexPath) {
        supplementaryCellBlock = [self.collectionDataSource dataController:self supplementaryNodeBlockOfKind:kind atIndexPath:indexPath];
      } else {
        ASCellNode *supplementaryNode = [self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath];
        supplementaryCellBlock = ^{ return supplementaryNode; };
      }
      [nodes addObject:supplementaryCellBlock];
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
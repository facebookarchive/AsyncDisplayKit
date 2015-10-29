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
#import "ASDisplayNode.h"
#import "ASDisplayNodeInternal.h"
#import "ASDataController+Subclasses.h"

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

@interface ASCollectionDataController ()

- (id<ASCollectionDataControllerSource>)collectionDataSource;

@end

@implementation ASCollectionDataController {
  NSMutableDictionary *_pendingNodes;
  NSMutableDictionary *_pendingIndexPaths;
}

- (void)prepareForReloadData
{
  _pendingNodes = [NSMutableDictionary dictionary];
  _pendingIndexPaths = [NSMutableDictionary dictionary];

  [[self supplementaryKinds] enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL *stop) {
    LOG(@"Populating elements of kind: %@", kind);
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSMutableArray *nodes = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withMutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;

    // Measure loaded nodes before leaving the main thread
    [self layoutLoadedNodes:nodes ofKind:kind atIndexPaths:indexPaths];
  }];
}

- (void)willReloadData
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
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
    
    [self batchLayoutNodes:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:^(NSArray *nodes, NSArray *indexPaths) {
      [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
    }];
    [_pendingNodes removeObjectForKey:kind];
    [_pendingIndexPaths removeObjectForKey:kind];
  }];
}

- (void)prepareForInsertSections:(NSIndexSet *)sections
{
  [[self supplementaryKinds] enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL *stop) {
    LOG(@"Populating elements of kind: %@, for sections: %@", kind, sections);
    NSMutableArray *nodes = [NSMutableArray array];
    NSMutableArray *indexPaths = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
    
    // Measure loaded nodes before leaving the main thread
    [self layoutLoadedNodes:nodes ofKind:kind atIndexPaths:indexPaths];
  }];
}

- (void)willInsertSections:(NSIndexSet *)sections
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:sections.count];
    for (NSUInteger i = 0; i < sections.count; i++) {
      [sectionArray addObject:[NSMutableArray array]];
    }
    
    [self insertSections:sectionArray ofKind:kind atIndexSet:sections completion:nil];
    [self batchLayoutNodes:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:nil];
    _pendingNodes[kind] = nil;
    _pendingIndexPaths[kind] = nil;
  }];
}

- (void)willDeleteSections:(NSIndexSet *)sections
{
  [[self supplementaryKinds] enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL *stop) {
    NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet([self editingNodesOfKind:kind], sections);
    
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    [self deleteSectionsOfKind:kind atIndexSet:sections completion:nil];
  }];
}

- (void)prepareForReloadSections:(NSIndexSet *)sections
{
  [[self supplementaryKinds] enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL *stop) {
    NSMutableArray *nodes = [NSMutableArray array];
    NSMutableArray *indexPaths = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withSections:sections mutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
    
    // Measure loaded nodes before leaving the main thread
    [self layoutLoadedNodes:nodes ofKind:kind atIndexPaths:indexPaths];
  }];
}

- (void)willReloadSections:(NSIndexSet *)sections
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    NSArray *indexPaths = ASIndexPathsForMultidimensionalArrayAtIndexSet([self editingNodesOfKind:kind], sections);
    [self deleteNodesOfKind:kind atIndexPaths:indexPaths completion:nil];
    // reinsert the elements
    [self batchLayoutNodes:nodes ofKind:kind atIndexPaths:_pendingIndexPaths[kind] completion:nil];
    _pendingNodes[kind] = nil;
    _pendingIndexPaths[kind] = nil;
  }];
}

- (void)willMoveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [[self supplementaryKinds] enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL *stop) {
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
  }];
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
      [nodes addObject:[self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath]];
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
      [nodes addObject:[self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath]];
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
  return [self completedNodesOfKind:kind][indexPath.section][indexPath.item];
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

@end

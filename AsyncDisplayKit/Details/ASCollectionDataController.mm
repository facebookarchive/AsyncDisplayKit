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

@implementation ASCollectionDataController {
  NSMutableDictionary *_completedSupplementaryNodes;
  NSMutableDictionary *_editingSupplementaryNodes;
}

- (void)initialSupplementaryLoading
{
  [self performEditCommandWithBlock:^{
    ASDisplayNodeAssertMainThread();
    [self accessDataSourceWithBlock:^{
      NSArray *elementKinds = [self.collectionDataSource supplementaryKindsInDataController:self];
      [elementKinds enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL * _Nonnull stop) {
        _completedSupplementaryNodes[kind] = [NSMutableArray array];
        _editingSupplementaryNodes[kind] = [NSMutableArray array];
        
        NSMutableArray *indexPaths = [NSMutableArray array];
        NSMutableArray *nodes = [NSMutableArray array];
        [self _populateAllNodesOfKind:kind withMutableNodes:nodes mutableIndexPaths:indexPaths];
        [self batchLayoutNodes:nodes atIndexPaths:indexPaths completion:nil];
      }];
    }];
  }];
}
       
- (void)_populateAllNodesOfKind:(NSString *)kind withMutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryKind:kind];
  for (NSUInteger i = 0; i < sectionCount; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    NSUInteger rowCount = [self.collectionDataSource dataController:self rowsInSection:i supplementaryKind:kind];
    for (NSUInteger j = 0; j < rowCount; j++) {
      NSIndexPath *indexPath = [sectionIndexPath indexPathByAddingIndex:j];
      [indexPaths addObject:indexPath];
      [nodes addObject:[self.collectionDataSource dataController:self supplementaryNodeOfKind:kind atIndexPath:indexPath]];
    }
  }
}

- (ASDisplayNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  return _completedSupplementaryNodes[kind][indexPath.section][indexPath.item];
}

- (id<ASCollectionDataControllerSource>)collectionDataSource
{
  return (id<ASCollectionDataControllerSource>)self.dataSource;
}

#pragma mark - Internal Data Querying

- (void)_insertNodes:(NSArray *)nodes ofKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths
{
  if (indexPaths.count == 0)
    return;
  NSMutableArray *editingNodes = [self _editingNodesOfKind:kind];
  ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(editingNodes, indexPaths, nodes);
  NSMutableArray *completedNodes = (NSMutableArray *)ASMultidimensionalArrayDeepMutableCopy(editingNodes);
  ASDisplayNodePerformBlockOnMainThread(^{
    _completedSupplementaryNodes[kind] = completedNodes;
    // TODO: Notify change
  });
}

- (void)_deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths
{
  if (indexPaths.count == 0)
    return;
}

- (NSMutableArray *)_completedNodesOfKind:(NSString *)kind
{
  return _completedSupplementaryNodes[kind];
}

- (NSMutableArray *)_editingNodesOfKind:(NSString *)kind
{
  return _editingSupplementaryNodes[kind];
}

@end

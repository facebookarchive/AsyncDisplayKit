/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionDataController.h"

#import "ASLog.h"
#import "ASAssert.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASDisplayNode.h"
#import "ASDisplayNodeInternal.h"
#import "ASDataController+Subclasses.h"

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

  NSArray *elementKinds = [self.collectionDataSource supplementaryNodeKindsInDataController:self];
  [elementKinds enumerateObjectsUsingBlock:^(NSString *kind, NSUInteger idx, BOOL * _Nonnull stop) {
    ASLOG(@"Populating elements of kind: %@", kind);
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSMutableArray *nodes = [NSMutableArray array];
    [self _populateSupplementaryNodesOfKind:kind withMutableNodes:nodes mutableIndexPaths:indexPaths];
    _pendingNodes[kind] = nodes;
    _pendingIndexPaths[kind] = indexPaths;
  }];
}

- (void)willReloadData
{
  [_pendingNodes enumerateKeysAndObjectsUsingBlock:^(NSString *kind, NSMutableArray *nodes, BOOL *stop) {
    ASLOG(@"Batch layout nodes of kind: %@, (%@)", kind, nodes);

    // Insert each section
    NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryKind:kind];
    NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
    for (int i = 0; i < sectionCount; i++) {
      [sections addObject:[[NSMutableArray alloc] init]];
    }
    [self insertSections:sections ofKind:kind atIndexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, sectionCount)] completion:nil];
    
    [self batchLayoutNodes:nodes atIndexPaths:_pendingIndexPaths[kind] constrainedSize:^ASSizeRange(NSIndexPath *indexPath) {
      return [self.collectionDataSource dataController:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
    } completion:^(NSArray *nodes, NSArray *indexPaths) {
      [self insertNodes:nodes ofKind:kind atIndexPaths:indexPaths completion:nil];
    }];
  }];
}

- (void)_populateSupplementaryNodesOfKind:(NSString *)kind withMutableNodes:(NSMutableArray *)nodes mutableIndexPaths:(NSMutableArray *)indexPaths
{
  NSUInteger sectionCount = [self.collectionDataSource dataController:self numberOfSectionsForSupplementaryKind:kind];
  for (NSUInteger i = 0; i < sectionCount; i++) {
    NSIndexPath *sectionIndexPath = [[NSIndexPath alloc] initWithIndex:i];
    NSUInteger rowCount = [self.collectionDataSource dataController:self supplementaryViewsOfKind:kind inSection:i];
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
  return [self internalCompletedNodes][kind][indexPath.section][indexPath.item];
}

- (id<ASCollectionDataControllerSource>)collectionDataSource
{
  return (id<ASCollectionDataControllerSource>)self.dataSource;
}

@end

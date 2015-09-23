//
//  ASCollectionDataController.m
//  Pods
//
//  Created by Levi McCallum on 9/22/15.
//
//

#import "ASCollectionDataController.h"

#import "ASAssert.h"

@interface ASDataController (Subclasses)

/**
 * Queues the given operation until an `endUpdates` synchronize update is completed.
 *
 * If this method is called outside of a begin/endUpdates batch update, the block is
 * executed immediately.
 */
- (void)performEditCommandWithBlock:(void (^)(void))block;

/**
 * Safely locks access to the data source and executes the given block, unlocking once complete.
 *
 * When `asyncDataFetching` is enabled, the block is executed on a background thread.
 */
- (void)accessDataSourceWithBlock:(dispatch_block_t)block;

@end

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
    }];
  }];
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
}

- (void)_deleteNodesOfKind:(NSString *)kind atIndexPaths:(NSArray *)indexPaths
{
  if (indexPaths.count == 0)
    return;
}

@end

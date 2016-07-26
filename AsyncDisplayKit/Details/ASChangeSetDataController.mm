//
//  ASChangeSetDataController.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 19/10/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASChangeSetDataController.h"
#import "_ASHierarchyChangeSet.h"
#import "ASAssert.h"
#import "ASDataController+Subclasses.h"

@implementation ASChangeSetDataController {
  NSInteger _changeSetBatchUpdateCounter;
  _ASHierarchyChangeSet *_changeSet;
}

#pragma mark - Batching (External API)

- (void)beginUpdates
{
  ASDisplayNodeAssertMainThread();
  if (_changeSetBatchUpdateCounter <= 0) {
    _changeSetBatchUpdateCounter = 0;
    _changeSet = [[_ASHierarchyChangeSet alloc] initWithOldData:[self itemCountsFromDataSource]];
  }
  _changeSetBatchUpdateCounter++;
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  _changeSetBatchUpdateCounter--;
  
  // Prevent calling endUpdatesAnimated:completion: in an unbalanced way
  NSAssert(_changeSetBatchUpdateCounter >= 0, @"endUpdatesAnimated:completion: called without having a balanced beginUpdates call");
  
  if (_changeSetBatchUpdateCounter == 0) {
    if (!self.initialReloadDataHasBeenCalled) {
      if (completion) {
        completion(YES);
      }
      _changeSet = nil;
      return;
    }
    
    [self invalidateDataSourceItemCounts];
    [_changeSet markCompletedWithNewItemCounts:[self itemCountsFromDataSource]];
    
    [super beginUpdates];
    
    for (_ASHierarchyItemChange *change in [_changeSet itemChangesOfType:_ASHierarchyChangeTypeDelete]) {
      [super deleteRowsAtIndexPaths:change.indexPaths withAnimationOptions:change.animationOptions];
    }
    
    for (_ASHierarchySectionChange *change in [_changeSet sectionChangesOfType:_ASHierarchyChangeTypeDelete]) {
      [super deleteSections:change.indexSet withAnimationOptions:change.animationOptions];
    }
    
    for (_ASHierarchySectionChange *change in [_changeSet sectionChangesOfType:_ASHierarchyChangeTypeInsert]) {
      [super insertSections:change.indexSet withAnimationOptions:change.animationOptions];
    }
    
    for (_ASHierarchyItemChange *change in [_changeSet itemChangesOfType:_ASHierarchyChangeTypeInsert]) {
      [super insertRowsAtIndexPaths:change.indexPaths withAnimationOptions:change.animationOptions];
    }

    [super endUpdatesAnimated:animated completion:completion];
    
    _changeSet = nil;
  }
}

- (BOOL)batchUpdating
{
  BOOL batchUpdating = (_changeSetBatchUpdateCounter != 0);
  // _changeSet must be available during batch update
  ASDisplayNodeAssertTrue(batchUpdating == (_changeSet != nil));
  return batchUpdating;
}

#pragma mark - Section Editing (External API)

- (void)insertSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet insertSections:sections animationOptions:animationOptions];
  [self endUpdates];
}

- (void)deleteSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet deleteSections:sections animationOptions:animationOptions];
  [self endUpdates];
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet reloadSections:sections animationOptions:animationOptions];
  [self endUpdates];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet deleteSections:[NSIndexSet indexSetWithIndex:section] animationOptions:animationOptions];
  [_changeSet insertSections:[NSIndexSet indexSetWithIndex:newSection] animationOptions:animationOptions];
  [self endUpdates];
}

#pragma mark - Row Editing (External API)

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet insertItems:indexPaths animationOptions:animationOptions];
  [self endUpdates];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet deleteItems:indexPaths animationOptions:animationOptions];
  [self endUpdates];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet reloadItems:indexPaths animationOptions:animationOptions];
  [self endUpdates];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet deleteItems:@[indexPath] animationOptions:animationOptions];
  [_changeSet insertItems:@[newIndexPath] animationOptions:animationOptions];
  [self endUpdates];
}

@end

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

@implementation ASChangeSetDataController {
  NSInteger _changeSetBatchUpdateCounter;
  _ASHierarchyChangeSet *_changeSet;
}

#pragma mark - Batching (External API)

- (void)beginUpdates
{
  // NOTE: This assertion is failing in some apps and will be enabled soon.
//  ASDisplayNodeAssertMainThread();
  if (_changeSetBatchUpdateCounter <= 0) {
    _changeSet = [_ASHierarchyChangeSet new];
    _changeSetBatchUpdateCounter = 0;
  }
  _changeSetBatchUpdateCounter++;
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  // NOTE: This assertion is failing in some apps and will be enabled soon.
//  ASDisplayNodeAssertMainThread();
  _changeSetBatchUpdateCounter--;
  
  // Prevent calling endUpdatesAnimated:completion: in an unbalanced way
  // NOTE: This assertion is failing in some apps and will be enabled soon.
//  NSAssert(_changeSetBatchUpdateCounter >= 0, @"endUpdatesAnimated:completion: called without having a balanced beginUpdates call");
  
  if (_changeSetBatchUpdateCounter == 0) {
    [_changeSet markCompleted];
    
    [super beginUpdates];

    NSAssert([_changeSet itemChangesOfType:_ASHierarchyChangeTypeReload].count == 0, @"Expected reload item changes to have been converted into insert/deletes.");
    NSAssert([_changeSet sectionChangesOfType:_ASHierarchyChangeTypeReload].count == 0, @"Expected reload section changes to have been converted into insert/deletes.");
    
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
  if ([self batchUpdating]) {
    [_changeSet insertSections:sections animationOptions:animationOptions];
  } else {
    [super insertSections:sections withAnimationOptions:animationOptions];
  }
}

- (void)deleteSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet deleteSections:sections animationOptions:animationOptions];
  } else {
    [super deleteSections:sections withAnimationOptions:animationOptions];
  }
}

- (void)reloadSections:(NSIndexSet *)sections withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet reloadSections:sections animationOptions:animationOptions];
  } else {
    [self beginUpdates];
    [super deleteSections:sections withAnimationOptions:animationOptions];
    [super insertSections:sections withAnimationOptions:animationOptions];
    [self endUpdates];
  }
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet deleteSections:[NSIndexSet indexSetWithIndex:section] animationOptions:animationOptions];
    [_changeSet insertSections:[NSIndexSet indexSetWithIndex:newSection] animationOptions:animationOptions];
  } else {
    [super moveSection:section toSection:newSection withAnimationOptions:animationOptions];
  }
}

#pragma mark - Row Editing (External API)

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet insertItems:indexPaths animationOptions:animationOptions];
  } else {
    [super insertRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet deleteItems:indexPaths animationOptions:animationOptions];
  } else {
    [super deleteRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
  }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet reloadItems:indexPaths animationOptions:animationOptions];
  } else {
    [self beginUpdates];
    [super deleteRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
    [super insertRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
    [self endUpdates];
  }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if ([self batchUpdating]) {
    [_changeSet deleteItems:@[indexPath] animationOptions:animationOptions];
    [_changeSet insertItems:@[newIndexPath] animationOptions:animationOptions];
  } else {
    [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOptions:animationOptions];
  }
}

@end

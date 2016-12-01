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

- (void)dealloc
{
  ASDisplayNodeCAssert(_changeSetBatchUpdateCounter == 0, @"ASChangeSetDataController deallocated in the middle of a batch update.");
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
  
  [_changeSet addCompletionHandler:completion];
  if (_changeSetBatchUpdateCounter == 0) {
    void (^batchCompletion)(BOOL) = _changeSet.completionHandler;
    
    /**
     * If the initial reloadData has not been called, just bail because we don't have
     * our old data source counts.
     * See ASUICollectionViewTests.testThatIssuingAnUpdateBeforeInitialReloadIsUnacceptable
     * For the issue that UICollectionView has that we're choosing to workaround.
     */
    if (!self.initialReloadDataHasBeenCalled) {
      if (batchCompletion != nil) {
        batchCompletion(YES);
      }
      _changeSet = nil;
      return;
    }

    [self invalidateDataSourceItemCounts];

    // Attempt to mark the update completed. This is when update validation will occur inside the changeset.
    // If an invalid update exception is thrown, we catch it and inject our "validationErrorSource" object,
    // which is the table/collection node's data source, into the exception reason to help debugging.
    @try {
      [_changeSet markCompletedWithNewItemCounts:[self itemCountsFromDataSource]];
    } @catch (NSException *e) {
      id responsibleDataSource = self.validationErrorSource;
      if (e.name == ASCollectionInvalidUpdateException && responsibleDataSource != nil) {
        [NSException raise:ASCollectionInvalidUpdateException format:@"%@: %@", [responsibleDataSource class], e.reason];
      } else {
        @throw e;
      }
    }
    
    ASDataControllerLogEvent(self, @"triggeredUpdate: %@", _changeSet);
    
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

#if ASEVENTLOG_ENABLE
    NSString *changeSetDescription = ASObjectDescriptionMakeTiny(_changeSet);
    batchCompletion = ^(BOOL finished) {
      if (batchCompletion != nil) {
        batchCompletion(finished);
      }
      ASDataControllerLogEvent(self, @"finishedUpdate: %@", changeSetDescription);
    };
#endif
    
    [super endUpdatesAnimated:animated completion:batchCompletion];
    
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

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  if (self.batchUpdating) {
    // This assertion will be enabled soon.
//    ASDisplayNodeFailAssert(@"Should not call %@ during batch update", NSStringFromSelector(_cmd));
    return;
  }

  [super waitUntilAllUpdatesAreCommitted];
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

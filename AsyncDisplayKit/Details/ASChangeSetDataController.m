//
//  ASChangeSetDataController.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 19/10/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASChangeSetDataController.h"
#import "ASInternalHelpers.h"
#import "_ASHierarchyChangeSet.h"
#import "ASAssert.h"

@interface ASChangeSetDataController ()

@property (nonatomic, assign) NSUInteger batchUpdateCounter;
@property (nonatomic, strong) _ASHierarchyChangeSet *changeSet;

@end

@implementation ASChangeSetDataController

- (instancetype)initWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  if (!(self = [super initWithAsyncDataFetching:asyncDataFetchingEnabled])) {
    return nil;
  }
  
  _batchUpdateCounter = 0;
  
  return self;
}

#pragma mark - Batching (External API)

- (void)beginUpdates
{
  ASDisplayNodeAssertMainThread();
  if (_batchUpdateCounter == 0) {
    _changeSet = [_ASHierarchyChangeSet new];
  }
  _batchUpdateCounter++;
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  _batchUpdateCounter--;
  
  if (_batchUpdateCounter == 0) {
    [_changeSet markCompleted];
    
    [super beginUpdates];
  
    for (_ASHierarchySectionChange *change in [_changeSet sectionChangesOfType:_ASHierarchyChangeTypeReload]) {
      [super reloadSections:change.indexSet withAnimationOptions:change.animationOptions];
    }
    
    for (_ASHierarchyItemChange *change in [_changeSet itemChangesOfType:_ASHierarchyChangeTypeReload]) {
      [super reloadRowsAtIndexPaths:change.indexPaths withAnimationOptions:change.animationOptions];
    }
    
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
  BOOL batchUpdating = (_batchUpdateCounter != 0);
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
    [super reloadSections:sections withAnimationOptions:animationOptions];
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
    [super reloadRowsAtIndexPaths:indexPaths withAnimationOptions:animationOptions];
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

//
//  _ASHierarchyChangeSet.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/29/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/NSIndexSet+ASHelpers.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <unordered_map>
#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

// If assertions are enabled and they haven't forced us to suppress the exception,
// then throw, otherwise log.
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  #define ASFailUpdateValidation(...)\
    _Pragma("clang diagnostic push")\
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")\
    if ([ASDisplayNode suppressesInvalidCollectionUpdateExceptions]) {\
      NSLog(__VA_ARGS__);\
    } else {\
      NSLog(__VA_ARGS__);\
      [NSException raise:ASCollectionInvalidUpdateException format:__VA_ARGS__];\
    }\
  _Pragma("clang diagnostic pop")
#else
  #define ASFailUpdateValidation(...) NSLog(__VA_ARGS__);
#endif

BOOL ASHierarchyChangeTypeIsFinal(_ASHierarchyChangeType changeType) {
    switch (changeType) {
        case _ASHierarchyChangeTypeInsert:
        case _ASHierarchyChangeTypeDelete:
            return YES;
        default:
            return NO;
    }
}

NSString *NSStringFromASHierarchyChangeType(_ASHierarchyChangeType changeType)
{
  switch (changeType) {
    case _ASHierarchyChangeTypeInsert:
      return @"Insert";
    case _ASHierarchyChangeTypeOriginalInsert:
      return @"OriginalInsert";
    case _ASHierarchyChangeTypeDelete:
      return @"Delete";
    case _ASHierarchyChangeTypeOriginalDelete:
      return @"OriginalDelete";
    case _ASHierarchyChangeTypeReload:
      return @"Reload";
    default:
      return @"(invalid)";
  }
}

@interface _ASHierarchySectionChange ()
- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexSet:(NSIndexSet *)indexSet animationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 On return `changes` is sorted according to the change type with changes coalesced by animationOptions
 Assumes: `changes` all have the same changeType
 */
+ (void)sortAndCoalesceSectionChanges:(NSMutableArray<_ASHierarchySectionChange *> *)changes;

/// Returns all the indexes from all the `indexSet`s of the given `_ASHierarchySectionChange` objects.
+ (NSMutableIndexSet *)allIndexesInSectionChanges:(NSArray *)changes;

+ (NSString *)smallDescriptionForSectionChanges:(NSArray<_ASHierarchySectionChange *> *)changes;
@end

@interface _ASHierarchyItemChange ()
- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions presorted:(BOOL)presorted;

/**
 On return `changes` is sorted according to the change type with changes coalesced by animationOptions
 Assumes: `changes` all have the same changeType
 */
+ (void)sortAndCoalesceItemChanges:(NSMutableArray<_ASHierarchyItemChange *> *)changes ignoringChangesInSections:(NSIndexSet *)sections;

+ (NSString *)smallDescriptionForItemChanges:(NSArray<_ASHierarchyItemChange *> *)changes;

+ (void)ensureItemChanges:(NSArray<_ASHierarchyItemChange *> *)changes ofSameType:(_ASHierarchyChangeType)changeType;
@end

@interface _ASHierarchyChangeSet () 

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchyItemChange *> *insertItemChanges;
@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchyItemChange *> *originalInsertItemChanges;

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchyItemChange *> *deleteItemChanges;
@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchyItemChange *> *originalDeleteItemChanges;

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchyItemChange *> *reloadItemChanges;

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchySectionChange *> *insertSectionChanges;
@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchySectionChange *> *originalInsertSectionChanges;

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchySectionChange *> *deleteSectionChanges;
@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchySectionChange *> *originalDeleteSectionChanges;

@property (nonatomic, strong, readonly) NSMutableArray<_ASHierarchySectionChange *> *reloadSectionChanges;

@end

@implementation _ASHierarchyChangeSet {
  std::vector<NSInteger> _oldItemCounts;
  std::vector<NSInteger> _newItemCounts;
  void (^_completionHandler)(BOOL finished);
}

- (instancetype)init
{
  ASFailUpdateValidation(@"_ASHierarchyChangeSet: -init is not supported. Call -initWithOldData:");
  return [self initWithOldData:std::vector<NSInteger>()];
}

- (instancetype)initWithOldData:(std::vector<NSInteger>)oldItemCounts
{
  self = [super init];
  if (self) {
    _oldItemCounts = oldItemCounts;
    
    _originalInsertItemChanges = [[NSMutableArray alloc] init];
    _insertItemChanges = [[NSMutableArray alloc] init];
    _originalDeleteItemChanges = [[NSMutableArray alloc] init];
    _deleteItemChanges = [[NSMutableArray alloc] init];
    _reloadItemChanges = [[NSMutableArray alloc] init];
    
    _originalInsertSectionChanges = [[NSMutableArray alloc] init];
    _insertSectionChanges = [[NSMutableArray alloc] init];
    _originalDeleteSectionChanges = [[NSMutableArray alloc] init];
    _deleteSectionChanges = [[NSMutableArray alloc] init];
    _reloadSectionChanges = [[NSMutableArray alloc] init];
  }
  return self;
}

#pragma mark External API

- (BOOL)isEmpty
{
  return (! _includesReloadData) && (! [self _includesPerItemOrSectionChanges]);
}

- (void)addCompletionHandler:(void (^)(BOOL))completion
{
  [self _ensureNotCompleted];
  if (completion == nil) {
    return;
  }

  void (^oldCompletionHandler)(BOOL finished) = _completionHandler;
  _completionHandler = ^(BOOL finished) {
    if (oldCompletionHandler != nil) {
    	oldCompletionHandler(finished);
    }
    completion(finished);
  };
}

- (void)executeCompletionHandlerWithFinished:(BOOL)finished
{
  if (_completionHandler != nil) {
    _completionHandler(finished);
    _completionHandler = nil;
  }
}

- (void)markCompletedWithNewItemCounts:(std::vector<NSInteger>)newItemCounts
{
  NSAssert(!_completed, @"Attempt to mark already-completed changeset as completed.");
  _completed = YES;
  _newItemCounts = newItemCounts;
  [self _sortAndCoalesceChangeArrays];
  [self _validateUpdate];
}

- (NSArray *)sectionChangesOfType:(_ASHierarchyChangeType)changeType
{
  [self _ensureCompleted];
  switch (changeType) {
    case _ASHierarchyChangeTypeInsert:
      return _insertSectionChanges;
    case _ASHierarchyChangeTypeReload:
      return _reloadSectionChanges;
    case _ASHierarchyChangeTypeDelete:
      return _deleteSectionChanges;
    case _ASHierarchyChangeTypeOriginalDelete:
      return _originalDeleteSectionChanges;
    case _ASHierarchyChangeTypeOriginalInsert:
      return _originalInsertSectionChanges;
    default:
      NSAssert(NO, @"Request for section changes with invalid type: %lu", (long)changeType);
      return nil;
  }
}

- (NSArray *)itemChangesOfType:(_ASHierarchyChangeType)changeType
{
  [self _ensureCompleted];
  switch (changeType) {
    case _ASHierarchyChangeTypeInsert:
      return _insertItemChanges;
    case _ASHierarchyChangeTypeReload:
      return _reloadItemChanges;
    case _ASHierarchyChangeTypeDelete:
      return _deleteItemChanges;
    case _ASHierarchyChangeTypeOriginalInsert:
      return _originalInsertItemChanges;
    case _ASHierarchyChangeTypeOriginalDelete:
      return _originalDeleteItemChanges;
    default:
      NSAssert(NO, @"Request for item changes with invalid type: %lu", (long)changeType);
      return nil;
  }
}

- (NSIndexSet *)indexesForItemChangesOfType:(_ASHierarchyChangeType)changeType inSection:(NSUInteger)section
{
  [self _ensureCompleted];
  NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
  for (_ASHierarchyItemChange *change in [self itemChangesOfType:changeType]) {
    [result addIndexes:[NSIndexSet as_indexSetFromIndexPaths:change.indexPaths inSection:section]];
  }
  return result;
}

- (NSUInteger)newSectionForOldSection:(NSUInteger)oldSection
{
  ASDisplayNodeAssertNotNil(_deletedSections, @"Cannot call %@ before `markCompleted` returns.", NSStringFromSelector(_cmd));
  ASDisplayNodeAssertNotNil(_insertedSections, @"Cannot call %@ before `markCompleted` returns.", NSStringFromSelector(_cmd));
  [self _ensureCompleted];
  if ([_deletedSections containsIndex:oldSection]) {
    return NSNotFound;
  }

  NSUInteger newIndex = oldSection - [_deletedSections countOfIndexesInRange:NSMakeRange(0, oldSection)];
  newIndex += [_insertedSections as_indexChangeByInsertingItemsBelowIndex:newIndex];
  return newIndex;
}

- (void)reloadData
{
  [self _ensureNotCompleted];
  NSAssert(_includesReloadData == NO, @"Attempt to reload data multiple times %@", self);
  _includesReloadData = YES;
}

- (void)deleteItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeOriginalDelete indexPaths:indexPaths animationOptions:options presorted:NO];
  [_originalDeleteItemChanges addObject:change];
}

- (void)deleteSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeOriginalDelete indexSet:sections animationOptions:options];
  [_originalDeleteSectionChanges addObject:change];
}

- (void)insertItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeOriginalInsert indexPaths:indexPaths animationOptions:options presorted:NO];
  [_originalInsertItemChanges addObject:change];
}

- (void)insertSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeOriginalInsert indexSet:sections animationOptions:options];
  [_originalInsertSectionChanges addObject:change];
}

- (void)reloadItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeReload indexPaths:indexPaths animationOptions:options presorted:NO];
  [_reloadItemChanges addObject:change];
}

- (void)reloadSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeReload indexSet:sections animationOptions:options];
  [_reloadSectionChanges addObject:change];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath animationOptions:(ASDataControllerAnimationOptions)options
{
  /**
   * TODO: Proper move implementation.
   */
  [self deleteItems:@[ indexPath ] animationOptions:options];
  [self insertItems:@[ newIndexPath ] animationOptions:options];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection animationOptions:(ASDataControllerAnimationOptions)options
{
  /**
   * TODO: Proper move implementation.
   */
  [self deleteSections:[NSIndexSet indexSetWithIndex:section] animationOptions:options];
  [self insertSections:[NSIndexSet indexSetWithIndex:newSection] animationOptions:options];
}

#pragma mark Private

- (BOOL)_ensureNotCompleted
{
  NSAssert(!_completed, @"Attempt to modify completed changeset %@", self);
  return !_completed;
}

- (BOOL)_ensureCompleted
{
  NSAssert(_completed, @"Attempt to process incomplete changeset %@", self);
  return _completed;
}

- (void)_sortAndCoalesceChangeArrays
{
  if (_includesReloadData) {
    return;
  }
  
  @autoreleasepool {

    // Split reloaded sections into [delete(oldIndex), insert(newIndex)]
    
    // Give these their "pre-reloads" values. Once we add in the reloads we'll re-process them.
    _deletedSections = [_ASHierarchySectionChange allIndexesInSectionChanges:_originalDeleteSectionChanges];
    _insertedSections = [_ASHierarchySectionChange allIndexesInSectionChanges:_originalInsertSectionChanges];
    for (_ASHierarchySectionChange *originalDeleteSectionChange in _originalDeleteSectionChanges) {
      [_deleteSectionChanges addObject:[originalDeleteSectionChange changeByFinalizingType]];
    }
    for (_ASHierarchySectionChange *originalInsertSectionChange in _originalInsertSectionChanges) {
      [_insertSectionChanges addObject:[originalInsertSectionChange changeByFinalizingType]];
    }
    
    for (_ASHierarchySectionChange *change in _reloadSectionChanges) {
      NSIndexSet *newSections = [change.indexSet as_indexesByMapping:^(NSUInteger idx) {
        NSUInteger newSec = [self newSectionForOldSection:idx];
        ASDisplayNodeAssert(newSec != NSNotFound, @"Request to reload and delete same section %tu", idx);
        return newSec;
      }];
      
      _ASHierarchySectionChange *deleteChange = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeDelete indexSet:change.indexSet animationOptions:change.animationOptions];
      [_deleteSectionChanges addObject:deleteChange];
      
      _ASHierarchySectionChange *insertChange = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeInsert indexSet:newSections animationOptions:change.animationOptions];
      [_insertSectionChanges addObject:insertChange];
    }
    
    [_ASHierarchySectionChange sortAndCoalesceSectionChanges:_deleteSectionChanges];
    [_ASHierarchySectionChange sortAndCoalesceSectionChanges:_insertSectionChanges];
    _deletedSections = [_ASHierarchySectionChange allIndexesInSectionChanges:_deleteSectionChanges];
    _insertedSections = [_ASHierarchySectionChange allIndexesInSectionChanges:_insertSectionChanges];

    // Split reloaded items into [delete(oldIndexPath), insert(newIndexPath)]
    for (_ASHierarchyItemChange *originalDeleteItemChange in _originalDeleteItemChanges) {
      [_deleteItemChanges addObject:[originalDeleteItemChange changeByFinalizingType]];
    }
    for (_ASHierarchyItemChange *originalInsertItemChange in _originalInsertItemChanges) {
      [_insertItemChanges addObject:[originalInsertItemChange changeByFinalizingType]];
    }
    
    [_ASHierarchyItemChange ensureItemChanges:_insertItemChanges ofSameType:_ASHierarchyChangeTypeInsert];
    NSDictionary *insertedIndexPathsMap = [_ASHierarchyItemChange sectionToIndexSetMapFromChanges:_insertItemChanges];
    
    [_ASHierarchyItemChange ensureItemChanges:_deleteItemChanges ofSameType:_ASHierarchyChangeTypeDelete];
    NSDictionary *deletedIndexPathsMap = [_ASHierarchyItemChange sectionToIndexSetMapFromChanges:_deleteItemChanges];
    
    for (_ASHierarchyItemChange *change in _reloadItemChanges) {
      NSAssert(change.changeType == _ASHierarchyChangeTypeReload, @"It must be a reload change to be in here");
      NSMutableArray *newIndexPaths = [NSMutableArray arrayWithCapacity:change.indexPaths.count];
      
      // Every indexPaths in the change need to update its section and/or row
      // depending on all the deletions and insertions
      // For reference, when batching reloads/deletes/inserts:
      // - delete/reload indexPaths that are passed in should all be their current indexPaths
      // - insert indexPaths that are passed in should all be their future indexPaths after deletions
      for (NSIndexPath *indexPath in change.indexPaths) {
        NSUInteger section = [self newSectionForOldSection:indexPath.section];
        NSUInteger item = indexPath.item;
        
        // Update row number based on deletions that are above the current row in the current section
        NSIndexSet *indicesDeletedInSection = deletedIndexPathsMap[@(indexPath.section)];
        item -= [indicesDeletedInSection countOfIndexesInRange:NSMakeRange(0, item)];
        // Update row number based on insertions that are above the current row in the future section
        NSIndexSet *indicesInsertedInSection = insertedIndexPathsMap[@(section)];
        item += [indicesInsertedInSection as_indexChangeByInsertingItemsBelowIndex:item];
        
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:item inSection:section];
        [newIndexPaths addObject:newIndexPath];
      }
      
      // All reload changes are translated into deletes and inserts
      // We delete the items that needs reload together with other deleted items, at their original index
      _ASHierarchyItemChange *deleteItemChangeFromReloadChange = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeDelete indexPaths:change.indexPaths animationOptions:change.animationOptions presorted:NO];
      [_deleteItemChanges addObject:deleteItemChangeFromReloadChange];
      // We insert the items that needs reload together with other inserted items, at their future index
      _ASHierarchyItemChange *insertItemChangeFromReloadChange = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeInsert indexPaths:newIndexPaths animationOptions:change.animationOptions presorted:NO];
      [_insertItemChanges addObject:insertItemChangeFromReloadChange];
    }
    
    // Ignore item deletes in reloaded/deleted sections.
    [_ASHierarchyItemChange sortAndCoalesceItemChanges:_deleteItemChanges ignoringChangesInSections:_deletedSections];

    // Ignore item inserts in reloaded(new)/inserted sections.
    [_ASHierarchyItemChange sortAndCoalesceItemChanges:_insertItemChanges ignoringChangesInSections:_insertedSections];
  }
}

- (void)_validateUpdate
{
  // If reloadData exists, ignore other changes
  if (_includesReloadData) {
    if ([self _includesPerItemOrSectionChanges]) {
      NSLog(@"Warning: A reload data shouldn't be used in conjuntion with other updates.");
    }
    return;
  }
  
  NSIndexSet *allReloadedSections = [_ASHierarchySectionChange allIndexesInSectionChanges:_reloadSectionChanges];
  
  NSInteger newSectionCount = _newItemCounts.size();
  NSInteger oldSectionCount = _oldItemCounts.size();
  
  NSInteger insertedSectionCount = _insertedSections.count;
  NSInteger deletedSectionCount = _deletedSections.count;
  // Assert that the new section count is correct.
  if (newSectionCount != oldSectionCount + insertedSectionCount - deletedSectionCount) {
    ASFailUpdateValidation(@"Invalid number of sections. The number of sections after the update (%zd) must be equal to the number of sections before the update (%zd) plus or minus the number of sections inserted or deleted (%tu inserted, %tu deleted)", newSectionCount, oldSectionCount, insertedSectionCount, deletedSectionCount);
    return;
  }
  
  // Assert that no invalid deletes/reloads happened.
  NSInteger invalidSectionDelete = NSNotFound;
  if (oldSectionCount == 0) {
    invalidSectionDelete = _deletedSections.firstIndex;
  } else {
    invalidSectionDelete = [_deletedSections indexGreaterThanIndex:oldSectionCount - 1];
  }
  if (invalidSectionDelete != NSNotFound) {
    ASFailUpdateValidation(@"Attempt to delete section %zd but there are only %zd sections before the update.", invalidSectionDelete, oldSectionCount);
    return;
  }
  
  for (_ASHierarchyItemChange *change in _deleteItemChanges) {
    for (NSIndexPath *indexPath in change.indexPaths) {
      // Assert that item delete happened in a valid section.
      NSInteger section = indexPath.section;
      NSInteger item = indexPath.item;
      if (section >= oldSectionCount) {
        ASFailUpdateValidation(@"Attempt to delete item %zd from section %zd, but there are only %zd sections before the update.", item, section, oldSectionCount);
        return;
      }
      
      // Assert that item delete happened to a valid item.
      NSInteger oldItemCount = _oldItemCounts[section];
      if (item >= oldItemCount) {
        ASFailUpdateValidation(@"Attempt to delete item %zd from section %zd, which only contains %zd items before the update.", item, section, oldItemCount);
        return;
      }
    }
  }
  
  for (_ASHierarchyItemChange *change in _insertItemChanges) {
    for (NSIndexPath *indexPath in change.indexPaths) {
      NSInteger section = indexPath.section;
      NSInteger item = indexPath.item;
      // Assert that item insert happened in a valid section.
      if (section >= newSectionCount) {
        ASFailUpdateValidation(@"Attempt to insert item %zd into section %zd, but there are only %zd sections after the update.", item, section, newSectionCount);
        return;
      }
      
      // Assert that item delete happened to a valid item.
      NSInteger newItemCount = _newItemCounts[section];
      if (item >= newItemCount) {
        ASFailUpdateValidation(@"Attempt to insert item %zd into section %zd, which only contains %zd items after the update.", item, section, newItemCount);
        return;
      }
    }
  }
  
  // Assert that no sections were inserted out of bounds.
  NSInteger invalidSectionInsert = NSNotFound;
  if (newSectionCount == 0) {
    invalidSectionInsert = _insertedSections.firstIndex;
  } else {
    invalidSectionInsert = [_insertedSections indexGreaterThanIndex:newSectionCount - 1];
  }
  if (invalidSectionInsert != NSNotFound) {
    ASFailUpdateValidation(@"Attempt to insert section %zd but there are only %zd sections after the update.", invalidSectionInsert, newSectionCount);
    return;
  }
  
  for (NSUInteger oldSection = 0; oldSection < oldSectionCount; oldSection++) {
    NSInteger oldItemCount = _oldItemCounts[oldSection];
    // If section was reloaded, ignore.
    if ([allReloadedSections containsIndex:oldSection]) {
      continue;
    }
    
    // If section was deleted, ignore.
    NSUInteger newSection = [self newSectionForOldSection:oldSection];
    if (newSection == NSNotFound) {
      continue;
    }
    
    NSIndexSet *originalInsertedItems = [self indexesForItemChangesOfType:_ASHierarchyChangeTypeOriginalInsert inSection:newSection];
    NSIndexSet *originalDeletedItems = [self indexesForItemChangesOfType:_ASHierarchyChangeTypeOriginalDelete inSection:oldSection];
    NSIndexSet *reloadedItems = [self indexesForItemChangesOfType:_ASHierarchyChangeTypeReload inSection:oldSection];
    
    // Assert that no reloaded items were deleted.
    NSInteger deletedReloadedItem = [originalDeletedItems as_intersectionWithIndexes:reloadedItems].firstIndex;
    if (deletedReloadedItem != NSNotFound) {
      ASFailUpdateValidation(@"Attempt to delete and reload the same item at index path %@", [NSIndexPath indexPathForItem:deletedReloadedItem inSection:oldSection]);
      return;
    }
    
    // Assert that the new item count is correct.
    NSInteger newItemCount = _newItemCounts[newSection];
    NSInteger insertedItemCount = originalInsertedItems.count;
    NSInteger deletedItemCount = originalDeletedItems.count;
    if (newItemCount != oldItemCount + insertedItemCount - deletedItemCount) {
      ASFailUpdateValidation(@"Invalid number of items in section %zd. The number of items after the update (%zd) must be equal to the number of items before the update (%zd) plus or minus the number of items inserted or deleted (%zd inserted, %zd deleted).", oldSection, newItemCount, oldItemCount, insertedItemCount, deletedItemCount);
      return;
    }
  }
}

- (BOOL)_includesPerItemOrSectionChanges
{
  return 0 < (_originalDeleteSectionChanges.count + _originalDeleteItemChanges.count
              +_originalInsertSectionChanges.count + _originalInsertItemChanges.count
              + _reloadSectionChanges.count + _reloadItemChanges.count);
}

#pragma mark - Debugging (Private)

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)debugDescription
{
  return ASObjectDescriptionMake(self, [self propertiesForDebugDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  [result addObject:@{ @"includesReloadData" : @(_includesReloadData) }];
  if (_reloadSectionChanges.count > 0) {
    [result addObject:@{ @"reloadSections" : [_ASHierarchySectionChange smallDescriptionForSectionChanges:_reloadSectionChanges] }];
  }
  if (_reloadItemChanges.count > 0) {
    [result addObject:@{ @"reloadItems" : [_ASHierarchyItemChange smallDescriptionForItemChanges:_reloadItemChanges] }];
  }
  if (_originalDeleteSectionChanges.count > 0) {
    [result addObject:@{ @"deleteSections" : [_ASHierarchySectionChange smallDescriptionForSectionChanges:_originalDeleteSectionChanges] }];
  }
  if (_originalDeleteItemChanges.count > 0) {
    [result addObject:@{ @"deleteItems" : [_ASHierarchyItemChange smallDescriptionForItemChanges:_originalDeleteItemChanges] }];
  }
  if (_originalInsertSectionChanges.count > 0) {
    [result addObject:@{ @"insertSections" : [_ASHierarchySectionChange smallDescriptionForSectionChanges:_originalInsertSectionChanges] }];
  }
  if (_originalInsertItemChanges.count > 0) {
    [result addObject:@{ @"insertItems" : [_ASHierarchyItemChange smallDescriptionForItemChanges:_originalInsertItemChanges] }];
  }
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  return [self propertiesForDescription];
}

@end

@implementation _ASHierarchySectionChange

- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexSet:(NSIndexSet *)indexSet animationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  self = [super init];
  if (self) {
    ASDisplayNodeAssert(indexSet.count > 0, @"Request to create _ASHierarchySectionChange with no sections!");
    _changeType = changeType;
    _indexSet = indexSet;
    _animationOptions = animationOptions;
  }
  return self;
}

- (_ASHierarchySectionChange *)changeByFinalizingType
{
  _ASHierarchyChangeType newType;
  switch (_changeType) {
    case _ASHierarchyChangeTypeOriginalInsert:
      newType = _ASHierarchyChangeTypeInsert;
      break;
    case _ASHierarchyChangeTypeOriginalDelete:
      newType = _ASHierarchyChangeTypeDelete;
      break;
    default:
      ASFailUpdateValidation(@"Attempt to finalize section change of invalid type %@.", NSStringFromASHierarchyChangeType(_changeType));
      return self;
  }
  return [[_ASHierarchySectionChange alloc] initWithChangeType:newType indexSet:_indexSet animationOptions:_animationOptions];
}

+ (void)sortAndCoalesceSectionChanges:(NSMutableArray<_ASHierarchySectionChange *> *)changes
{
  _ASHierarchySectionChange *firstChange = changes.firstObject;
  if (firstChange == nil) {
    return;
  }
  _ASHierarchyChangeType type = [firstChange changeType];
  
  ASDisplayNodeAssert(ASHierarchyChangeTypeIsFinal(type), @"Attempt to sort and coalesce section changes of intermediary type %@. Why?", NSStringFromASHierarchyChangeType(type));
    
  // Lookup table [Int: AnimationOptions]
  __block std::unordered_map<NSUInteger, ASDataControllerAnimationOptions> animationOptions;
  
  // All changed indexes
  NSMutableIndexSet *allIndexes = [NSMutableIndexSet new];
  
  for (_ASHierarchySectionChange *change in changes) {
    ASDataControllerAnimationOptions options = change.animationOptions;
    NSIndexSet *indexes = change.indexSet;
    [indexes enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
      for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
        animationOptions[i] = options;
      }
    }];
    [allIndexes addIndexes:indexes];
  }
  
  // Create new changes by grouping sorted changes by animation option
  NSMutableArray *result = [[NSMutableArray alloc] init];
  
  __block ASDataControllerAnimationOptions currentOptions = 0;
  NSMutableIndexSet *currentIndexes = [NSMutableIndexSet indexSet];

  BOOL reverse = type == _ASHierarchyChangeTypeDelete || type == _ASHierarchyChangeTypeOriginalDelete;
  NSEnumerationOptions options = reverse ? NSEnumerationReverse : kNilOptions;

  [allIndexes enumerateRangesWithOptions:options usingBlock:^(NSRange range, BOOL * _Nonnull stop) {
    NSInteger increment = reverse ? -1 : 1;
    NSUInteger start = reverse ? NSMaxRange(range) - 1 : range.location;
    NSInteger limit = reverse ? range.location - 1 : NSMaxRange(range);
    for (NSInteger i = start; i != limit; i += increment) {
      ASDataControllerAnimationOptions options = animationOptions[i];
      
      // End the previous group if needed.
      if (options != currentOptions && currentIndexes.count > 0) {
        _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:type indexSet:[currentIndexes copy] animationOptions:currentOptions];
        [result addObject:change];
        [currentIndexes removeAllIndexes];
      }
      
      // Start a new group if needed.
      if (currentIndexes.count == 0) {
        currentOptions = options;
      }
      
      [currentIndexes addIndex:i];
    }
  }];

  // Finish up the last group.
  if (currentIndexes.count > 0) {
    _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:type indexSet:[currentIndexes copy] animationOptions:currentOptions];
    [result addObject:change];
  }

  [changes setArray:result];
}

+ (NSMutableIndexSet *)allIndexesInSectionChanges:(NSArray<_ASHierarchySectionChange *> *)changes
{
  NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
  for (_ASHierarchySectionChange *change in changes) {
    [indexes addIndexes:change.indexSet];
  }
  return indexes;
}

#pragma mark - Debugging (Private)

+ (NSString *)smallDescriptionForSectionChanges:(NSArray<_ASHierarchySectionChange *> *)changes
{
  NSMutableIndexSet *unionIndexSet = [NSMutableIndexSet indexSet];
  for (_ASHierarchySectionChange *change in changes) {
    [unionIndexSet addIndexes:change.indexSet];
  }
  return [unionIndexSet as_smallDescription];
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)debugDescription
{
  return ASObjectDescriptionMake(self, [self propertiesForDebugDescription]);
}

- (NSString *)smallDescription
{
  return [self.indexSet as_smallDescription];
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  [result addObject:@{ @"indexes" : [self.indexSet as_smallDescription] }];
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  [result addObject:@{ @"anim" : @(_animationOptions) }];
  [result addObject:@{ @"type" : NSStringFromASHierarchyChangeType(_changeType) }];
  [result addObject:@{ @"indexes" : self.indexSet }];
  return result;
}

@end

@implementation _ASHierarchyItemChange

- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions presorted:(BOOL)presorted
{
  self = [super init];
  if (self) {
    ASDisplayNodeAssert(indexPaths.count > 0, @"Request to create _ASHierarchyItemChange with no items!");
    _changeType = changeType;
    if (presorted) {
      _indexPaths = indexPaths;
    } else {
      SEL sorting = changeType == _ASHierarchyChangeTypeDelete ? @selector(asdk_inverseCompare:) : @selector(compare:);
      _indexPaths = [indexPaths sortedArrayUsingSelector:sorting];
    }
    _animationOptions = animationOptions;
  }
  return self;
}

// Create a mapping out of changes indexPaths to a {@section : [indexSet]} fashion
// e.g. changes: (0 - 0), (0 - 1), (2 - 5)
//  will become: {@0 : [0, 1], @2 : [5]}
+ (NSDictionary *)sectionToIndexSetMapFromChanges:(NSArray<_ASHierarchyItemChange *> *)changes
{
  NSMutableDictionary *sectionToIndexSetMap = [NSMutableDictionary dictionary];
  for (_ASHierarchyItemChange *change in changes) {
    for (NSIndexPath *indexPath in change.indexPaths) {
      NSNumber *sectionKey = @(indexPath.section);
      NSMutableIndexSet *indexSet = sectionToIndexSetMap[sectionKey];
      if (indexSet) {
        [indexSet addIndex:indexPath.item];
      } else {
        indexSet = [NSMutableIndexSet indexSetWithIndex:indexPath.item];
        sectionToIndexSetMap[sectionKey] = indexSet;
      }
    }
  }
  return sectionToIndexSetMap;
}

+ (void)ensureItemChanges:(NSArray<_ASHierarchyItemChange *> *)changes ofSameType:(_ASHierarchyChangeType)changeType
{
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  for (_ASHierarchyItemChange *change in changes) {
    NSAssert(change.changeType == changeType, @"The map we created must all be of the same changeType as of now");
  }
#endif
}

- (_ASHierarchyItemChange *)changeByFinalizingType
{
  _ASHierarchyChangeType newType;
  switch (_changeType) {
    case _ASHierarchyChangeTypeOriginalInsert:
      newType = _ASHierarchyChangeTypeInsert;
      break;
    case _ASHierarchyChangeTypeOriginalDelete:
      newType = _ASHierarchyChangeTypeDelete;
      break;
    default:
      ASFailUpdateValidation(@"Attempt to finalize item change of invalid type %@.", NSStringFromASHierarchyChangeType(_changeType));
      return self;
  }
  return [[_ASHierarchyItemChange alloc] initWithChangeType:newType indexPaths:_indexPaths animationOptions:_animationOptions presorted:YES];
}

+ (void)sortAndCoalesceItemChanges:(NSMutableArray<_ASHierarchyItemChange *> *)changes ignoringChangesInSections:(NSIndexSet *)ignoredSections
{
  if (changes.count < 1) {
    return;
  }
  
  _ASHierarchyChangeType type = [changes.firstObject changeType];
  ASDisplayNodeAssert(ASHierarchyChangeTypeIsFinal(type), @"Attempt to sort and coalesce item changes of intermediary type %@. Why?", NSStringFromASHierarchyChangeType(type));
    
  // Lookup table [NSIndexPath: AnimationOptions]
  NSMutableDictionary *animationOptions = [NSMutableDictionary new];
  
  // All changed index paths, sorted
  NSMutableArray *allIndexPaths = [[NSMutableArray alloc] init];
  
  for (_ASHierarchyItemChange *change in changes) {
    for (NSIndexPath *indexPath in change.indexPaths) {
      if (![ignoredSections containsIndex:indexPath.section]) {
        animationOptions[indexPath] = @(change.animationOptions);
        [allIndexPaths addObject:indexPath];
      }
    }
  }
  
  SEL sorting = type == _ASHierarchyChangeTypeDelete ? @selector(asdk_inverseCompare:) : @selector(compare:);
  [allIndexPaths sortUsingSelector:sorting];

  // Create new changes by grouping sorted changes by animation option
  NSMutableArray *result = [[NSMutableArray alloc] init];

  ASDataControllerAnimationOptions currentOptions = 0;
  NSMutableArray *currentIndexPaths = [NSMutableArray array];

  for (NSIndexPath *indexPath in allIndexPaths) {
    ASDataControllerAnimationOptions options = [animationOptions[indexPath] integerValue];

    // End the previous group if needed.
    if (options != currentOptions && currentIndexPaths.count > 0) {
      _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:type indexPaths:[currentIndexPaths copy] animationOptions:currentOptions presorted:YES];
      [result addObject:change];
      [currentIndexPaths removeAllObjects];
    }

    // Start a new group if needed.
    if (currentIndexPaths.count == 0) {
      currentOptions = options;
    }

    [currentIndexPaths addObject:indexPath];
  }

  // Finish up the last group.
  if (currentIndexPaths.count > 0) {
    _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:type indexPaths:[currentIndexPaths copy] animationOptions:currentOptions presorted:YES];
    [result addObject:change];
  }

  [changes setArray:result];
}

#pragma mark - Debugging (Private)

+ (NSString *)smallDescriptionForItemChanges:(NSArray<_ASHierarchyItemChange *> *)changes
{
  NSDictionary *map = [self sectionToIndexSetMapFromChanges:changes];
  NSMutableString *str = [NSMutableString stringWithString:@"{ "];
  [map enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull section, NSIndexSet * _Nonnull indexSet, BOOL * _Nonnull stop) {
    [str appendFormat:@"@%lu : %@ ", (long)section.integerValue, [indexSet as_smallDescription]];
  }];
  [str appendString:@"}"];
  return str;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)debugDescription
{
  return ASObjectDescriptionMake(self, [self propertiesForDebugDescription]);
}

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  [result addObject:@{ @"indexPaths" : self.indexPaths }];
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  [result addObject:@{ @"anim" : @(_animationOptions) }];
  [result addObject:@{ @"type" : NSStringFromASHierarchyChangeType(_changeType) }];
  [result addObject:@{ @"indexPaths" : self.indexPaths }];
  return result;
}

@end

//
//  _ASHierarchyChangeSet.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/29/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "_ASHierarchyChangeSet.h"
#import "ASInternalHelpers.h"

@interface _ASHierarchySectionChange ()
- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexSet:(NSIndexSet *)indexSet animationOptions:(ASDataControllerAnimationOptions)animationOptions;

/**
 On return `changes` is sorted according to the change type with changes coalesced by animationOptions
 Assumes: `changes` is [_ASHierarchySectionChange] all with the same changeType
 */
+ (void)sortAndCoalesceChanges:(NSMutableArray *)changes;

/// Returns all the indexes from all the `indexSet`s of the given `_ASHierarchySectionChange` objects.
+ (NSMutableIndexSet *)allIndexesInChanges:(NSArray *)changes;
@end

@interface _ASHierarchyItemChange ()
- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions presorted:(BOOL)presorted;

/**
 On return `changes` is sorted according to the change type with changes coalesced by animationOptions
 Assumes: `changes` is [_ASHierarchyItemChange] all with the same changeType
 */
+ (void)sortAndCoalesceChanges:(NSMutableArray *)changes ignoringChangesInSections:(NSIndexSet *)sections;
@end

@interface _ASHierarchyChangeSet ()

@property (nonatomic, strong, readonly) NSMutableArray *insertItemChanges;
@property (nonatomic, strong, readonly) NSMutableArray *deleteItemChanges;
@property (nonatomic, strong, readonly) NSMutableArray *reloadItemChanges;
@property (nonatomic, strong, readonly) NSMutableArray *insertSectionChanges;
@property (nonatomic, strong, readonly) NSMutableArray *deleteSectionChanges;
@property (nonatomic, strong, readonly) NSMutableArray *reloadSectionChanges;

@end

@implementation _ASHierarchyChangeSet

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    _insertItemChanges = [NSMutableArray new];
    _deleteItemChanges = [NSMutableArray new];
    _reloadItemChanges = [NSMutableArray new];
    _insertSectionChanges = [NSMutableArray new];
    _deleteSectionChanges = [NSMutableArray new];
    _reloadSectionChanges = [NSMutableArray new];
  }
  return self;
}

#pragma mark External API

- (void)markCompleted
{
  NSAssert(!_completed, @"Attempt to mark already-completed changeset as completed.");
  _completed = YES;
  [self _sortAndCoalesceChangeArrays];
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
    default:
      NSAssert(NO, @"Request for section changes with invalid type: %lu", (long)changeType);
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
    default:
      NSAssert(NO, @"Request for item changes with invalid type: %lu", (long)changeType);
  }
}

- (NSInteger)newSectionForOldSection:(NSInteger)oldSection
{
  [self _ensureCompleted];
  if ([_deletedSections containsIndex:oldSection]) {
    return NSNotFound;
  }

  NSInteger indexAfterDeletes = oldSection - [_deletedSections countOfIndexesInRange:NSMakeRange(0, oldSection)];
  return indexAfterDeletes + [_insertedSections countOfIndexesInRange:NSMakeRange(0, indexAfterDeletes)];
}

- (void)deleteItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeDelete indexPaths:indexPaths animationOptions:options presorted:NO];
  [_deleteItemChanges addObject:change];
}

- (void)deleteSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeDelete indexSet:sections animationOptions:options];
  [_deleteSectionChanges addObject:change];
}

- (void)insertItems:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:_ASHierarchyChangeTypeInsert indexPaths:indexPaths animationOptions:options presorted:NO];
  [_insertItemChanges addObject:change];
}

- (void)insertSections:(NSIndexSet *)sections animationOptions:(ASDataControllerAnimationOptions)options
{
  [self _ensureNotCompleted];
  _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:_ASHierarchyChangeTypeInsert indexSet:sections animationOptions:options];
  [_insertSectionChanges addObject:change];
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
  @autoreleasepool {
    [_ASHierarchySectionChange sortAndCoalesceChanges:_deleteSectionChanges];
    [_ASHierarchySectionChange sortAndCoalesceChanges:_insertSectionChanges];
    [_ASHierarchySectionChange sortAndCoalesceChanges:_reloadSectionChanges];

    _deletedSections = [[_ASHierarchySectionChange allIndexesInChanges:_deleteSectionChanges] copy];
    _insertedSections = [[_ASHierarchySectionChange allIndexesInChanges:_insertSectionChanges] copy];
    _reloadedSections = [[_ASHierarchySectionChange allIndexesInChanges:_reloadSectionChanges] copy];

    // These are invalid old section indexes.
    NSMutableIndexSet *deletedOrReloaded = [_deletedSections mutableCopy];
    [deletedOrReloaded addIndexes:_reloadedSections];

    // These are invalid new section indexes.
    NSMutableIndexSet *insertedOrReloaded = [_insertedSections mutableCopy];

    // Get the new section that each reloaded section index corresponds to.
    [_reloadedSections enumerateIndexesUsingBlock:^(NSUInteger oldIndex, __unused BOOL * stop) {
      NSUInteger newIndex = [self newSectionForOldSection:oldIndex];
      if (newIndex != NSNotFound) {
        [insertedOrReloaded addIndex:newIndex];
      }
    }];

    // Ignore item reloads/deletes in reloaded/deleted sections.
    [_ASHierarchyItemChange sortAndCoalesceChanges:_deleteItemChanges ignoringChangesInSections:deletedOrReloaded];
    [_ASHierarchyItemChange sortAndCoalesceChanges:_reloadItemChanges ignoringChangesInSections:deletedOrReloaded];

    // Ignore item inserts in reloaded(new)/inserted sections.
    [_ASHierarchyItemChange sortAndCoalesceChanges:_insertItemChanges ignoringChangesInSections:insertedOrReloaded];
  }
}

@end

@implementation _ASHierarchySectionChange

- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexSet:(NSIndexSet *)indexSet animationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  self = [super init];
  if (self) {
    _changeType = changeType;
    _indexSet = indexSet;
    _animationOptions = animationOptions;
  }
  return self;
}

+ (void)sortAndCoalesceChanges:(NSMutableArray *)changes
{
  if (changes.count < 1) {
    return;
  }
  
  _ASHierarchyChangeType type = [changes.firstObject changeType];
  
  // Lookup table [Int: AnimationOptions]
  NSMutableDictionary *animationOptions = [NSMutableDictionary new];
  
  // All changed indexes, sorted
  NSMutableIndexSet *allIndexes = [NSMutableIndexSet new];
  
  for (_ASHierarchySectionChange *change in changes) {
    [change.indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, __unused BOOL *stop) {
      animationOptions[@(idx)] = @(change.animationOptions);
    }];
    [allIndexes addIndexes:change.indexSet];
  }
  
  // Create new changes by grouping sorted changes by animation option
  NSMutableArray *result = [NSMutableArray new];
  
  __block ASDataControllerAnimationOptions currentOptions = 0;
  NSMutableIndexSet *currentIndexes = [NSMutableIndexSet indexSet];

  NSEnumerationOptions options = type == _ASHierarchyChangeTypeDelete ? NSEnumerationReverse : kNilOptions;

  [allIndexes enumerateIndexesWithOptions:options usingBlock:^(NSUInteger idx, __unused BOOL * stop) {
    ASDataControllerAnimationOptions options = [animationOptions[@(idx)] integerValue];

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

    [currentIndexes addIndex:idx];
  }];

  // Finish up the last group.
  if (currentIndexes.count > 0) {
    _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:type indexSet:[currentIndexes copy] animationOptions:currentOptions];
    [result addObject:change];
  }

  [changes setArray:result];
}

+ (NSMutableIndexSet *)allIndexesInChanges:(NSArray *)changes
{
  NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
  for (_ASHierarchySectionChange *change in changes) {
    [indexes addIndexes:change.indexSet];
  }
  return indexes;
}

@end

@implementation _ASHierarchyItemChange

- (instancetype)initWithChangeType:(_ASHierarchyChangeType)changeType indexPaths:(NSArray *)indexPaths animationOptions:(ASDataControllerAnimationOptions)animationOptions presorted:(BOOL)presorted
{
  self = [super init];
  if (self) {
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

+ (void)sortAndCoalesceChanges:(NSMutableArray *)changes ignoringChangesInSections:(NSIndexSet *)sections
{
  if (changes.count < 1) {
    return;
  }
  
  _ASHierarchyChangeType type = [changes.firstObject changeType];
  
  // Lookup table [NSIndexPath: AnimationOptions]
  NSMutableDictionary *animationOptions = [NSMutableDictionary new];
  
  // All changed index paths, sorted
  NSMutableArray *allIndexPaths = [NSMutableArray new];
  
  NSPredicate *indexPathInValidSection = [NSPredicate predicateWithBlock:^BOOL(NSIndexPath *indexPath, __unused NSDictionary *_) {
    return ![sections containsIndex:indexPath.section];
  }];
  for (_ASHierarchyItemChange *change in changes) {
    for (NSIndexPath *indexPath in change.indexPaths) {
      if ([indexPathInValidSection evaluateWithObject:indexPath]) {
        animationOptions[indexPath] = @(change.animationOptions);
        [allIndexPaths addObject:indexPath];
      }
    }
  }
  
  SEL sorting = type == _ASHierarchyChangeTypeDelete ? @selector(asdk_inverseCompare:) : @selector(compare:);
  [allIndexPaths sortUsingSelector:sorting];

  // Create new changes by grouping sorted changes by animation option
  NSMutableArray *result = [NSMutableArray new];

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

@end

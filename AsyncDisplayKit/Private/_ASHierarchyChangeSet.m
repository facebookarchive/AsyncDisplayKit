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

@implementation _ASHierarchyChangeSet {
  NSMutableIndexSet *_deletedSections;
  NSMutableIndexSet *_insertedSections;
  NSMutableIndexSet *_reloadedSections;
  NSMutableArray *_insertedItems;
  NSMutableArray *_deletedItems;
  NSMutableArray *_reloadedItems;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _deletedSections = [NSMutableIndexSet new];
    _insertedSections = [NSMutableIndexSet new];
    _reloadedSections = [NSMutableIndexSet new];
    
    _deletedItems = [NSMutableArray new];
    _insertedItems = [NSMutableArray new];
    _reloadedItems = [NSMutableArray new];
    
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
      NSAssert(NO, @"Request for section changes with invalid type: %lu", changeType);
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
      NSAssert(NO, @"Request for item changes with invalid type: %lu", changeType);
  }
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
    [_ASHierarchyItemChange sortAndCoalesceChanges:_deleteItemChanges ignoringChangesInSections:_deletedSections];
    [_ASHierarchyItemChange sortAndCoalesceChanges:_reloadItemChanges ignoringChangesInSections:_reloadedSections];
    [_ASHierarchyItemChange sortAndCoalesceChanges:_insertItemChanges ignoringChangesInSections:_insertedSections];
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
  __block NSMutableIndexSet *currentIndexes = nil;
  NSUInteger lastIndex = allIndexes.lastIndex;
  
  NSEnumerationOptions options = type == _ASHierarchyChangeTypeDelete ? NSEnumerationReverse : kNilOptions;
  [allIndexes enumerateIndexesWithOptions:options usingBlock:^(NSUInteger idx, __unused BOOL * stop) {
    ASDataControllerAnimationOptions options = [animationOptions[@(idx)] integerValue];
    BOOL endingCurrentGroup = NO;
    
    if (currentIndexes == nil) {
      // Starting a new group
      currentIndexes = [NSMutableIndexSet indexSetWithIndex:idx];
      currentOptions = options;
    } else if (options == currentOptions) {
      // Continuing the current group
      [currentIndexes addIndex:idx];
    } else {
      endingCurrentGroup = YES;
    }
    
    BOOL endingLastGroup = (currentIndexes != nil && lastIndex == idx);
    
    if (endingCurrentGroup || endingLastGroup) {
      _ASHierarchySectionChange *change = [[_ASHierarchySectionChange alloc] initWithChangeType:type indexSet:currentIndexes animationOptions:currentOptions];
      [result addObject:change];
      currentOptions = 0;
      currentIndexes = nil;
    }
  }];
  
  [changes setArray:result];
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
  NSMutableArray *currentIndexPaths = nil;
  NSIndexPath *lastIndexPath = allIndexPaths.lastObject;
  
  for (NSIndexPath *indexPath in allIndexPaths) {
    ASDataControllerAnimationOptions options = [animationOptions[indexPath] integerValue];
    BOOL endingCurrentGroup = NO;
    
    if (currentIndexPaths == nil) {
      // Starting a new group
      currentIndexPaths = [NSMutableArray arrayWithObject:indexPath];
      currentOptions = options;
    } else if (options == currentOptions) {
      // Continuing the current group
      [currentIndexPaths addObject:indexPath];
    } else {
      endingCurrentGroup = YES;
    }
    
    BOOL endingLastGroup = (currentIndexPaths != nil && (NSOrderedSame == [lastIndexPath compare:indexPath]));

    if (endingCurrentGroup || endingLastGroup) {
      _ASHierarchyItemChange *change = [[_ASHierarchyItemChange alloc] initWithChangeType:type indexPaths:currentIndexPaths animationOptions:currentOptions presorted:YES];
      [result addObject:change];
      currentOptions = 0;
      currentIndexPaths = nil;
    }
  }
  
  [changes setArray:result];
}

@end

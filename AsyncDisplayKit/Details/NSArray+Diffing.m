//
//  NSArray+Diffing.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "NSArray+Diffing.h"
#import "ASAssert.h"
#import "NSIndexSet+ASHelpers.h"
#import "ASEqualityHelpers.h"

// This is required to get +indexPathForItem:inSection: which uses tagged pointers for performance.
#import <UIKit/UICollectionView.h>

/**
 * If a comparison block exists, calls that.
 * Otherwise, checks if the precomputed hashes are equal.
 * If they are equal, uses @c ASObjectIsEqual
 */
#define FAST_EQUAL(selfIndex, otherIndex) (comparison ? comparison(self[selfIndex], array[otherIndex]) : (selfHashes[selfIndex] == arrayHashes[otherIndex] && ASObjectIsEqual(self[selfIndex], array[otherIndex])))

#define FAST_EQUAL_NOHASH(array, index, otherArray, otherIndex) (comparison ? comparison(array[index], otherArray[otherIndex]) : ASObjectIsEqual(array[index], otherArray[otherIndex]))

@implementation NSArray (Diffing)

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions compareBlock:nil];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  [self asdk_diffWithArray:array insertions:insertions deletions:deletions commons:nil compareBlock:comparison];
}

- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions commons:(NSIndexSet **)commons compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  NSUInteger selfCount = self.count;
  NSUInteger arrayCount = array.count;

  // If they didn't provide a comparison block, we are going to use isEqual:
  // We precompute the hashes of all our elements because for non-trivial
  // counts, even extremely fast isEqual: implementations will be far too slow.
  NSUInteger selfHashes[selfCount];
  NSUInteger arrayHashes[arrayCount];
  if (comparison == nil) {
    NSUInteger i = 0;
    for (id object in self) {
      selfHashes[i] = [object hash];
      i += 1;
    }
    i = 0;
    for (id object in array) {
      arrayHashes[i] = [object hash];
      i += 1;
    }
  }

  NSIndexSet *commonIndexes = [self _asdk_commonIndexesWithArray:array selfHashes:selfHashes arrayHashes:arrayHashes compareBlock:comparison];
  NSUInteger commonCount = commonIndexes.count;

  if (commons) {
    *commons = commonIndexes;
  }

  if (selfCount == arrayCount && commonCount == selfCount) {
    return;
  }

  if (insertions) {
    NSArray *commonObjects = [self objectsAtIndexes:commonIndexes];
    NSMutableIndexSet *insertionIndexes = [NSMutableIndexSet indexSet];
    for (NSInteger i = 0, j = 0; i < commonCount || j < arrayCount;) {
      if (i < commonCount && j < arrayCount && FAST_EQUAL_NOHASH(commonObjects, i, array, j)) {
        i++; j++;
      } else {
        [insertionIndexes addIndex:j];
        j++;
      }
    }
    *insertions = insertionIndexes;
  }
  
  if (deletions) {
    NSMutableIndexSet *deletionIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.count)];
    [deletionIndexes removeIndexes:commonIndexes];
    *deletions = deletionIndexes;
  }
}

- (NSIndexSet *)_asdk_commonIndexesWithArray:(NSArray *)array selfHashes:(NSUInteger *)selfHashes arrayHashes:(NSUInteger *)arrayHashes compareBlock:(BOOL (^)(id lhs, id rhs))comparison
{
  NSInteger selfCount = self.count;
  NSInteger arrayCount = array.count;
  
  // Allocate the diff map in the heap so we don't blow the stack for large arrays.
  NSInteger (*lengths)[arrayCount+1] = NULL;
  size_t lengthsSize = ((selfCount+1) * sizeof(*lengths));
  // Would rather use initWithCapacity: to skip the zeroing, but TECHNICALLY
  // `mutableBytes` is only guaranteed to be non-NULL if the data object has a non-zero length.
  NS_VALID_UNTIL_END_OF_SCOPE NSMutableData *lengthsData = [[NSMutableData alloc] initWithLength:lengthsSize];
  lengths = lengthsData.mutableBytes;
  if (lengths == NULL) {
    ASDisplayNodeFailAssert(@"Failed to allocate memory for diffing with size %tu", lengthsSize);
    return nil;
  }
  
  for (NSInteger i = 0; i <= selfCount; i++) {
    for (NSInteger j = 0; j <= arrayCount; j++) {
      if (i == 0 || j == 0) {
        lengths[i][j] = 0;
      } else if (FAST_EQUAL(i-1, j-1)) {
        lengths[i][j] = 1 + lengths[i-1][j-1];
      } else {
        lengths[i][j] = MAX(lengths[i-1][j], lengths[i][j-1]);
      }
    }
  }
  
  NSMutableIndexSet *common = [NSMutableIndexSet indexSet];
  NSInteger i = selfCount, j = arrayCount;
  while(i > 0 && j > 0) {
    if (FAST_EQUAL(i-1, j-1)) {
      [common addIndex:(i-1)];
      i--; j--;
    } else if (lengths[i-1][j] > lengths[i][j-1]) {
      i--;
    } else {
      j--;
    }
  }
  
  return common;
}

- (void)asdk_nestedDiffWithArray:(NSArray *)nestedArray
                insertedSections:(NSIndexSet **)insertedSections
                 deletedSections:(NSIndexSet **)deletedSections
                   insertedItems:(NSArray<NSIndexPath *> **)insertedItems
                    deletedItems:(NSArray<NSIndexPath *> **)deletedItems
                    nestingBlock:(__attribute((noescape)) NSArray *(^)(id object))nestingBlock;
{
  NSIndexSet *survivingSections = nil;
  NSMutableArray<NSIndexPath *> *mutableInsertedItems = [NSMutableArray array];
  NSMutableArray<NSIndexPath *> *mutableDeletedItems = [NSMutableArray array];

  [self asdk_diffWithArray:nestedArray insertions:insertedSections deletions:deletedSections commons:&survivingSections compareBlock:^BOOL(id lhs, id rhs) {
    return [lhs isEqual:rhs];
  }];
  // Would prefer to use ASDN::Mutex but:
  // 1. It doesn't play well with __block
  // 2. This file contains code that won't build under C++ (lengths = lengthsData.mutableBytes;)
  __block pthread_mutex_t lock;
  ASDisplayNodeAssert(pthread_mutex_init(&lock, NULL) == 0, @"Failed to init lock.");
  [self enumerateObjectsAtIndexes:survivingSections options:NSEnumerationConcurrent usingBlock:^(id  _Nonnull oldSection, NSUInteger oldSectionIndex, BOOL * _Nonnull stop) {
    NSUInteger newSectionIndex = oldSectionIndex;
    newSectionIndex -= [*deletedSections countOfIndexesInRange:NSMakeRange(0, oldSectionIndex)];
    newSectionIndex += [*insertedSections as_indexChangeByInsertingItemsBelowIndex:oldSectionIndex];

    id newSection = nestedArray[newSectionIndex];
    NSArray *oldItems = nestingBlock(oldSection);
    NSArray *newItems = nestingBlock(newSection);
    NSIndexSet *deletedItemsInSection = nil, *insertedItemsInSection = nil;
    [oldItems asdk_diffWithArray:newItems insertions:&insertedItemsInSection deletions:&deletedItemsInSection];

    // Technically we could just lock around the -addObject call but this is simpler and
    // the performance difference would probably be a wash.
    ASDisplayNodeAssert(pthread_mutex_lock(&lock) == 0, @"Failed to acquire lock");
    [deletedItemsInSection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [mutableDeletedItems addObject:[NSIndexPath indexPathForItem:idx inSection:oldSectionIndex]];
    }];
    [insertedItemsInSection enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      [mutableInsertedItems addObject:[NSIndexPath indexPathForItem:idx inSection:newSectionIndex]];
    }];
    ASDisplayNodeAssert(pthread_mutex_unlock(&lock) == 0, @"Failed to release lock");
  }];
  ASDisplayNodeAssert(pthread_mutex_destroy(&lock) == 0, @"Failed to destroy lock.");
  *insertedItems = mutableInsertedItems;
  *deletedItems = mutableDeletedItems;
}

@end

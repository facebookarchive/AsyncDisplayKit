//
//  ASMultidimensionalArrayUtils.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASAssert.h"
#import "ASMultidimensionalArrayUtils.h"

// Import UIKit to get [NSIndexPath indexPathForItem:inSection:] which uses
// static memory addresses rather than allocating new index path objects.
#import <UIKit/UIKit.h>

#pragma mark - Internal Methods

static void ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray,
                                                                 const NSArray *indexPaths,
                                                                 NSUInteger &curIdx,
                                                                 NSIndexPath *curIndexPath,
                                                                 const NSUInteger dimension,
                                                                 void (^updateBlock)(NSMutableArray *arr, NSIndexSet *indexSet, NSUInteger idx))
{
  if (curIdx == indexPaths.count) {
    return;
  }

  if (curIndexPath.length < dimension - 1) {
    NSInteger i = 0;
    for (NSMutableArray *subarray in mutableArray) {
      ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(subarray, indexPaths, curIdx, [curIndexPath indexPathByAddingIndex:i], dimension, updateBlock);
      i += 1;
    }
  } else {
    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];

    while (curIdx < indexPaths.count &&
           [curIndexPath isEqual:[indexPaths[curIdx] indexPathByRemovingLastIndex]]) {
      [indexSet addIndex:[indexPaths[curIdx] indexAtPosition:curIndexPath.length]];
      curIdx++;
    }

    updateBlock(mutableArray, indexSet, curIdx);
  }
}

static void ASRecursivelyFindIndexPathsForMultidimensionalArray(NSObject *obj, NSIndexPath *curIndexPath, NSMutableArray <NSIndexPath *>*res)
{
  if (![obj isKindOfClass:[NSArray class]]) {
    [res addObject:curIndexPath];
  } else {
    NSArray *array = (NSArray *)obj;
    NSUInteger idx = 0;
    for (NSArray *subarray in array) {
      ASRecursivelyFindIndexPathsForMultidimensionalArray(subarray, [curIndexPath indexPathByAddingIndex:idx], res);
      idx++;
    }
  }
}

static BOOL ASElementExistsAtIndexPathForMultidimensionalArray(NSArray *array, NSIndexPath *indexPath) {
  NSUInteger indexLength = indexPath.length;
  ASDisplayNodeCAssert(indexLength != 0, @"Must have a non-zero indexPath length");
  NSUInteger firstIndex = [indexPath indexAtPosition:0];
  BOOL elementExists = firstIndex < array.count;

  if (indexLength == 1) {
    return elementExists;
  }

  if (!elementExists) {
    return NO;
  }

  NSUInteger indexesLength = indexLength - 1;
  NSUInteger indexes[indexesLength];
  [indexPath getIndexes:indexes range:NSMakeRange(1, indexesLength)];
  NSIndexPath *indexPathByRemovingFirstIndex;
  // Use -indexPathForItem:inSection: if possible because it does not allocate into the heap
  if (indexesLength == 2) {
    indexPathByRemovingFirstIndex = [NSIndexPath indexPathForItem:indexes[1] inSection:indexes[0]];
  } else {
    indexPathByRemovingFirstIndex = [NSIndexPath indexPathWithIndexes:indexes length:indexesLength];
  }

  return ASElementExistsAtIndexPathForMultidimensionalArray(array[firstIndex], indexPathByRemovingFirstIndex);
}

#pragma mark - Public Methods

NSObject<NSCopying> *ASMultidimensionalArrayDeepMutableCopy(NSObject<NSCopying> *obj)
{
  if ([obj isKindOfClass:[NSArray class]]) {
    NSArray *arr = (NSArray *)obj;
    NSMutableArray * mutableArr = [NSMutableArray arrayWithCapacity:arr.count];
    for (NSObject<NSCopying> *elem in arr) {
      [mutableArr addObject:ASMultidimensionalArrayDeepMutableCopy(elem)];
    }
    return mutableArr;
  }

  return obj;
}

NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array)
{
  NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
  for (NSArray *subarray in array) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    [newArray addObject:[subarray mutableCopy]];
  }
  return newArray;
}

void ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths, NSArray *elements)
{
  ASDisplayNodeCAssert(indexPaths.count == elements.count, @"Inconsistent indexPaths and elements");

  if (!indexPaths.count) {
    return;
  }

  NSUInteger curIdx = 0;
  NSIndexPath *indexPath = [[NSIndexPath alloc] init];
  ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(mutableArray, indexPaths, curIdx, indexPath, [indexPaths[0] length], ^(NSMutableArray *arr, NSIndexSet *indexSet, NSUInteger idx) {
    [arr insertObjects:[elements subarrayWithRange:NSMakeRange(idx - indexSet.count, indexSet.count)]
             atIndexes:indexSet];
  });

  ASDisplayNodeCAssert(curIdx == indexPaths.count, @"Indexpath is out of range !");
}

void ASDeleteElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths)
{
  if (!indexPaths.count) {
    return;
  }

  NSUInteger curIdx = 0;
  NSIndexPath *indexPath = [[NSIndexPath alloc] init];

  ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(mutableArray, indexPaths, curIdx, indexPath, [indexPaths[0] length], ^(NSMutableArray *arr, NSIndexSet *indexSet, NSUInteger idx) {
    [arr removeObjectsAtIndexes:indexSet];
  });

  ASDisplayNodeCAssert(curIdx == indexPaths.count, @"Indexpath is out of range !");
}

NSArray *ASFindElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths)
{
  NSUInteger curIdx = 0;
  NSIndexPath *indexPath = [[NSIndexPath alloc] init];
  NSMutableArray *deletedElements = [[NSMutableArray alloc] initWithCapacity:indexPaths.count];

  if (!indexPaths.count) {
    return deletedElements;
  }

  ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(mutableArray, indexPaths, curIdx, indexPath, [indexPaths[0] length], ^(NSMutableArray *arr, NSIndexSet *indexSet, NSUInteger idx) {
    [deletedElements addObjectsFromArray:[arr objectsAtIndexes:indexSet]];
  });

  ASDisplayNodeCAssert(curIdx == indexPaths.count, @"Indexpath is out of range !");

  return deletedElements;
}

NSArray *ASIndexPathsForMultidimensionalArrayAtIndexSet(NSArray *multidimensionalArray, NSIndexSet *indexSet)
{
  NSMutableArray *res = [NSMutableArray array];
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    ASRecursivelyFindIndexPathsForMultidimensionalArray(multidimensionalArray[idx], [NSIndexPath indexPathWithIndex:idx], res);
  }];

  return res;
}

NSArray<NSIndexPath *> *ASIndexPathsInMultidimensionalArrayIntersectingIndexPaths(NSArray *multidimensionalArray, NSArray<NSIndexPath *> *indexPaths)
{
  NSMutableArray *res = [NSMutableArray array];
  for (NSIndexPath *indexPath in indexPaths) {
    if (ASElementExistsAtIndexPathForMultidimensionalArray(multidimensionalArray, indexPath)) {
      [res addObject:indexPath];
    }
  }

  return res;
}

NSArray *ASIndexPathsForTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray)
{
  NSMutableArray *result = [NSMutableArray array];
  NSUInteger section = 0;
  for (NSArray *subarray in twoDimensionalArray) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    for (NSUInteger item = 0; item < subarray.count; item++) {
      [result addObject:[NSIndexPath indexPathForItem:item inSection:section]];
    }
    section++;
  }
  return result;
}
  
NSArray *ASIndexPathsForMultidimensionalArray(NSArray *multidimensionalArray)
{
  NSMutableArray *res = [NSMutableArray array];
  ASRecursivelyFindIndexPathsForMultidimensionalArray(multidimensionalArray, [[NSIndexPath alloc] init], res);
  return res;
}

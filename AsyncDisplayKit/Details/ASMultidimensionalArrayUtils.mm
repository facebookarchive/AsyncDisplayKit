/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASAssert.h"
#import "ASMultidimensionalArrayUtils.h"

#pragma mark - Internal Methods

static void ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray,
                                                                 const NSArray *indexPaths,
                                                                 NSUInteger &curIdx,
                                                                 NSIndexPath *curIndexPath,
                                                                 const NSUInteger dimension,
                                                                 void (^updateBlock)(NSMutableArray *arr, NSIndexSet *indexSet, NSUInteger idx)) {
  if (curIdx == indexPaths.count) {
    return;
  }

  if (curIndexPath.length < dimension - 1) {
    for (int i = 0; i < mutableArray.count; i++) {
      ASRecursivelyUpdateMultidimensionalArrayAtIndexPaths(mutableArray[i], indexPaths, curIdx, [curIndexPath indexPathByAddingIndex:i], dimension, updateBlock);
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

static void ASRecursivelyFindIndexPathsForMultidimensionalArray(NSObject *obj, NSIndexPath *curIndexPath, NSMutableArray *res) {
  if (![obj isKindOfClass:[NSArray class]]) {
    [res addObject:curIndexPath];
  } else {
    NSArray *arr = (NSArray *)obj;
    [arr enumerateObjectsUsingBlock:^(NSObject *subObj, NSUInteger idx, BOOL *stop) {
      ASRecursivelyFindIndexPathsForMultidimensionalArray(subObj, [curIndexPath indexPathByAddingIndex:idx], res);
    }];
  }
}

#pragma mark - Public Methods

NSObject<NSCopying> *ASMultidimensionalArrayDeepMutableCopy(NSObject<NSCopying> *obj) {
  if ([obj isKindOfClass:[NSArray class]]) {
    NSArray *arr = (NSArray *)obj;
    NSMutableArray * mutableArr = [NSMutableArray array];
    for (NSObject<NSCopying> *elem in arr) {
      [mutableArr addObject:ASMultidimensionalArrayDeepMutableCopy(elem)];
    }
    return mutableArr;
  }

  return obj;
}

void ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths, NSArray *elements) {
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

void ASDeleteElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths) {
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

NSArray *ASFindElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths) {
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

NSArray *ASIndexPathsForMultidimensionalArrayAtIndexSet(NSArray *multidimensionalArray, NSIndexSet *indexSet) {
  NSMutableArray *res = [[NSMutableArray alloc] initWithCapacity:multidimensionalArray.count];
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    ASRecursivelyFindIndexPathsForMultidimensionalArray(multidimensionalArray[idx], [NSIndexPath indexPathWithIndex:idx], res);
  }];

  return res;
}

NSArray *ASIndexPathsForMultidimensionalArray(NSArray *multidimensionalArray) {
  NSMutableArray *res = [NSMutableArray arrayWithCapacity:multidimensionalArray.count];
  ASRecursivelyFindIndexPathsForMultidimensionalArray(multidimensionalArray, [[NSIndexPath alloc] init], res);
  return res;
}


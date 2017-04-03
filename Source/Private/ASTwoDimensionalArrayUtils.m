//
//  ASTwoDimensionalArrayUtils.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>

// Import UIKit to get [NSIndexPath indexPathForItem:inSection:] which uses
// tagged pointers.
#import <UIKit/UIKit.h>

#pragma mark - Public Methods

NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array)
{
  NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
  NSInteger i = 0;
  for (NSArray *subarray in array) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    newArray[i++] = [subarray mutableCopy];
  }
  return newArray;
}

void ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths)
{
  if (indexPaths.count == 0) {
    return;
  }

#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  NSArray *sortedIndexPaths = [indexPaths sortedArrayUsingSelector:@selector(asdk_inverseCompare:)];
  ASDisplayNodeCAssert([sortedIndexPaths isEqualToArray:indexPaths], @"Expected array of index paths to be sorted in descending order.");
#endif

  /**
   * It is tempting to do something clever here and collect indexes into ranges or NSIndexSets
   * but deep down, __NSArrayM only implements removeObjectAtIndex: and so doing all that extra
   * work ends up running the same code.
   */
  for (NSIndexPath *indexPath in indexPaths) {
    NSInteger section = indexPath.section;
    if (section >= mutableArray.count) {
      ASDisplayNodeCFailAssert(@"Invalid section index %zd – only %zd sections", section, mutableArray.count);
      continue;
    }

    NSMutableArray *subarray = mutableArray[section];
    NSInteger item = indexPath.item;
    if (item >= subarray.count) {
      ASDisplayNodeCFailAssert(@"Invalid item index %zd – only %zd items in section %zd", item, subarray.count, section);
      continue;
    }
    [subarray removeObjectAtIndex:item];
  }
}

NSArray *ASIndexPathsForTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray)
{
  NSMutableArray *result = [NSMutableArray array];
  NSInteger section = 0;
  NSInteger i = 0;
  for (NSArray *subarray in twoDimensionalArray) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    NSInteger itemCount = subarray.count;
    for (NSInteger item = 0; item < itemCount; item++) {
      result[i++] = [NSIndexPath indexPathForItem:item inSection:section];
    }
    section++;
  }
  return result;
}

NSArray *ASElementsInTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray)
{
  NSMutableArray *result = [NSMutableArray array];
  NSInteger i = 0;
  for (NSArray *subarray in twoDimensionalArray) {
    ASDisplayNodeCAssert([subarray isKindOfClass:[NSArray class]], @"This function expects NSArray<NSArray *> *");
    for (id element in subarray) {
      result[i++] = element;
    }
  }
  return result;
}

id ASGetElementInTwoDimensionalArray(NSArray *array, NSIndexPath *indexPath)
{
  ASDisplayNodeCAssertNotNil(indexPath, @"Expected non-nil index path");
  ASDisplayNodeCAssert(indexPath.length == 2, @"Expected index path of length 2. Index path: %@", indexPath);
  NSInteger section = indexPath.section;
  if (array.count <= section) {
    return nil;
  }

  NSArray *innerArray = array[section];
  NSInteger item = indexPath.item;
  if (innerArray.count <= item) {
    return nil;
  }
  return innerArray[item];
}

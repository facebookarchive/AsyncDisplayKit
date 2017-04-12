//
//  ASTwoDimensionalArrayUtils.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASBaseDefines.h>


NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class for operation on two-dimensional array, where the objects of the root array are each arrays
 */

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * Deep mutable copy of an array that contains arrays, which contain objects.  It will go one level deep into the array to copy.
 * This method is substantially faster than the generalized version, e.g. about 10x faster, so use it whenever it fits the need.
 */
extern NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array) AS_WARN_UNUSED_RESULT;

/**
 * Delete the elements of the mutable two-dimensional array at given index paths – sorted in descending order!
 */
extern void ASDeleteElementsInTwoDimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray<NSIndexPath *> *indexPaths);

/**
 * Return all the index paths of a two-dimensional array, in ascending order.
 */
extern NSArray<NSIndexPath *> *ASIndexPathsForTwoDimensionalArray(NSArray<NSArray *>* twoDimensionalArray) AS_WARN_UNUSED_RESULT;

/**
 * Return all the elements of a two-dimensional array, in ascending order.
 */
extern NSArray *ASElementsInTwoDimensionalArray(NSArray<NSArray *>* twoDimensionalArray) AS_WARN_UNUSED_RESULT;

/**
 * Attempt to get the object at the given index path. Returns @c nil if the index path is out of bounds.
 */
extern id _Nullable ASGetElementInTwoDimensionalArray(NSArray<NSArray *> *array, NSIndexPath *indexPath) AS_WARN_UNUSED_RESULT;


ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END

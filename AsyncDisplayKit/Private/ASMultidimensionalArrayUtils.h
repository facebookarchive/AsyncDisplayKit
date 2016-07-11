//
//  ASMultidimensionalArrayUtils.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASBaseDefines.h>


/**
 * Helper class for operation on multidimensional array, where the object of array may be an object or an array.
 */

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * Deep mutable copy of an array that contains arrays, which contain objects.  It will go one level deep into the array to copy.
 * This method is substantially faster than the generalized version, e.g. about 10x faster, so use it whenever it fits the need.
 */
extern NSMutableArray<NSMutableArray *> *ASTwoDimensionalArrayDeepMutableCopy(NSArray<NSArray *> *array);

/**
 * Deep mutable copy of multidimensional array.  This is completely generalized and supports copying mixed-depth arrays,
 * where some subarrays might contain both elements and other subarrays. It will recursively do the multiple copy for each subarray.
 */
extern NSObject<NSCopying> *ASMultidimensionalArrayDeepMutableCopy(NSObject<NSCopying> *obj);

/**
 * Insert the elements into the mutable multidimensional array at given index paths.
 */
extern void ASInsertElementsIntoMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths, NSArray *elements);

/**
 * Delete the elements of the mutable multidimensional array at given index paths
 */
extern void ASDeleteElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths);

/**
 * Find the elements of the mutable multidimensional array at given index paths.
 */
extern NSArray *ASFindElementsInMultidimensionalArrayAtIndexPaths(NSMutableArray *mutableArray, NSArray *indexPaths);

/**
 * Return all the index paths of mutable multidimensional array at given index set, in ascending order.
 */
extern NSArray *ASIndexPathsForMultidimensionalArrayAtIndexSet(NSArray *multidimensionalArray, NSIndexSet *indexSet);

/**
 * Return the index paths of the given multidimensional array that are present in the given index paths array.
 */
extern NSArray<NSIndexPath *> *ASIndexPathsInMultidimensionalArrayIntersectingIndexPaths(NSArray *multidimensionalArray, NSArray<NSIndexPath *> *indexPaths);

/**
 * Return all the index paths of a two-dimensional array, in ascending order.
 */
extern NSArray *ASIndexPathsForTwoDimensionalArray(NSArray <NSArray *>* twoDimensionalArray);

/**
 * Return all the index paths of a multidimensional array, in ascending order.
 */
extern NSArray *ASIndexPathsForMultidimensionalArray(NSArray *MultidimensionalArray);


ASDISPLAYNODE_EXTERN_C_END

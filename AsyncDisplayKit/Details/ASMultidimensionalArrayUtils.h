//  Copyright 2004-present Facebook. All Rights Reserved.

#import <Foundation/Foundation.h>

#import "ASBaseDefines.h"

/**
 * Helper class for operation on multidimensional array, where the object of array may be an object or an array.
 */

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * Deep muutable copy of multidimensional array.
 * It will recursively do the multiple copy for each subarray.
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
extern NSArray *ASIndexPathsForMultidimensionalArrayAtIndexSet(NSArray *MultidimensionalArray, NSIndexSet *indexSet);

/**
 * Reteurn all the index paths of mutable multidimensional array, in ascending order.
 */
extern NSArray *ASIndexPathsForMultidimensionalArray(NSArray *MultidimensionalArray);


ASDISPLAYNODE_EXTERN_C_END

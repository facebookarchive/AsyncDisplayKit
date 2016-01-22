/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#ifndef ASCollectionViewLayoutFacilitatorProtocol_h
#define ASCollectionViewLayoutFacilitatorProtocol_h

/**
 * This facilitator protocol is intended to help Layout to better
 * gel with the CollectionView
 */
@protocol ASCollectionViewLayoutFacilitatorProtocol <NSObject>

/**
 * Inform that the collectionView is editing the cells at a list of indexPaths
 */
- (void)collectionViewEditingCellsAtIndexPaths:(NSArray *)indexPaths;

/**
 * Inform that the collectionView is editing the sections at a set of indexes
 */
- (void)collectionViewEditingSectionsAtIndexSet:(NSIndexSet *)indexes;

@end

#endif /* ASCollectionViewLayoutFacilitatorProtocol_h */

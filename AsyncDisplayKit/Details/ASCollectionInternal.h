//
//  ASCollectionInternal.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 1/1/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionView.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionViewLayoutFacilitatorProtocol;
@class ASCollectionNode;
@class ASDataController;
@class ASRangeController;

@interface ASCollectionView ()
- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator eventLog:(nullable ASEventLog *)eventLog;

@property (nonatomic, weak, readwrite) ASCollectionNode *collectionNode;
@property (nonatomic, strong, readonly) ASDataController *dataController;
@property (nonatomic, strong, readonly) ASRangeController *rangeController;

/**
 * Attempt to get the view-layer index path for the item with the given index path.
 *
 * @param indexPath The index path of the item.
 * @param wait If the item hasn't reached the view yet, this attempts to wait for updates to commit.
 */
- (nullable NSIndexPath *)convertIndexPathFromCollectionNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait;

/**
 * Attempt to get the node index path given the view-layer index path.
 *
 * @param indexPath The index path of the row.
 */
- (NSIndexPath *)convertIndexPathToCollectionNode:(NSIndexPath *)indexPath;

/**
 * Attempt to get the node index paths given the view-layer index paths.
 *
 * @param indexPaths An array of index paths in the view space
 */
- (nullable NSArray<NSIndexPath *> *)convertIndexPathsToCollectionNode:(nullable NSArray<NSIndexPath *> *)indexPaths;

// Called after running each node block, to update the
// hierarchy state and set the interaction delegate.
- (void)didCreateNode:(ASCellNode *)node;

/**
 * Prevent this collection view from making assertions about what methods its delegate/data source implement.
 *
 * This isn't pretty, but unfortunately OCMock always responds to all selectors, so
 * removing it will require pretty significant resources that aren't currently worth it.
 */
@property (nonatomic, assign) BOOL test_suppressCallbackImplementationAssertions;

@end

NS_ASSUME_NONNULL_END

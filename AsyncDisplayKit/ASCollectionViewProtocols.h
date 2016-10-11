//
//  ASCollectionViewProtocols.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

NS_ASSUME_NONNULL_BEGIN

/**
 * This is a subset of UICollectionViewDataSource.
 *
 * @see ASCollectionDataSource
 */
@protocol ASCommonCollectionDataSource <NSObject>

@required

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section ASDISPLAYNODE_DEPRECATED;

@optional

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView ASDISPLAYNODE_DEPRECATED;

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

@end


/**
 * This is a subset of UICollectionViewDelegate.
 *
 * @see ASCollectionDelegate
 */
@protocol ASCommonCollectionDelegate <NSObject, UIScrollViewDelegate>

@optional

- (UICollectionViewTransitionLayout *)collectionView:(UICollectionView *)collectionView transitionLayoutForOldLayout:(UICollectionViewLayout *)fromLayout newLayout:(UICollectionViewLayout *)toLayout;

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath ASDISPLAYNODE_DEPRECATED;
- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender ASDISPLAYNODE_DEPRECATED;
- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END

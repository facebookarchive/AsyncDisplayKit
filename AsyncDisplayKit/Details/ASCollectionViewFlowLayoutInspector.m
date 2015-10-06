/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import "ASCollectionViewFlowLayoutInspector.h"

#import "ASCollectionView.h"

@implementation ASCollectionViewFlowLayoutInspector {
  BOOL _delegateImplementsReferenceSizeForHeader;
  BOOL _delegateImplementsReferenceSizeForFooter;
}

#pragma mark - Accessors

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView flowLayout:(UICollectionViewFlowLayout *)flowLayout
{
    if (flowLayout == nil) {
        return nil;
    }

    self = [super init];
    if (self != nil) {
        self.collectionView = collectionView;
        _layout = flowLayout;
    }
    return self;
}

- (void)setCollectionView:(ASCollectionView *)collectionView
{
    _collectionView = collectionView;
    _delegateImplementsReferenceSizeForHeader = [[self layoutDelegate] respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)];
    _delegateImplementsReferenceSizeForFooter = [[self layoutDelegate] respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)];
}

#pragma mark - ASCollectionViewLayoutInspecting

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  CGSize constrainedSize;
  CGSize supplementarySize = [self sizeForSupplementaryViewOfKind:kind inSection:indexPath.section];
  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    constrainedSize = CGSizeMake(_collectionView.bounds.size.width, supplementarySize.height);
  } else {
    constrainedSize = CGSizeMake(supplementarySize.height, _collectionView.bounds.size.height);
  }
  return ASSizeRangeMake(CGSizeZero, constrainedSize);
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind
{
  if ([collectionView.asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
    return [collectionView.asyncDataSource numberOfSectionsInCollectionView:collectionView];
  } else {
    return 1;
  }
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  return [self layoutHasSupplementaryViewOfKind:kind inSection:section] ? 1 : 0;
}

#pragma mark - Private helpers

- (CGSize)sizeForSupplementaryViewOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
    if (_delegateImplementsReferenceSizeForHeader) {
      return [[self layoutDelegate] collectionView:_collectionView layout:_layout referenceSizeForHeaderInSection:section];
    } else {
      return [self.layout headerReferenceSize];
    }
  } else if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
    if (_delegateImplementsReferenceSizeForFooter) {
      return [[self layoutDelegate] collectionView:_collectionView layout:_layout referenceSizeForFooterInSection:section];
    } else {
      return [self.layout footerReferenceSize];
    }
  } else {
    return CGSizeZero;
  }
}

- (BOOL)layoutHasSupplementaryViewOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  CGSize size = [self sizeForSupplementaryViewOfKind:kind inSection:section];
  if ([self usedLayoutValueForSize:size] > 0) {
    return YES;
  } else {
    return NO;
  }
}

- (CGFloat)usedLayoutValueForSize:(CGSize)size
{
  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    return size.height;
  } else {
    return size.width;
  }
}

- (id<ASCollectionViewDelegateFlowLayout>)layoutDelegate
{
  return (id<ASCollectionViewDelegateFlowLayout>)_collectionView.asyncDelegate;
}

@end

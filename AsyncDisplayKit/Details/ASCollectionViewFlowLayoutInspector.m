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
#import "ASAssert.h"

@implementation ASCollectionViewFlowLayoutInspector {
  BOOL _delegateImplementsReferenceSizeForHeader;
  BOOL _delegateImplementsReferenceSizeForFooter;
}

#pragma mark - Accessors

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView flowLayout:(UICollectionViewFlowLayout *)flowLayout;
{
  self = [super init];

  if (flowLayout == nil) {
    ASDisplayNodeAssert(NO, @"Should never create a layout inspector without a layout");
  }

  if (self != nil) {
    [self cacheSelectorsForCollectionView:collectionView];
    _layout = flowLayout;
  }
  return self;
}

- (void)cacheSelectorsForCollectionView:(ASCollectionView *)collectionView
{
  if (collectionView == nil) {
    _delegateImplementsReferenceSizeForHeader = nil;
    _delegateImplementsReferenceSizeForFooter = nil;
  } else {
    _delegateImplementsReferenceSizeForHeader = [[self delegateForCollectionView:collectionView] respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)];
    _delegateImplementsReferenceSizeForFooter = [[self delegateForCollectionView:collectionView] respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)];
  }
}

#pragma mark - ASCollectionViewLayoutInspecting

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  CGSize constrainedSize;
  CGSize supplementarySize = [self sizeForSupplementaryViewOfKind:kind inSection:indexPath.section collectionView:collectionView];
  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    constrainedSize = CGSizeMake(collectionView.bounds.size.width, supplementarySize.height);
  } else {
    constrainedSize = CGSizeMake(supplementarySize.height, collectionView.bounds.size.height);
  }
  return ASSizeRangeMake(CGSizeZero, constrainedSize);
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryNodeOfKind:(NSString *)kind
{
  if ([collectionView.asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
    return [collectionView.asyncDataSource numberOfSectionsInCollectionView:collectionView];
  } else {
    return 1;
  }
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  return [self layoutHasSupplementaryViewOfKind:kind inSection:section collectionView:collectionView] ? 1 : 0;
}

#pragma mark - Private helpers

- (CGSize)sizeForSupplementaryViewOfKind:(NSString *)kind inSection:(NSUInteger)section collectionView:(ASCollectionView *)collectionView
{
  if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
    if (_delegateImplementsReferenceSizeForHeader) {
      return [[self delegateForCollectionView:collectionView] collectionView:collectionView layout:_layout referenceSizeForHeaderInSection:section];
    } else {
      return [self.layout headerReferenceSize];
    }
  } else if ([kind isEqualToString:UICollectionElementKindSectionFooter]) {
    if (_delegateImplementsReferenceSizeForFooter) {
      return [[self delegateForCollectionView:collectionView] collectionView:collectionView layout:_layout referenceSizeForFooterInSection:section];
    } else {
      return [self.layout footerReferenceSize];
    }
  } else {
    return CGSizeZero;
  }
}

- (BOOL)layoutHasSupplementaryViewOfKind:(NSString *)kind inSection:(NSUInteger)section collectionView:(ASCollectionView *)collectionView
{
  CGSize size = [self sizeForSupplementaryViewOfKind:kind inSection:section collectionView:collectionView];
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

- (id<ASCollectionViewDelegateFlowLayout>)delegateForCollectionView:(ASCollectionView *)collectionView
{
  return (id<ASCollectionViewDelegateFlowLayout>)collectionView.asyncDelegate;
}

@end

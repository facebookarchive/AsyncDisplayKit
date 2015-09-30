//
//  ASCollectionViewFlowLayoutInspector.m
//  Pods
//
//  Created by Levi McCallum on 9/29/15.
//
//

#import <UIKit/UIKit.h>

#import "ASCollectionViewFlowLayoutInspector.h"

#import "ASCollectionView.h"

@implementation ASCollectionViewFlowLayoutInspector {
  BOOL _delegateImplementsReferenceSizeForHeader;
  BOOL _delegateImplementsReferenceSizeForFooter;
}

#pragma mark - Accessors

- (void)setLayout:(UICollectionViewFlowLayout *)layout
{
  _layout = layout;
  _delegateImplementsReferenceSizeForHeader = [[self layoutDelegate] respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)];
  _delegateImplementsReferenceSizeForFooter = [[self layoutDelegate] respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)];
}

#pragma mark - ASCollectionViewLayoutInspecting

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  CGSize constrainedSize = CGSizeMake(FLT_MAX, FLT_MAX);
  CGSize supplementarySize = [self sizeForSupplementaryViewOfKind:kind inSection:indexPath.section];
  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    constrainedSize.height = supplementarySize.height;
  } else {
    constrainedSize.width = supplementarySize.width;
  }
  return ASSizeRangeMake(CGSizeZero, constrainedSize);
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind
{
  return [collectionView.asyncDataSource numberOfSectionsInCollectionView:collectionView];
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

- (id<UICollectionViewDelegateFlowLayout>)layoutDelegate
{
  return (id<UICollectionViewDelegateFlowLayout>)self.collectionView.delegate;
}

@end

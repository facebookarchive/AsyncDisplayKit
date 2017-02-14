//
//  ASPagerFlowLayout.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/12/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASPagerFlowLayout.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionView.h>

@interface ASPagerFlowLayout () {
  __weak ASCellNode *_currentCellNode;
}

@end

@implementation ASPagerFlowLayout

- (ASCollectionView *)asCollectionView
{
  // Dynamic cast is too slow and not worth it.
  return (ASCollectionView *)self.collectionView;
}

- (void)prepareLayout
{
  [super prepareLayout];
  if (_currentCellNode == nil) {
    [self _updateCurrentNode];
  }
}

- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems
{
  [super prepareForCollectionViewUpdates:updateItems];
  if (!self.collectionView.decelerating && !self.collectionView.tracking) {
    [self _updateCurrentNode];
  }
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
  // Don't mess around if the user is interacting with the page node. Although if just a rotation happened we should
  // try to use the current index path to not end up setting the target content offset to something in between pages
  if (!self.collectionView.decelerating && !self.collectionView.tracking) {
    NSIndexPath *indexPath = [self.asCollectionView indexPathForNode:_currentCellNode];
    if (indexPath) {
      return [self _targetContentOffsetForItemAtIndexPath:indexPath proposedContentOffset:proposedContentOffset];
    }
  }

  return [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
}

- (CGPoint)_targetContentOffsetForItemAtIndexPath:(NSIndexPath *)indexPath proposedContentOffset:(CGPoint)proposedContentOffset
{
  if ([self _dataSourceIsEmpty]) {
    return proposedContentOffset;
  }
  
  UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
  if (attributes == nil) {
    return proposedContentOffset;
  }

  CGFloat xOffset = (CGRectGetWidth(self.collectionView.bounds) - CGRectGetWidth(attributes.frame)) / 2.0;
  return CGPointMake(attributes.frame.origin.x - xOffset, proposedContentOffset.y);
}

- (BOOL)_dataSourceIsEmpty
{
  return ([self.collectionView numberOfSections] == 0 ||
          [self.collectionView numberOfItemsInSection:0] == 0);
}

- (void)_updateCurrentNode
{
  UICollectionView *collectionView = self.collectionView;
  CGRect bounds = collectionView.bounds;
  CGRect rect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);

  NSIndexPath *indexPath = [self layoutAttributesForElementsInRect:rect].firstObject.indexPath;
  if (indexPath) {
    ASCellNode *node = [self.asCollectionView nodeForItemAtIndexPath:indexPath];
    if (node) {
      _currentCellNode = node;
    }
  }
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{/*
  BOOL sizeChanged = !CGSizeEqualToSize(newBounds.size, self.collectionView.bounds.size);
  if (!sizeChanged) {
    return NO;
  }
  BOOL anim = ([self.collectionView.layer animationForKey:@"bounds.size"] != nil);
  if (!anim) {
    return NO;
  }
  if (!anim && !sizeChanged) {*/
    [self _updateCurrentNode];
  //}
  return NO;
}

@end

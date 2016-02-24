//
//  ASPagerFlowLayout.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASPagerFlowLayout.h"

@interface ASPagerFlowLayout ()

@property (strong, nonatomic) NSIndexPath *currentIndexPath;

@end

@implementation ASPagerFlowLayout

- (void)invalidateLayout
{
  self.currentIndexPath = [self _indexPathForVisiblyCenteredItem];
  [super invalidateLayout];
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
  if (self.currentIndexPath) {
    return [self _targetContentOffsetForItemAtIndexPath:self.currentIndexPath
                                  proposedContentOffset:proposedContentOffset];
  }
  
  return [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
}

- (CGPoint)_targetContentOffsetForItemAtIndexPath:(NSIndexPath *)indexPath proposedContentOffset:(CGPoint)proposedContentOffset
{
  UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:self.currentIndexPath];
  CGFloat xOffset = (self.collectionView.bounds.size.width - attributes.frame.size.width) / 2;
  return CGPointMake(attributes.frame.origin.x - xOffset, proposedContentOffset.y);
}

- (NSIndexPath *)_indexPathForVisiblyCenteredItem
{
  CGRect visibleRect = [self _visibleRect];
  CGFloat visibleXCenter = CGRectGetMidX(visibleRect);
  NSArray<UICollectionViewLayoutAttributes *> *layoutAttributes = [self layoutAttributesForElementsInRect:visibleRect];
  for (UICollectionViewLayoutAttributes *attributes in layoutAttributes) {
    if ([attributes representedElementCategory] == UICollectionElementCategoryCell && attributes.center.x == visibleXCenter) {
      return attributes.indexPath;
    }
  }
  return nil;
}

- (CGRect)_visibleRect
{
  CGRect visibleRect;
  visibleRect.origin = self.collectionView.contentOffset;
  visibleRect.size = self.collectionView.bounds.size;
  return visibleRect;
}

@end
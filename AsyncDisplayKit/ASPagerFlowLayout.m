//
//  ASPagerFlowLayout.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASPagerFlowLayout.h"
#import "ASPagerNode.h"

@interface ASPagerFlowLayout ()

@property (strong, nonatomic) NSIndexPath *currentIndexPath;
@property (weak, nonatomic) id<ASPagerFlowLayoutPageProvider> pageProvider;

@end

@implementation ASPagerFlowLayout

#pragma mark - Lifecycle

- (instancetype)initWithPageProvider:(id<ASPagerFlowLayoutPageProvider>)pageProvider
{
  self = [super init];
  if (self == nil) { return self; }
  _pageProvider = pageProvider;
  return self;
}

#pragma mark - UICollectionViewFlowLayout

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
  CGRect oldBounds = self.collectionView.bounds;
  if (!CGSizeEqualToSize(oldBounds.size, newBounds.size)) {
    return YES;
  }
    
  return NO;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset
{
  if ([self _dataSourceIsEmpty]) {
    return proposedContentOffset;
  }
  
  if (_pageProvider == nil || [self _visibleRectIsInvalid]) {
    return [super targetContentOffsetForProposedContentOffset:proposedContentOffset];
  }

  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:_pageProvider.currentPageIndex inSection:0];
  UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
  CGFloat xOffset = (CGRectGetWidth(self.collectionView.bounds) - CGRectGetWidth(attributes.frame)) / 2;
  return CGPointMake(attributes.frame.origin.x - xOffset, proposedContentOffset.y);
}

#pragma mark - Helper

- (BOOL)_dataSourceIsEmpty
{
  return ([self.collectionView numberOfSections] == 0 || [self.collectionView numberOfItemsInSection:0] == 0);
}

- (CGRect)_visibleRect
{
  CGRect visibleRect;
  visibleRect.origin = self.collectionView.contentOffset;
  visibleRect.size = self.collectionView.bounds.size;
  return visibleRect;
}

- (BOOL)_visibleRectIsInvalid
{
  return CGRectEqualToRect([self _visibleRect], CGRectZero);
}

@end

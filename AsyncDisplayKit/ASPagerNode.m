//
//  ASPagerNode.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASPagerNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASPagerNode () <ASCollectionViewDataSource, ASCollectionViewDelegateFlowLayout> {
  UICollectionViewFlowLayout *_flowLayout;
}

@end

@implementation ASPagerNode

- (instancetype)init
{
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  self = [super initWithCollectionViewLayout:flowLayout];
  if (self != nil) {
    _flowLayout = flowLayout;
  }
  return self;
}

- (void)didLoad
{
  [super didLoad];
  
  self.view.asyncDataSource = self;
  self.view.asyncDelegate = self;
  
  self.view.pagingEnabled = YES;
  self.view.allowsSelection = NO;
  self.view.showsVerticalScrollIndicator = NO;
  self.view.showsHorizontalScrollIndicator = NO;
  
  ASRangeTuningParameters preloadParams = { .leadingBufferScreenfuls = 2.0, .trailingBufferScreenfuls = 2.0 };
  ASRangeTuningParameters renderParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  [self setTuningParameters:preloadParams forRangeType:ASLayoutRangeTypePreload];
  [self setTuningParameters:renderParams forRangeType:ASLayoutRangeTypeRender];
}

#pragma mark - Helpers

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
  [self.view scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:animated];
}

#pragma mark - ASCollectionViewDataSource

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(self.dataSource != nil, @"ASPagerNode must have a data source to load paging nodes");
  return [self.dataSource pagerNode:self nodeAtIndex:indexPath.item];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(self.dataSource != nil, @"ASPagerNode must have a data source to load paging nodes");
  return [self.dataSource numberOfPagesInPagerNode:self];
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake(CGSizeZero, self.view.bounds.size);
}

@end

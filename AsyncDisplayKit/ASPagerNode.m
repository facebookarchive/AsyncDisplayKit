//
//  ASPagerNode.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASPagerNode.h"
#import "ASDelegateProxy.h"
#import "ASDisplayNode+Subclasses.h"

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionViewDelegateFlowLayout, ASDelegateProxyInterceptor> {
  UICollectionViewFlowLayout *_flowLayout;
  ASPagerNodeProxy *_proxy;
  id <ASPagerNodeDataSource> _pagerDataSource;
}

@end

@implementation ASPagerNode
@dynamic delegate;

- (instancetype)init
{
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  return [self initWithFlowLayout:flowLayout];
}

- (instancetype)initWithFlowLayout:(UICollectionViewFlowLayout *)flowLayout
{
  self = [super initWithCollectionViewLayout:flowLayout];
  if (self != nil) {
    _flowLayout = flowLayout;
  }
  return self;
}

- (ASCollectionView *)collectionView
{
  return self.view;
}

- (void)setDataSource:(id <ASPagerNodeDataSource>)pagerDataSource
{
  if (pagerDataSource != _pagerDataSource) {
    _pagerDataSource = pagerDataSource;
    _proxy = pagerDataSource ? [[ASPagerNodeProxy alloc] initWithTarget:pagerDataSource interceptor:self] : nil;
    super.dataSource = (id <ASCollectionDataSource>)_proxy;
  }
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  [self setDataSource:nil];
}

- (id <ASPagerNodeDataSource>)dataSource
{
  return _pagerDataSource;
}

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *cv = self.view;
  cv.asyncDataSource = self;
  cv.asyncDelegate = self;
  
  cv.pagingEnabled = YES;
  cv.allowsSelection = NO;
  cv.showsVerticalScrollIndicator = NO;
  cv.showsHorizontalScrollIndicator = NO;
  cv.scrollsToTop = NO;
  
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
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load paging nodes");
  return [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load paging nodes");
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake(CGSizeZero, self.view.bounds.size);
}

@end

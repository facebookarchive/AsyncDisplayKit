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
#import "UICollectionViewLayout+ASConvenience.h"

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionViewDelegateFlowLayout, ASDelegateProxyInterceptor>
{
  UICollectionViewFlowLayout *_flowLayout;
  ASPagerNodeProxy *_proxy;
  __weak id <ASPagerNodeDataSource> _pagerDataSource;
}

@end

@implementation ASPagerNode
@dynamic view, delegate, dataSource;

- (instancetype)init
{
  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  return [self initWithCollectionViewLayout:flowLayout];
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewFlowLayout *)flowLayout;
{
  ASDisplayNodeAssert([flowLayout asdk_isFlowLayout], @"ASPagerNode requires a flow layout.");
  self = [super initWithCollectionViewLayout:flowLayout];
  if (self != nil) {
    _flowLayout = flowLayout;
  }
  return self;
}

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *cv = self.view;
#if TARGET_OS_IOS
  cv.pagingEnabled = YES;
  cv.scrollsToTop = NO;
#endif
  cv.allowsSelection = NO;
  cv.showsVerticalScrollIndicator = NO;
  cv.showsHorizontalScrollIndicator = NO;
  
  // Zeroing contentInset is important, as UIKit will set the top inset for the navigation bar even though
  // our view is only horizontally scrollable.  This causes UICollectionViewFlowLayout to log a warning.
  // From here we cannot disable this directly (UIViewController's automaticallyAdjustsScrollViewInsets).
  cv.zeroContentInsets = YES;
  
  ASRangeTuningParameters preloadParams = { .leadingBufferScreenfuls = 2.0, .trailingBufferScreenfuls = 2.0 };
  ASRangeTuningParameters renderParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  [self setTuningParameters:preloadParams forRangeType:ASLayoutRangeTypeFetchData];
  [self setTuningParameters:renderParams forRangeType:ASLayoutRangeTypeDisplay];
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
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  ASCellNode *pageNode = [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
  return pageNode;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake(CGSizeZero, self.view.bounds.size);
}

#pragma mark - Data Source Proxy

- (id <ASPagerNodeDataSource>)dataSource
{
  return _pagerDataSource;
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

@end

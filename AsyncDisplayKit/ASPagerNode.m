//
//  ASPagerNode.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASPagerNode.h"
#import "ASDelegateProxy.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASPagerFlowLayout.h"
#import "ASCollectionView+Undeprecated.h"

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionDelegate, ASCollectionViewDelegateFlowLayout, ASDelegateProxyInterceptor>
{
  ASPagerFlowLayout *_flowLayout;

  __weak id <ASPagerDataSource> _pagerDataSource;
  ASPagerNodeProxy *_proxyDataSource;
  BOOL _pagerDataSourceImplementsNodeBlockAtIndex;

  __weak id <ASPagerDelegate> _pagerDelegate;
  ASPagerNodeProxy *_proxyDelegate;
  BOOL _pagerDelegateImplementsConstrainedSizeForNode;
}

@end

@implementation ASPagerNode

@dynamic view, delegate, dataSource;

#pragma mark - Lifecycle

- (instancetype)init
{
  ASPagerFlowLayout *flowLayout = [[ASPagerFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  return [self initWithCollectionViewLayout:flowLayout];
}

- (instancetype)initWithCollectionViewLayout:(ASPagerFlowLayout *)flowLayout;
{
  ASDisplayNodeAssert([flowLayout isKindOfClass:[ASPagerFlowLayout class]], @"ASPagerNode requires a flow layout.");
  self = [super initWithCollectionViewLayout:flowLayout];
  if (self != nil) {
    _flowLayout = flowLayout;
  }
  return self;
}

#pragma mark - ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *cv = self.view;
  cv.asyncDataSource = (id<ASCollectionDataSource>)_proxyDataSource ?: self;
  cv.asyncDelegate = (id<ASCollectionDelegate>)_proxyDelegate ?: self;
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

  ASRangeTuningParameters minimumRenderParams = { .leadingBufferScreenfuls = 0.0, .trailingBufferScreenfuls = 0.0 };
  ASRangeTuningParameters minimumPreloadParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  [self setTuningParameters:minimumRenderParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:minimumPreloadParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypePreload];
  
  ASRangeTuningParameters fullRenderParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  ASRangeTuningParameters fullPreloadParams = { .leadingBufferScreenfuls = 2.0, .trailingBufferScreenfuls = 2.0 };
  [self setTuningParameters:fullRenderParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:fullPreloadParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypePreload];
}

#pragma mark - Getters / Setters

- (NSInteger)currentPageIndex
{
  return (self.view.contentOffset.x / CGRectGetWidth(self.view.bounds));
}

#pragma mark - Helpers

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
  [self.view scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:animated];
}

- (ASCellNode *)nodeForPageAtIndex:(NSInteger)index
{
  return [self.view nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
}

#pragma mark - ASCollectionDataSource

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  if (!_pagerDataSourceImplementsNodeBlockAtIndex) {
    ASCellNode *node = [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
    return ^{ return node; };
  }
  return [_pagerDataSource pagerNode:self nodeBlockAtIndex:indexPath.item];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  if (_pagerDelegateImplementsConstrainedSizeForNode) {
    return [_pagerDelegate pagerNode:self constrainedSizeForNodeAtIndex:indexPath.item];
  }

  return ASSizeRangeMake(CGSizeZero, self.view.bounds.size);
}

#pragma mark - Data Source Proxy

- (id <ASPagerDataSource>)dataSource
{
  return _pagerDataSource;
}

- (void)setDataSource:(id <ASPagerDataSource>)dataSource
{
  if (dataSource != _pagerDataSource) {
    _pagerDataSource = dataSource;
    
    _pagerDataSourceImplementsNodeBlockAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeBlockAtIndex:)];
    // Data source must implement pagerNode:nodeBlockAtIndex: or pagerNode:nodeAtIndex:
    ASDisplayNodeAssertTrue(_pagerDataSourceImplementsNodeBlockAtIndex || [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeAtIndex:)]);
    
    _proxyDataSource = dataSource ? [[ASPagerNodeProxy alloc] initWithTarget:dataSource interceptor:self] : nil;
    
    super.dataSource = (id <ASCollectionDataSource>)_proxyDataSource;
  }
}

- (void)setDelegate:(id<ASPagerDelegate>)delegate
{
  if (delegate != _pagerDelegate) {
    _pagerDelegate = delegate;
    
    _pagerDelegateImplementsConstrainedSizeForNode = [_pagerDelegate respondsToSelector:@selector(pagerNode:constrainedSizeForNodeAtIndex:)];
    
    _proxyDelegate = delegate ? [[ASPagerNodeProxy alloc] initWithTarget:delegate interceptor:self] : nil;
    
    super.delegate = (id <ASCollectionDelegate>)_proxyDelegate;
  }
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  [self setDataSource:nil];
  [self setDelegate:nil];
}

@end

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
#import "ASPagerFlowLayout.h"
#import "UICollectionViewLayout+ASConvenience.h"

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionViewDelegateFlowLayout, ASDelegateProxyInterceptor, ASPagerFlowLayoutPageProvider>
{
  ASPagerFlowLayout *_flowLayout;
  ASPagerNodeProxy *_dataSourceProxy;
  ASPagerNodeProxy *_delegateProxy;
  __weak id <ASPagerNodeDataSource> _pagerDataSource;
  BOOL _pagerDataSourceImplementsNodeBlockAtIndex;
  BOOL _pagerDataSourceImplementsConstrainedSizeForNode;
}

@property (nonatomic, assign, readonly) NSInteger numberOfPages;

@end

@implementation ASPagerNode
@dynamic view, delegate, dataSource;

- (instancetype)init
{
  ASPagerFlowLayout *flowLayout = [[ASPagerFlowLayout alloc] initWithPageProvider:self];
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
    _currentPageIndex = 0;
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
  
  // Set the super delegate to the pager for now to inject the scroll delegate calls. If the API consumer
  // set's the delegate on the ASPagerNode we add an ASPagerNodeProxy in between in setDelegate:
  super.delegate = self;

  ASRangeTuningParameters minimumRenderParams = { .leadingBufferScreenfuls = 0.0, .trailingBufferScreenfuls = 0.0 };
  ASRangeTuningParameters minimumPreloadParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  [self setTuningParameters:minimumRenderParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:minimumPreloadParams forRangeMode:ASLayoutRangeModeMinimum rangeType:ASLayoutRangeTypeFetchData];
  
  ASRangeTuningParameters fullRenderParams = { .leadingBufferScreenfuls = 1.0, .trailingBufferScreenfuls = 1.0 };
  ASRangeTuningParameters fullPreloadParams = { .leadingBufferScreenfuls = 2.0, .trailingBufferScreenfuls = 2.0 };
  [self setTuningParameters:fullRenderParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeDisplay];
  [self setTuningParameters:fullPreloadParams forRangeMode:ASLayoutRangeModeFull rangeType:ASLayoutRangeTypeFetchData];
}

#pragma mark - Getter / Setter

- (NSInteger)numberOfPages
{
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

#pragma mark - Helpers

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated
{
  // Prevent an exception to scroll to an index path that is invalid
  if (index >= 0 && index < self.numberOfPages) {
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
    [self.view scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:animated];
  
    _currentPageIndex = index;
  }
}

#pragma mark - ASCollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  return self.numberOfPages;
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  if (!_pagerDataSourceImplementsNodeBlockAtIndex) {
    ASCellNode *node = [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
    return ^{ return node; };
  }
  return [_pagerDataSource pagerNode:self nodeBlockAtIndex:indexPath.item];
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  if (_pagerDataSourceImplementsConstrainedSizeForNode) {
    return [_pagerDataSource pagerNode:self constrainedSizeForNodeAtIndexPath:indexPath];
  }
  return ASSizeRangeMake(CGSizeZero, self.view.bounds.size);
}

#pragma mark - Proxies

- (id <ASPagerDataSource>)dataSource
{
  return _pagerDataSource;
}

- (void)setDataSource:(id <ASPagerDataSource>)pagerDataSource
{
  if (pagerDataSource != _pagerDataSource) {
    _pagerDataSource = pagerDataSource;
    
    _pagerDataSourceImplementsNodeBlockAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeBlockAtIndex:)];
    _pagerDataSourceImplementsConstrainedSizeForNode = [_pagerDataSource respondsToSelector:@selector(pagerNode:constrainedSizeForNodeAtIndexPath:)];
    
    // Data source must implement pagerNode:nodeBlockAtIndex: or pagerNode:nodeAtIndex:
    ASDisplayNodeAssertTrue(_pagerDataSourceImplementsNodeBlockAtIndex || [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeAtIndex:)]);
    
    _dataSourceProxy = pagerDataSource ? [[ASPagerNodeProxy alloc] initWithTarget:pagerDataSource interceptor:self] : nil;
    
    super.dataSource = (id <ASCollectionDataSource>)_dataSourceProxy;
  }
}

- (void)setDelegate:(id<ASCollectionDelegate>)delegate
{
  _delegateProxy = delegate ? [[ASPagerNodeProxy alloc] initWithTarget:delegate interceptor:self] : nil;
  
  super.delegate = (id <ASCollectionDelegate>)_delegateProxy;
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  [self setDataSource:nil];
  [self setDelegate:nil];
}

#pragma mark - <ASCollectionDelegate>

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  CGFloat pageWidth = CGRectGetWidth(self.view.frame);
  _currentPageIndex = floor((self.view.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
}

- (void)scrollViewWillEndDragging:(UIScrollView*)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint*)targetContentOffset
{
  CGFloat pageWidth = CGRectGetWidth(self.view.frame);
  NSInteger newPageIndex = _currentPageIndex;

  if (velocity.x == 0) {
    // Handle slow dragging not lifting finger
    newPageIndex = floor((targetContentOffset->x - pageWidth / 2) / pageWidth) + 1;
  } else {
    newPageIndex = velocity.x > 0 ? _currentPageIndex + 1 : _currentPageIndex - 1;

    if (newPageIndex < 0) {
        newPageIndex = 0;
    }
    if (newPageIndex > self.view.contentSize.width / pageWidth) {
        newPageIndex = ceil(self.view.contentSize.width / pageWidth) - 1.0;
    }
  }
  _currentPageIndex = newPageIndex;

  *targetContentOffset = CGPointMake(newPageIndex * pageWidth, targetContentOffset->y);
}

@end

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

#import <AsyncDisplayKit/ASPagerNode.h>
#import <AsyncDisplayKit/ASDelegateProxy.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASPagerFlowLayout.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>
#import <AsyncDisplayKit/UIResponder+AsyncDisplayKit.h>

@interface ASPagerNode () <ASCollectionDataSource, ASCollectionDelegate, ASCollectionDelegateFlowLayout, ASDelegateProxyInterceptor>
{
  ASPagerFlowLayout *_flowLayout;

  __weak id <ASPagerDataSource> _pagerDataSource;
  ASPagerNodeProxy *_proxyDataSource;
  struct {
    unsigned nodeBlockAtIndex:1;
    unsigned nodeAtIndex:1;
  } _pagerDataSourceFlags;

  __weak id <ASPagerDelegate> _pagerDelegate;
  struct {
    unsigned constrainedSizeForNode:1;
  } _pagerDelegateFlags;
  ASPagerNodeProxy *_proxyDelegate;
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
  [self scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionLeft animated:animated];
}

- (ASCellNode *)nodeForPageAtIndex:(NSInteger)index
{
  return [self nodeForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
}

- (NSInteger)indexOfPageWithNode:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (!indexPath) {
    return NSNotFound;
  }
  return indexPath.row;
}

#pragma mark - ASCollectionDataSource

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (_pagerDataSourceFlags.nodeBlockAtIndex) {
    return [_pagerDataSource pagerNode:self nodeBlockAtIndex:indexPath.item];
  } else if (_pagerDataSourceFlags.nodeAtIndex) {
    ASCellNode *node = [_pagerDataSource pagerNode:self nodeAtIndex:indexPath.item];
    return ^{ return node; };
  } else {
    ASDisplayNodeFailAssert(@"Pager data source must implement either %@ or %@. Data source: %@", NSStringFromSelector(@selector(pagerNode:nodeBlockAtIndex:)), NSStringFromSelector(@selector(pagerNode:nodeAtIndex:)), _pagerDataSource);
    return ^{
      return [[ASCellNode alloc] init];
    };
  }
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  ASDisplayNodeAssert(_pagerDataSource != nil, @"ASPagerNode must have a data source to load nodes to display");
  return [_pagerDataSource numberOfPagesInPagerNode:self];
}

#pragma mark - ASCollectionDelegate

- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (_pagerDelegateFlags.constrainedSizeForNode) {
    return [_pagerDelegate pagerNode:self constrainedSizeForNodeAtIndex:indexPath.item];
  }
#pragma clang diagnostic pop

  return ASSizeRangeMake(self.bounds.size);
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
    
    if (dataSource == nil) {
      memset(&_pagerDataSourceFlags, 0, sizeof(_pagerDataSourceFlags));
    } else {
      _pagerDataSourceFlags.nodeBlockAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeBlockAtIndex:)];
      _pagerDataSourceFlags.nodeAtIndex = [_pagerDataSource respondsToSelector:@selector(pagerNode:nodeAtIndex:)];
    }
    
    _proxyDataSource = dataSource ? [[ASPagerNodeProxy alloc] initWithTarget:dataSource interceptor:self] : nil;
    
    super.dataSource = (id <ASCollectionDataSource>)_proxyDataSource;
  }
}

- (void)setDelegate:(id<ASPagerDelegate>)delegate
{
  if (delegate != _pagerDelegate) {
    _pagerDelegate = delegate;
    
    if (delegate == nil) {
      memset(&_pagerDelegateFlags, 0, sizeof(_pagerDelegateFlags));
    } else {
    	_pagerDelegateFlags.constrainedSizeForNode = [_pagerDelegate respondsToSelector:@selector(pagerNode:constrainedSizeForNodeAtIndex:)];
    }
    
    _proxyDelegate = delegate ? [[ASPagerNodeProxy alloc] initWithTarget:delegate interceptor:self] : nil;
    
    super.delegate = (id <ASCollectionDelegate>)_proxyDelegate;
  }
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  [self setDataSource:nil];
  [self setDelegate:nil];
}

- (void)didEnterVisibleState
{
	[super didEnterVisibleState];

	// Check that our view controller does not automatically set our content insets
	// It would be better to have a -didEnterHierarchy hook to put this in, but
	// such a hook doesn't currently exist, and in every use case I can imagine,
	// the pager is not hosted inside a range-managed node.
	if (_allowsAutomaticInsetsAdjustment == NO) {
		UIViewController *vc = [self.view asdk_associatedViewController];
		if (vc.automaticallyAdjustsScrollViewInsets) {
			NSLog(@"AsyncDisplayKit: ASPagerNode is setting automaticallyAdjustsScrollViewInsets=NO on its owning view controller %@. This automatic behavior will be disabled in the future. Set allowsAutomaticInsetsAdjustment=YES on the pager node to suppress this behavior.", vc);
			vc.automaticallyAdjustsScrollViewInsets = NO;
		}
	}
}

@end

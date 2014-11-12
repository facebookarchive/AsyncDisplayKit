/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionView.h"

#import "ASAssert.h"
#import "ASRangeController.h"


#pragma mark -
#pragma mark Proxying.

/**
 * ASCollectionView intercepts and/or overrides a few of UICollectionView's critical data source and delegate methods.
 *
 * Any selector included in this function *MUST* be implemented by ASCollectionView.
 */
static BOOL _isInterceptedSelector(SEL sel)
{
  return (          
          // handled by ASCollectionView node<->cell machinery
          sel == @selector(collectionView:cellForItemAtIndexPath:) ||
          sel == @selector(collectionView:layout:sizeForItemAtIndexPath:) ||
          
          // handled by ASRangeController
          sel == @selector(numberOfSectionsInCollectionView:) ||
          sel == @selector(collectionView:numberOfItemsInSection:) ||
          
          // used for ASRangeController visibility updates
          sel == @selector(collectionView:willDisplayCell:forItemAtIndexPath:) ||
          sel == @selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)
          );
}


/**
 * Stand-in for UICollectionViewDataSource and UICollectionViewDelegate.  Any method calls we intercept are routed to ASCollectionView;
 * everything else leaves AsyncDisplayKit safely and arrives at the original intended data source and delegate.
 */
@interface _ASCollectionViewProxy : NSProxy
- (instancetype)initWithTarget:(id<NSObject>)target interceptor:(ASCollectionView *)interceptor;
@end

@implementation _ASCollectionViewProxy {
  id<NSObject> __weak _target;
  ASCollectionView * __weak _interceptor;
}

- (instancetype)initWithTarget:(id<NSObject>)target interceptor:(ASCollectionView *)interceptor
{
  // -[NSProxy init] is undefined
  if (!self) {
    return nil;
  }
  
  ASDisplayNodeAssert(target, @"target must not be nil");
  ASDisplayNodeAssert(interceptor, @"interceptor must not be nil");
  
  _target = target;
  _interceptor = interceptor;
  
  return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
  return (_isInterceptedSelector(aSelector) || [_target respondsToSelector:aSelector]);
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  if (_isInterceptedSelector(aSelector)) {
    return _interceptor;
  }
  
  return [_target respondsToSelector:aSelector] ? _target : nil;
}

@end


#pragma mark -
#pragma mark ASCollectionView.

@interface ASCollectionView () <ASRangeControllerDelegate> {
  _ASCollectionViewProxy *_proxyDataSource;
  _ASCollectionViewProxy *_proxyDelegate;
  
  ASRangeController *_rangeController;
}

@end

@implementation ASCollectionView

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  if (!(self = [super initWithFrame:frame collectionViewLayout:layout]))
    return nil;
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.delegate = self;
  
  [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"_ASCollectionViewCell"];
  
  return self;
}


#pragma mark -
#pragma mark Overrides.

- (void)reloadData
{
  [_rangeController rebuildData];
  [super reloadData];
}

- (void)setDataSource:(id<UICollectionViewDataSource>)dataSource
{
  ASDisplayNodeAssert(NO, @"ASCollectionView uses asyncDataSource, not UICollectionView's dataSource property.");
}

- (void)setDelegate:(id<UICollectionViewDelegate>)delegate
{
  // Our UIScrollView superclass sets its delegate to nil on dealloc. Only assert if we get a non-nil value here.
  ASDisplayNodeAssert(delegate == nil, @"ASCollectionView uses asyncDelegate, not UICollectionView's delegate property.");
}

- (void)setAsyncDataSource:(id<ASCollectionViewDataSource>)asyncDataSource
{
  if (_asyncDataSource == asyncDataSource)
    return;
  
  _asyncDataSource = asyncDataSource;
  _proxyDataSource = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
  super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASCollectionViewDelegate>)asyncDelegate
{
  if (_asyncDelegate == asyncDelegate)
    return;
  
  _asyncDelegate = asyncDelegate;
  _proxyDelegate = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
  super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
}

- (ASRangeTuningParameters)rangeTuningParameters
{
  return _rangeController.tuningParameters;
}

- (void)setRangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  _rangeController.tuningParameters = tuningParameters;
}

- (void)appendNodesWithIndexPaths:(NSArray *)indexPaths
{
  [_rangeController appendNodesWithIndexPaths:indexPaths];
}

- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [_rangeController calculatedSizeForNodeAtIndexPath:indexPath];
}

#pragma mark Assertions.

- (void)throwUnimplementedException
{
  [[NSException exceptionWithName:@"UnimplementedException"
                           reason:@"ASCollectionView's update/editing support is not yet implemented.  Please see ASCollectionView.h."
                         userInfo:nil] raise];
}

- (void)insertSections:(NSIndexSet *)sections
{
  [self throwUnimplementedException];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  [self throwUnimplementedException];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  [self throwUnimplementedException];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [self throwUnimplementedException];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self throwUnimplementedException];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self throwUnimplementedException];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self throwUnimplementedException];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    [self throwUnimplementedException];
}


#pragma mark -
#pragma mark Intercepted selectors.

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *reuseIdentifier = @"_ASCollectionViewCell";
  
  UICollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
  
  [_rangeController configureContentView:cell.contentView forIndexPath:indexPath];
  
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_rangeController calculatedSizeForNodeAtIndexPath:indexPath];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return [_rangeController numberOfSizedSections];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_rangeController numberOfSizedRowsInSection:section];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChange];
  
  if ([_asyncDelegate respondsToSelector:@selector(collectionView:willDisplayNodeForItemAtIndexPath:)]) {
    [_asyncDelegate collectionView:self willDisplayNodeForItemAtIndexPath:indexPath];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChange];
  
  if ([_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNodeForItemAtIndexPath:)]) {
    [_asyncDelegate collectionView:self didEndDisplayingNodeForItemAtIndexPath:indexPath];
  }
}


#pragma mark -
#pragma mark ASRangeControllerDelegate.

- (NSArray *)rangeControllerVisibleNodeIndexPaths:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return [[self indexPathsForVisibleItems] sortedArrayUsingSelector:@selector(compare:)];
}

- (CGSize)rangeControllerViewportSize:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
}

- (NSInteger)rangeControllerSections:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  if ([_asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
    return [_asyncDataSource numberOfSectionsInCollectionView:self];
  } else {
    return 1;
  }
}

- (NSInteger)rangeController:(ASRangeController *)rangeController rowsInSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [_asyncDataSource collectionView:self numberOfItemsInSection:section];
}

- (ASCellNode *)rangeController:(ASRangeController *)rangeController nodeForIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotMainThread();
  return [_asyncDataSource collectionView:self nodeForItemAtIndexPath:indexPath];
}

- (CGSize)rangeController:(ASRangeController *)rangeController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotMainThread();
  CGSize contentSize = [self.collectionViewLayout collectionViewContentSize];
  CGSize viewSize = self.bounds.size;
  CGFloat constrainedWidth = viewSize.width == contentSize.width ? viewSize.width : FLT_MAX;
  CGFloat constrainedHeight = viewSize.height == contentSize.height ? viewSize.height : FLT_MAX;
  return CGSizeMake(constrainedWidth, constrainedHeight);
}

- (void)rangeController:(ASRangeController *)rangeController didSizeNodesWithIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  [UIView performWithoutAnimation:^{
    [self performBatchUpdates:^{
      // -insertItemsAtIndexPaths: is insufficient; UICollectionView also needs to be notified of section changes
      NSInteger sectionCount = [super numberOfSections];
      NSInteger newSectionCount = [_rangeController numberOfSizedSections];
      if (newSectionCount > sectionCount) {
        NSRange range = NSMakeRange(sectionCount, newSectionCount - sectionCount);
        NSIndexSet *sections = [NSIndexSet indexSetWithIndexesInRange:range];
        [super insertSections:sections];
      }
      
      [super insertItemsAtIndexPaths:indexPaths];
    } completion:nil];
  }];
}

@end

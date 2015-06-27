/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionView.h"

#import "ASAssert.h"
#import "ASCollectionViewLayoutController.h"
#import "ASRangeController.h"
#import "ASDataController.h"
#import "ASDisplayNodeInternal.h"
#import "ASBatchFetching.h"
#import "UICollectionViewLayout+ASConvenience.h"

const static NSUInteger kASCollectionViewAnimationNone = UITableViewRowAnimationNone;


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
          sel == @selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:) ||

          // used for batch fetching API
          sel == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)
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
  ASDisplayNodeAssert(_target, @"target must not be nil"); // catch weak ref's being nilled early
  ASDisplayNodeAssert(_interceptor, @"interceptor must not be nil");

  return (_isInterceptedSelector(aSelector) || [_target respondsToSelector:aSelector]);
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  ASDisplayNodeAssert(_target, @"target must not be nil"); // catch weak ref's being nilled early
  ASDisplayNodeAssert(_interceptor, @"interceptor must not be nil");

  if (_isInterceptedSelector(aSelector)) {
    return _interceptor;
  }
  
  return [_target respondsToSelector:aSelector] ? _target : nil;
}

@end


#pragma mark -
#pragma mark ASCollectionView.

@interface ASCollectionView () <ASRangeControllerDelegate, ASDataControllerSource> {
  _ASCollectionViewProxy *_proxyDataSource;
  _ASCollectionViewProxy *_proxyDelegate;

  ASDataController *_dataController;
  ASRangeController *_rangeController;
  ASCollectionViewLayoutController *_layoutController;

  BOOL _performingBatchUpdates;
  NSMutableArray *_batchUpdateBlocks;

  BOOL _asyncDataFetchingEnabled;

  ASBatchContext *_batchContext;
}

@property (atomic, assign) BOOL asyncDataSourceLocked;

@end

@implementation ASCollectionView

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:frame collectionViewLayout:layout asyncDataFetching:NO];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  if (!(self = [super initWithFrame:frame collectionViewLayout:layout]))
    return nil;
  
  // FIXME: asyncDataFetching is currently unreliable for some use cases.
  // https://github.com/facebook/AsyncDisplayKit/issues/385
  asyncDataFetchingEnabled = NO;

  _layoutController = [[ASCollectionViewLayoutController alloc] initWithCollectionView:self];

  _rangeController = [[ASRangeController alloc] init];
  _rangeController.delegate = self;
  _rangeController.layoutController = _layoutController;

  _dataController = [[ASDataController alloc] initWithAsyncDataFetching:asyncDataFetchingEnabled];
  _dataController.delegate = _rangeController;
  _dataController.dataSource = self;

  _batchContext = [[ASBatchContext alloc] init];

  _leadingScreensForBatching = 1.0;

  _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  _asyncDataSourceLocked = NO;

  _performingBatchUpdates = NO;
  _batchUpdateBlocks = [NSMutableArray array];

  [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"_ASCollectionViewCell"];
  
  return self;
}

- (void)dealloc
{
  // Sometimes the UIKit classes can call back to their delegate even during deallocation.
  // This bug might be iOS 7-specific.
  super.delegate  = nil;
  super.dataSource = nil;
}

#pragma mark -
#pragma mark Overrides.

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssert(self.asyncDelegate, @"ASCollectionView's asyncDelegate property must be set.");
  ASDisplayNodePerformBlockOnMainThread(^{
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOptions:kASCollectionViewAnimationNone completion:completion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
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
  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDataSource in the ViewController's dealloc. In this case our _asyncDataSource
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to nil out
  // super.dataSource in this case because calls to _ASTableViewProxy will start failing and cause crashes.

  if (asyncDataSource == nil) {
    super.dataSource = nil;
    _asyncDataSource = nil;
    _proxyDataSource = nil;
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
  }
}

- (void)setAsyncDelegate:(id<ASCollectionViewDelegate>)asyncDelegate
{
  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDelegate in the ViewController's dealloc. In this case our _asyncDelegate
  // will return as nil (ARC magic) even though the _proxyDelegate still exists. It's really important to nil out
  // super.delegate in this case because calls to _ASTableViewProxy will start failing and cause crashes.

  if (asyncDelegate == nil) {
    // order is important here, the delegate must be callable while nilling super.delegate to avoid random crashes
    // in UIScrollViewAccessibility.
    super.delegate = nil;
    _asyncDelegate = nil;
    _proxyDelegate = nil;
  } else {
    _asyncDelegate = asyncDelegate;
    _proxyDelegate = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
    super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
  }
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [_layoutController setTuningParameters:tuningParameters forRangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [_layoutController tuningParametersForRangeType:rangeType];
}

- (ASRangeTuningParameters)rangeTuningParameters
{
  return [self tuningParametersForRangeType:ASLayoutRangeTypeRender];
}

- (void)setRangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  [self setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeRender];
}

- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [[_dataController nodeAtIndexPath:indexPath] calculatedSize];
}

- (NSArray *)visibleNodes
{
  NSArray *indexPaths = [self indexPathsForVisibleItems];
  NSMutableArray *visibleNodes = [[NSMutableArray alloc] init];

  [indexPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    ASCellNode *visibleNode = [self nodeForItemAtIndexPath:obj];
    [visibleNodes addObject:visibleNode];
  }];

  return visibleNodes;
}

#pragma mark Assertions.

- (void)performBatchUpdates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [_dataController beginUpdates];
  updates();
  [_dataController endUpdatesWithCompletion:completion];
}

- (void)insertSections:(NSIndexSet *)sections
{
  [_dataController insertSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  [_dataController deleteSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  [_dataController reloadSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [_dataController moveSection:section toSection:newSection withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOptions:kASCollectionViewAnimationNone];
}

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

#pragma mark -
#pragma mark Intercepted selectors.

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *reuseIdentifier = @"_ASCollectionViewCell";
  
  UICollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];

  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  
  [_rangeController configureContentView:cell.contentView forCellNode:node];
  
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [[_dataController nodeAtIndexPath:indexPath] calculatedSize];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return [_dataController numberOfSections];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_dataController numberOfRowsInSection:section];
}

- (ASScrollDirection)scrollDirection
{
  CGPoint scrollVelocity = [self.panGestureRecognizer velocityInView:self.superview];
  return [self scrollDirectionForVelocity:scrollVelocity];
}
  
- (ASScrollDirection)scrollDirectionForVelocity:(CGPoint)scrollVelocity
{
  ASScrollDirection direction = ASScrollDirectionNone;
  ASScrollDirection scrollableDirections = [self scrollableDirections];
  
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections)) { // Can scroll horizontally.
    if (scrollVelocity.x >= 0) {
      direction |= ASScrollDirectionRight;
    } else {
      direction |= ASScrollDirectionLeft;
    }
  }
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections)) { // Can scroll vertically.
    if (scrollVelocity.y >= 0) {
      direction |= ASScrollDirectionDown;
    } else {
      direction |= ASScrollDirectionUp;
    }
  }

  return direction;
}

- (ASScrollDirection)scrollableDirections
{
  if ([self.collectionViewLayout asdk_isFlowLayout]) {
    return [self flowLayoutScrollableDirections:(UICollectionViewFlowLayout *)self.collectionViewLayout];
  } else {
    return [self nonFlowLayoutScrollableDirections];
  }
}

- (ASScrollDirection)flowLayoutScrollableDirections:(UICollectionViewFlowLayout *)flowLayout {
  return (flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) ? ASScrollDirectionHorizontalDirections : ASScrollDirectionVerticalDirections;
}

- (ASScrollDirection)nonFlowLayoutScrollableDirections
{
  ASScrollDirection scrollableDirection = ASScrollDirectionNone;
  if (self.contentSize.width > self.bounds.size.width) { // Can scroll horizontally.
    scrollableDirection |= ASScrollDirectionHorizontalDirections;
  }
  if (self.contentSize.height > self.bounds.size.height) { // Can scroll vertically.
    scrollableDirection |= ASScrollDirectionVerticalDirections;
  }
  return scrollableDirection;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
  
  if ([_asyncDelegate respondsToSelector:@selector(collectionView:willDisplayNodeForItemAtIndexPath:)]) {
    [_asyncDelegate collectionView:self willDisplayNodeForItemAtIndexPath:indexPath];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
  
  if ([_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNodeForItemAtIndexPath:)]) {
    [_asyncDelegate collectionView:self didEndDisplayingNodeForItemAtIndexPath:indexPath];
  }
}


#pragma mark -
#pragma mark Batch Fetching

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
  [self handleBatchFetchScrollingToOffset:*targetContentOffset];

  if ([_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)]) {
    [_asyncDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
  }
}

- (BOOL)shouldBatchFetch
{
  // if the delegate does not respond to this method, there is no point in starting to fetch
  BOOL canFetch = [_asyncDelegate respondsToSelector:@selector(collectionView:willBeginBatchFetchWithContext:)];
  if (canFetch && [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForCollectionView:)]) {
    return [_asyncDelegate shouldBatchFetchForCollectionView:self];
  } else {
    return canFetch;
  }
}

- (void)handleBatchFetchScrollingToOffset:(CGPoint)targetOffset
{
  ASDisplayNodeAssert(_batchContext != nil, @"Batch context should exist");

  if (![self shouldBatchFetch]) {
    return;
  }

  if (ASDisplayShouldFetchBatchForContext(_batchContext, [self scrollDirection], self.bounds, self.contentSize, targetOffset, _leadingScreensForBatching)) {
    [_batchContext beginBatchFetching];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [_asyncDelegate collectionView:self willBeginBatchFetchWithContext:_batchContext];
    });
  }
}


#pragma mark - ASDataControllerSource

- (ASCellNode *)dataController:(ASDataController *)dataController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_asyncDataSource collectionView:self nodeForItemAtIndexPath:indexPath];
  ASDisplayNodeAssert([node isKindOfClass:ASCellNode.class], @"invalid node class, expected ASCellNode");
  return node;
}

- (CGSize)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  CGSize restrainedSize = self.bounds.size;

  if (ASScrollDirectionContainsHorizontalDirection([self scrollableDirections])) {
    restrainedSize.width = FLT_MAX;
  } else {
    restrainedSize.height = FLT_MAX;
  }

  return restrainedSize;
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  return [_asyncDataSource collectionView:self numberOfItemsInSection:section];
}

- (NSUInteger)dataControllerNumberOfSections:(ASDataController *)dataController {
  if ([_asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
    return [_asyncDataSource numberOfSectionsInCollectionView:self];
  } else {
    return 1;
  }
}

- (void)dataControllerLockDataSource
{
  ASDisplayNodeAssert(!self.asyncDataSourceLocked, @"The data source has already been locked");

  self.asyncDataSourceLocked = YES;
  if ([_asyncDataSource respondsToSelector:@selector(collectionViewLockDataSource:)]) {
    [_asyncDataSource collectionViewLockDataSource:self];
  }
}

- (void)dataControllerUnlockDataSource
{
  ASDisplayNodeAssert(self.asyncDataSourceLocked, @"The data source has already been unlocked");

  self.asyncDataSourceLocked = NO;
  if ([_asyncDataSource respondsToSelector:@selector(collectionViewUnlockDataSource:)]) {
    [_asyncDataSource collectionViewUnlockDataSource:self];
  }
}

#pragma mark -
#pragma mark ASRangeControllerDelegate.

- (void)rangeControllerBeginUpdates:(ASRangeController *)rangeController {
  ASDisplayNodeAssertMainThread();
  _performingBatchUpdates = YES;
}

- (void)rangeControllerEndUpdates:(ASRangeController *)rangeController completion:(void (^)(BOOL))completion {
  ASDisplayNodeAssertMainThread();

  [super performBatchUpdates:^{
    [_batchUpdateBlocks enumerateObjectsUsingBlock:^(dispatch_block_t block, NSUInteger idx, BOOL *stop) {
      block();
    }];
  } completion:^(BOOL finished) {
    if (completion) {
      completion(finished);
    }
  }];

  [_batchUpdateBlocks removeAllObjects];
  _performingBatchUpdates = NO;
}

- (NSArray *)rangeControllerVisibleNodeIndexPaths:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return [self indexPathsForVisibleItems];
}

- (CGSize)rangeControllerViewportSize:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
}

- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths
{
  return [_dataController nodesAtIndexPaths:indexPaths];
}

- (void)rangeController:(ASRangeController *)rangeController didInsertNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super insertItemsAtIndexPaths:indexPaths];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super insertItemsAtIndexPaths:indexPaths];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super deleteItemsAtIndexPaths:indexPaths];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super deleteItemsAtIndexPaths:indexPaths];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super insertSections:indexSet];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super insertSections:indexSet];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super deleteSections:indexSet];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super deleteSections:indexSet];
    }];
  }
}

@end

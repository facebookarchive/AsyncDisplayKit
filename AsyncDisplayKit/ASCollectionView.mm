/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionView.h"

#import "ASAssert.h"
#import "ASFlowLayoutController.h"
#import "ASRangeController.h"
#import "ASDataController.h"
#import "ASDisplayNodeInternal.h"

const static NSUInteger kASCollectionViewAnimationNone = 0;


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

@interface ASCollectionView () <ASRangeControllerDelegate, ASDataControllerSource> {
  _ASCollectionViewProxy *_proxyDataSource;
  _ASCollectionViewProxy *_proxyDelegate;

  ASDataController *_dataController;
  ASRangeController *_rangeController;
  ASFlowLayoutController *_layoutController;

  BOOL _performingBatchUpdates;
  NSMutableArray *_batchUpdateBlocks;
}

@end

@implementation ASCollectionView

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  if (!(self = [super initWithFrame:frame collectionViewLayout:layout]))
    return nil;

  ASDisplayNodeAssert([layout isKindOfClass:UICollectionViewFlowLayout.class], @"only flow layouts are currently supported");

  ASFlowLayoutDirection direction = (((UICollectionViewFlowLayout *)layout).scrollDirection == UICollectionViewScrollDirectionHorizontal) ? ASFlowLayoutDirectionHorizontal : ASFlowLayoutDirectionVertical;
  _layoutController = [[ASFlowLayoutController alloc] initWithScrollOption:direction];

  _rangeController = [[ASRangeController alloc] init];
  _rangeController.delegate = self;
  _rangeController.layoutController = _layoutController;

  _dataController = [[ASDataController alloc] init];
  _dataController.delegate = _rangeController;
  _dataController.dataSource = self;

  _proxyDelegate = [[_ASCollectionViewProxy alloc] initWithTarget:nil interceptor:self];
  super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;

  _performingBatchUpdates = NO;
  _batchUpdateBlocks = [NSMutableArray array];

  [self registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"_ASCollectionViewCell"];
  
  return self;
}

#pragma mark -
#pragma mark Overrides.

- (void)reloadData
{
  ASDisplayNodePerformBlockOnMainThread(^{
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOption:kASCollectionViewAnimationNone];
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

  if (asyncDataSource == nil) {
    _asyncDataSource = nil;
    _proxyDataSource = nil;
    super.dataSource = nil;
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
  }
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
  return _layoutController.tuningParameters;
}

- (void)setRangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  _layoutController.tuningParameters = tuningParameters;
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
  [_dataController insertSections:sections withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  [_dataController deleteSections:sections withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  [_dataController reloadSections:sections withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [_dataController moveSection:section toSection:newSection withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOption:kASCollectionViewAnimationNone];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOption:kASCollectionViewAnimationNone];
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
  ASScrollDirection direction = ASScrollDirectionNone;
  if (_layoutController.layoutDirection == ASFlowLayoutDirectionHorizontal) {
    if (scrollVelocity.x > 0) {
      direction = ASScrollDirectionRight;
    } else if (scrollVelocity.x < 0) {
      direction = ASScrollDirectionLeft;
    }
  } else {
    if (scrollVelocity.y > 0) {
      direction = ASScrollDirectionDown;
    } else {
      direction = ASScrollDirectionUp;
    }
  }

  return direction;
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

  if (_layoutController.layoutDirection == ASFlowLayoutDirectionHorizontal) {
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

- (void)rangeController:(ASRangeController *)rangeController didInsertNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
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

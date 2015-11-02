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
#import "ASCollectionDataController.h"
#import "ASBatchFetching.h"
#import "UICollectionViewLayout+ASConvenience.h"
#import "ASInternalHelpers.h"
#import "ASCollectionViewFlowLayoutInspector.h"

// FIXME: Temporary nonsense import until method names are finalized and exposed
#import "ASDisplayNode+Subclasses.h"

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
          sel == @selector(collectionView:viewForSupplementaryElementOfKind:atIndexPath:) ||
          
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
#pragma mark ASCellNode<->UICollectionViewCell bridging.

@class _ASCollectionViewCell;

@interface _ASCollectionViewCell : UICollectionViewCell
@property (nonatomic, weak) ASCellNode *node;
@end

@implementation _ASCollectionViewCell

- (void)setSelected:(BOOL)selected
{
  _node.selected = selected;
}

- (void)setHighlighted:(BOOL)highlighted
{
  _node.highlighted = highlighted;
}

@end

#pragma mark -
#pragma mark ASCollectionView.

@interface ASCollectionView () <ASRangeControllerDelegate, ASDataControllerSource, ASCellNodeLayoutDelegate> {
  _ASCollectionViewProxy *_proxyDataSource;
  _ASCollectionViewProxy *_proxyDelegate;

  ASCollectionDataController *_dataController;
  ASRangeController *_rangeController;
  ASCollectionViewLayoutController *_layoutController;
  ASCollectionViewFlowLayoutInspector *_flowLayoutInspector;

  BOOL _performingBatchUpdates;
  NSMutableArray *_batchUpdateBlocks;

  BOOL _asyncDataFetchingEnabled;
  BOOL _asyncDelegateImplementsInsetSection;
  BOOL _collectionViewLayoutImplementsInsetSection;
  BOOL _asyncDataSourceImplementsConstrainedSizeForNode;

  ASBatchContext *_batchContext;
  
  CGSize _maxSizeForNodesConstrainedSize;
  BOOL _ignoreMaxSizeChange;
  
  NSMutableSet *_registeredSupplementaryKinds;
  
  /**
   * If YES, the `UICollectionView` will reload its data on next layout pass so we should not forward any updates to it.
   
   * Rationale:
   * In `reloadData`, a collection view invalidates its data and marks itself as needing reload, and waits until `layoutSubviews` to requery its data source.
   * This can lead to data inconsistency problems.
   * Say you have an empty collection view. You call `reloadData`, then immediately insert an item into your data source and call `insertItemsAtIndexPaths:[0,0]`.
   * You will get an assertion failure saying `Invalid number of items in section 0.
   * The number of items after the update (1) must be equal to the number of items before the update (1) plus or minus the items added and removed (1 added, 0 removed).`
   * The collection view never queried your data source before the update to see that it actually had 0 items.
  */
  BOOL _superIsPendingDataLoad;
}

@property (atomic, assign) BOOL asyncDataSourceLocked;

@end

@implementation ASCollectionView

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:CGRectZero collectionViewLayout:layout asyncDataFetching:NO];
}

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

  _dataController = [[ASCollectionDataController alloc] initWithAsyncDataFetching:asyncDataFetchingEnabled];
  _dataController.delegate = _rangeController;
  _dataController.dataSource = self;
  
  _batchContext = [[ASBatchContext alloc] init];

  _leadingScreensForBatching = 1.0;

  _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  _asyncDataSourceLocked = NO;

  _performingBatchUpdates = NO;
  _batchUpdateBlocks = [NSMutableArray array];

  _superIsPendingDataLoad = YES;
  
  _collectionViewLayoutImplementsInsetSection = [layout respondsToSelector:@selector(sectionInset)];

  _maxSizeForNodesConstrainedSize = self.bounds.size;
  // If the initial size is 0, expect a size change very soon which is part of the initial configuration
  // and should not trigger a relayout.
  _ignoreMaxSizeChange = CGSizeEqualToSize(_maxSizeForNodesConstrainedSize, CGSizeZero);
  
  // Register the default layout inspector delegate for flow layouts only, custom layouts
  // will need to roll their own ASCollectionViewLayoutInspecting implementation and set a layout delegate
  if ([layout asdk_isFlowLayout]) {
    _layoutInspector = [self flowLayoutInspector];
  }
  
  _registeredSupplementaryKinds = [NSMutableSet set];
  
  self.backgroundColor = [UIColor whiteColor];
  
  [self registerClass:[_ASCollectionViewCell class] forCellWithReuseIdentifier:@"_ASCollectionViewCell"];
  
  return self;
}

- (void)dealloc
{
  // Sometimes the UIKit classes can call back to their delegate even during deallocation.
  // This bug might be iOS 7-specific.
  super.delegate  = nil;
  super.dataSource = nil;
}

/**
 * A layout inspector implementation specific for the sizing behavior of UICollectionViewFlowLayouts
 */
- (ASCollectionViewFlowLayoutInspector *)flowLayoutInspector
{
    if (_flowLayoutInspector == nil) {
        UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
        ASDisplayNodeAssertNotNil(layout, @"Collection view layout must be a flow layout to use the built-in inspector");
        _flowLayoutInspector = [[ASCollectionViewFlowLayoutInspector alloc] initWithCollectionView:self
                                                                                        flowLayout:layout];
    }
    return _flowLayoutInspector;
}

#pragma mark -
#pragma mark Overrides.

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssert(self.asyncDelegate, @"ASCollectionView's asyncDelegate property must be set.");
  ASPerformBlockOnMainThread(^{
    _superIsPendingDataLoad = YES;
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOptions:kASCollectionViewAnimationNone completion:completion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)reloadDataImmediately
{
  ASDisplayNodeAssertMainThread();
  [_dataController reloadDataImmediatelyWithAnimationOptions:kASCollectionViewAnimationNone];
  [super reloadData];
}

- (void)setDataSource:(id<UICollectionViewDataSource>)dataSource
{
  // UIKit can internally generate a call to this method upon changing the asyncDataSource; only assert for non-nil.
  ASDisplayNodeAssert(dataSource == nil, @"ASCollectionView uses asyncDataSource, not UICollectionView's dataSource property.");
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
    _asyncDataSourceImplementsConstrainedSizeForNode = NO;
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
    _asyncDataSourceImplementsConstrainedSizeForNode = ([_asyncDataSource respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)] ? 1 : 0);
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
    _asyncDelegateImplementsInsetSection = NO;
  } else {
    _asyncDelegate = asyncDelegate;
    _proxyDelegate = [[_ASCollectionViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
    super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
    _asyncDelegateImplementsInsetSection = ([_asyncDelegate respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)] ? 1 : 0);
  }

  [_layoutInspector didChangeCollectionViewDelegate:asyncDelegate];
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

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [_dataController indexPathForNode:cellNode];
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

- (void)performBatchAnimated:(BOOL)animated updates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();

  [_dataController beginUpdates];
  updates();
  [_dataController endUpdatesAnimated:animated completion:completion];
}

- (void)performBatchUpdates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self performBatchAnimated:YES updates:updates completion:completion];
}

- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind
{
  ASDisplayNodeAssert(elementKind != nil, @"A kind is needed for supplementary node registration");
  [_registeredSupplementaryKinds addObject:elementKind];
  [self registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:elementKind
                                            withReuseIdentifier:[self __reuseIdentifierForKind:elementKind]];
}

- (void)insertSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  [_dataController insertSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  [_dataController deleteSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  [_dataController reloadSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  [_dataController moveSection:section toSection:newSection withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOptions:kASCollectionViewAnimationNone];
}

- (NSString *)__reuseIdentifierForKind:(NSString *)kind
{
  return [@"_ASCollectionSupplementaryView_" stringByAppendingString:kind];
}

#pragma mark -
#pragma mark Intercepted selectors.

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *reuseIdentifier = @"_ASCollectionViewCell";
  
  _ASCollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];

  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  
  [_rangeController configureContentView:cell.contentView forCellNode:node];
  
  cell.node = node;
  
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [[_dataController nodeAtIndexPath:indexPath] calculatedSize];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *identifier = [self __reuseIdentifierForKind:kind];
  UICollectionReusableView *view = [self dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:identifier forIndexPath:indexPath];
  ASCellNode *node = [_dataController supplementaryNodeOfKind:kind atIndexPath:indexPath];
  [_rangeController configureContentView:view forCellNode:node];
  return view;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  _superIsPendingDataLoad = NO;
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
  
  ASCellNode *cellNode = [self nodeForItemAtIndexPath:indexPath];
  if (cellNode.neverShowPlaceholders) {
    [cellNode recursivelyEnsureDisplay];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
  
  if ([_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNodeForItemAtIndexPath:)]) {
    [_asyncDelegate collectionView:self didEndDisplayingNodeForItemAtIndexPath:indexPath];
  }
}

- (void)layoutSubviews
{
  if (! CGSizeEqualToSize(_maxSizeForNodesConstrainedSize, self.bounds.size)) {
    _maxSizeForNodesConstrainedSize = self.bounds.size;
    
    // First size change occurs during initial configuration. An expensive relayout pass is unnecessary at that time
    // and should be avoided, assuming that the initial data loading automatically runs shortly afterward.
    if (_ignoreMaxSizeChange) {
      _ignoreMaxSizeChange = NO;
    } else {
      [self performBatchAnimated:NO updates:^{
        [_dataController relayoutAllNodes];
      } completion:nil];
    }
  }
  
  // To ensure _maxSizeForNodesConstrainedSize is up-to-date for every usage, this call to super must be done last
  [super layoutSubviews];
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
  node.layoutDelegate = self;
  return node;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange constrainedSize;
  if (_asyncDataSourceImplementsConstrainedSizeForNode) {
    constrainedSize = [_asyncDataSource collectionView:self constrainedSizeForNodeAtIndexPath:indexPath];
  } else {
    CGSize maxSize = _maxSizeForNodesConstrainedSize;
    if (ASScrollDirectionContainsHorizontalDirection([self scrollableDirections])) {
      maxSize.width = FLT_MAX;
    } else {
      maxSize.height = FLT_MAX;
    }
    constrainedSize = ASSizeRangeMake(CGSizeZero, maxSize);
  }

  UIEdgeInsets sectionInset = UIEdgeInsetsZero;
  if (_collectionViewLayoutImplementsInsetSection) {
    sectionInset = [(UICollectionViewFlowLayout *)self.collectionViewLayout sectionInset];
  }
  
  if (_asyncDelegateImplementsInsetSection) {
    sectionInset = [(id<ASCollectionViewDelegateFlowLayout>)_asyncDelegate collectionView:self layout:self.collectionViewLayout insetForSectionAtIndex:indexPath.section];
  }

  if (ASScrollDirectionContainsHorizontalDirection([self scrollableDirections])) {
    constrainedSize.min.width = MAX(0, constrainedSize.min.width - sectionInset.left - sectionInset.right);
    //ignore insets for FLT_MAX so FLT_MAX can be compared against
    if (constrainedSize.max.width - FLT_EPSILON < FLT_MAX) {
      constrainedSize.max.width = MAX(0, constrainedSize.max.width - sectionInset.left - sectionInset.right);
    }
  } else {
    constrainedSize.min.height = MAX(0, constrainedSize.min.height - sectionInset.top - sectionInset.bottom);
    //ignore insets for FLT_MAX so FLT_MAX can be compared against
    if (constrainedSize.max.height - FLT_EPSILON < FLT_MAX) {
      constrainedSize.max.height = MAX(0, constrainedSize.max.height - sectionInset.top - sectionInset.bottom);
    }
  }

  return constrainedSize;
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  return [_asyncDataSource collectionView:self numberOfItemsInSection:section];
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController {
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

#pragma mark - ASCollectionViewDataControllerSource Supplementary view support

- (ASCellNode *)dataController:(ASCollectionDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_asyncDataSource collectionView:self nodeForSupplementaryElementOfKind:kind atIndexPath:indexPath];
  ASDisplayNodeAssert(node != nil, @"A node must be returned for a supplementary node");
  return node;
}

- (NSArray *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController
{
  return [_registeredSupplementaryKinds allObjects];
}

- (ASSizeRange)dataController:(ASCollectionDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(_layoutInspector != nil, @"To support supplementary nodes in ASCollectionView, it must have a layoutDelegate for layout inspection. (See ASCollectionViewFlowLayoutInspector for an example.)");
  return [_layoutInspector collectionView:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
}

- (NSUInteger)dataController:(ASCollectionDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  ASDisplayNodeAssert(_layoutInspector != nil, @"To support supplementary nodes in ASCollectionView, it must have a layoutDelegate for layout inspection. (See ASCollectionViewFlowLayoutInspector for an example.)");
  return [_layoutInspector collectionView:self supplementaryNodesOfKind:kind inSection:section];
}

- (NSUInteger)dataController:(ASCollectionDataController *)dataController numberOfSectionsForSupplementaryNodeOfKind:(NSString *)kind;
{
  ASDisplayNodeAssert(_layoutInspector != nil, @"To support supplementary nodes in ASCollectionView, it must have a layoutDelegate for layout inspection. (See ASCollectionViewFlowLayoutInspector for an example.)");
  return [_layoutInspector collectionView:self numberOfSectionsForSupplementaryNodeOfKind:kind];
}

#pragma mark - ASRangeControllerDelegate.

- (void)rangeControllerBeginUpdates:(ASRangeController *)rangeController {
  ASDisplayNodeAssertMainThread();
  _performingBatchUpdates = YES;
}

- (void)rangeController:(ASRangeController *)rangeController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion {
  ASDisplayNodeAssertMainThread();

  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    if (completion) {
      completion(NO);
    }
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  ASPerformBlockWithoutAnimation(!animated, ^{
    [super performBatchUpdates:^{
      for (dispatch_block_t block in _batchUpdateBlocks) {
        block();
      }
    } completion:completion];
  });

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

- (void)rangeController:(ASRangeController *)rangeController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

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

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

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

  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

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

  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

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

#pragma mark - ASCellNodeDelegate

- (void)node:(ASCellNode *)node didRelayoutWithSuggestedAnimation:(ASCellNodeAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath != nil) {
    [super reloadItemsAtIndexPaths:@[indexPath]];
  }
}

@end

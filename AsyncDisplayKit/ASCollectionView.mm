//
//  ASCollectionView.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASAssert.h"
#import "ASAvailability.h"
#import "ASBatchFetching.h"
#import "ASDelegateProxy.h"
#import "ASCellNode+Internal.h"
#import "ASCollectionDataController.h"
#import "ASCollectionViewLayoutController.h"
#import "ASCollectionViewFlowLayoutInspector.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASInternalHelpers.h"
#import "UICollectionViewLayout+ASConvenience.h"
#import "ASRangeController.h"
#import "ASCollectionNode.h"
#import "_ASDisplayLayer.h"
#import "ASCollectionViewLayoutFacilitatorProtocol.h"
#import "ASSectionContext.h"
#import "ASCollectionView+Undeprecated.h"

/**
 * A macro to get self.collectionNode and assign it to a local variable, or return
 * the given value if nil.
 *
 * Previously we would set ASCollectionNode's dataSource & delegate to nil
 * during dealloc. However, our asyncDelegate & asyncDataSource must be set on the
 * main thread, so if the node is deallocated off-main, we won't learn about the change
 * until later on. Since our @c collectionNode parameter to delegate methods (e.g.
 * collectionNode:didEndDisplayingItemWithNode:) is nonnull, it's important that we never
 * unintentionally pass nil (this will crash in Swift, in production). So we can use
 * this macro to ensure that our node is still alive before calling out to the user
 * on its behalf.
 */
#define GET_COLLECTIONNODE_OR_RETURN(__var, __val) \
  ASCollectionNode *__var = self.collectionNode; \
  if (__var == nil) { \
    return __val; \
  }

/// What, if any, invalidation should we perform during the next -layoutSubviews.
typedef NS_ENUM(NSUInteger, ASCollectionViewInvalidationStyle) {
  /// Perform no invalidation.
  ASCollectionViewInvalidationStyleNone,
  /// Perform invalidation with animation (use an empty batch update).
  ASCollectionViewInvalidationStyleWithoutAnimation,
  /// Perform invalidation without animation (use -invalidateLayout).
  ASCollectionViewInvalidationStyleWithAnimation,
};

static const NSUInteger kASCollectionViewAnimationNone = UITableViewRowAnimationNone;
static NSString * const kCellReuseIdentifier = @"_ASCollectionViewCell";

#pragma mark -
#pragma mark ASCellNode<->UICollectionViewCell bridging.

@class _ASCollectionViewCell;

@interface _ASCollectionViewCell : UICollectionViewCell
@property (nonatomic, weak) ASCellNode *node;
@property (nonatomic, strong) UICollectionViewLayoutAttributes *layoutAttributes;
@end

@implementation _ASCollectionViewCell

- (void)setNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  node.layoutAttributes = _layoutAttributes;
  _node = node;
  [node __setSelectedFromUIKit:self.selected];
  [node __setHighlightedFromUIKit:self.highlighted];
}

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  [_node __setSelectedFromUIKit:selected];
}

- (void)setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  [_node __setHighlightedFromUIKit:highlighted];
}

- (void)setLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  _layoutAttributes = layoutAttributes;
  _node.layoutAttributes = layoutAttributes;
}

- (void)prepareForReuse
{
  self.layoutAttributes = nil;

  // Need to clear node pointer before UIKit calls setSelected:NO / setHighlighted:NO on its cells
  self.node = nil;
  [super prepareForReuse];
}

/**
 * In the initial case, this is called by UICollectionView during cell dequeueing, before
 *   we get a chance to assign a node to it, so we must be sure to set these layout attributes
 *   on our node when one is next assigned to us in @c setNode: . Since there may be cases when we _do_ already
 *   have our node assigned e.g. during a layout update for existing cells, we also attempt
 *   to update it now.
 */
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  self.layoutAttributes = layoutAttributes;
}

@end

#pragma mark -
#pragma mark ASCollectionView.

@interface ASCollectionView () <ASRangeControllerDataSource, ASRangeControllerDelegate, ASCollectionDataControllerSource, ASCellNodeInteractionDelegate, ASDelegateProxyInterceptor, ASBatchFetchingScrollView, ASDataControllerEnvironmentDelegate, ASCALayerExtendedDelegate> {
  ASCollectionViewProxy *_proxyDataSource;
  ASCollectionViewProxy *_proxyDelegate;
  
  ASCollectionDataController *_dataController;
  ASRangeController *_rangeController;
  ASCollectionViewLayoutController *_layoutController;
  id<ASCollectionViewLayoutInspecting> _defaultLayoutInspector;
  __weak id<ASCollectionViewLayoutInspecting> _layoutInspector;
  NSMutableSet *_cellsForVisibilityUpdates;
  id<ASCollectionViewLayoutFacilitatorProtocol> _layoutFacilitator;
  
  BOOL _performingBatchUpdates;
  NSUInteger _superBatchUpdateCount;
  NSMutableArray *_batchUpdateBlocks;

  BOOL _isDeallocating;
  
  ASBatchContext *_batchContext;
  
  CGSize _lastBoundsSizeUsedForMeasuringNodes;
  BOOL _ignoreNextBoundsSizeChangeForMeasuringNodes;
  
  NSMutableSet *_registeredSupplementaryKinds;
  
  CGPoint _deceleratingVelocity;
  
  ASCollectionViewInvalidationStyle _nextLayoutInvalidationStyle;
  
  /**
   * Our layer, retained. Under iOS < 9, when collection views are removed from the hierarchy,
   * their layers may be deallocated and become dangling pointers. This puts the collection view
   * into a very dangerous state where pretty much any call will crash it. So we manually retain our layer.
   *
   * You should never access this, and it will be nil under iOS >= 9.
   */
  CALayer *_retainedLayer;
  
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

  /**
   * It's important that we always check for batch fetching at least once, but also
   * that we do not check for batch fetching for empty updates (as that may cause an infinite
   * loop of batch fetching, where the batch completes and performBatchUpdates: is called without
   * actually making any changes.) So to handle the case where a collection is completely empty
   * (0 sections) we always check at least once after each update (initial reload is the first update.)
   */
  BOOL _hasEverCheckedForBatchFetchingDueToUpdate;
    
  struct {
    unsigned int scrollViewDidScroll:1;
    unsigned int scrollViewWillBeginDragging:1;
    unsigned int scrollViewDidEndDragging:1;
    unsigned int scrollViewWillEndDragging:1;
    unsigned int collectionViewWillDisplayNodeForItem:1;
    unsigned int collectionViewWillDisplayNodeForItemDeprecated:1;
    unsigned int collectionViewDidEndDisplayingNodeForItem:1;
    unsigned int collectionViewShouldSelectItem:1;
    unsigned int collectionViewDidSelectItem:1;
    unsigned int collectionViewShouldDeselectItem:1;
    unsigned int collectionViewDidDeselectItem:1;
    unsigned int collectionViewShouldHighlightItem:1;
    unsigned int collectionViewDidHighlightItem:1;
    unsigned int collectionViewDidUnhighlightItem:1;
    unsigned int collectionViewShouldShowMenuForItem:1;
    unsigned int collectionViewCanPerformActionForItem:1;
    unsigned int collectionViewPerformActionForItem:1;
    unsigned int collectionViewWillBeginBatchFetch:1;
    unsigned int shouldBatchFetchForCollectionView:1;
    unsigned int collectionNodeWillDisplayItem:1;
    unsigned int collectionNodeDidEndDisplayingItem:1;
    unsigned int collectionNodeShouldSelectItem:1;
    unsigned int collectionNodeDidSelectItem:1;
    unsigned int collectionNodeShouldDeselectItem:1;
    unsigned int collectionNodeDidDeselectItem:1;
    unsigned int collectionNodeShouldHighlightItem:1;
    unsigned int collectionNodeDidHighlightItem:1;
    unsigned int collectionNodeDidUnhighlightItem:1;
    unsigned int collectionNodeShouldShowMenuForItem:1;
    unsigned int collectionNodeCanPerformActionForItem:1;
    unsigned int collectionNodePerformActionForItem:1;
    unsigned int collectionNodeWillBeginBatchFetch:1;
    unsigned int collectionNodeWillDisplaySupplementaryElement:1;
    unsigned int collectionNodeDidEndDisplayingSupplementaryElement:1;

    unsigned int shouldBatchFetchForCollectionNode:1;
  } _asyncDelegateFlags;
  
  struct {
    unsigned int collectionViewNodeForItem:1;
    unsigned int collectionViewNodeBlockForItem:1;
    unsigned int collectionViewNodeForSupplementaryElement:1;
    unsigned int numberOfSectionsInCollectionView:1;
    unsigned int collectionViewNumberOfItemsInSection:1;
    unsigned int collectionNodeNodeForItem:1;
    unsigned int collectionNodeNodeBlockForItem:1;
    unsigned int collectionNodeNodeForSupplementaryElement:1;
    unsigned int numberOfSectionsInCollectionNode:1;
    unsigned int collectionNodeNumberOfItemsInSection:1;
    unsigned int collectionNodeContextForSection:1;
  } _asyncDataSourceFlags;
  
  struct {
    unsigned int didChangeCollectionViewDataSource:1;
    unsigned int didChangeCollectionViewDelegate:1;
  } _layoutInspectorFlags;
}

@property (nonatomic, weak)   ASCollectionNode *collectionNode;

@end

@interface ASCollectionNode ()
- (instancetype)_initWithCollectionView:(ASCollectionView *)collectionView;
@end

@implementation ASCollectionView
{
  __weak id<ASCollectionDelegate> _asyncDelegate;
  __weak id<ASCollectionDataSource> _asyncDataSource;
}

// Using _ASDisplayLayer ensures things like -layout are properly forwarded to ASCollectionNode.
+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:CGRectZero collectionViewLayout:layout];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self _initWithFrame:frame collectionViewLayout:layout layoutFacilitator:nil eventLog:nil];
}

- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator eventLog:(ASEventLog *)eventLog
{
  if (!(self = [super initWithFrame:frame collectionViewLayout:layout]))
    return nil;
  
  _layoutController = [[ASCollectionViewLayoutController alloc] initWithCollectionView:self];
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.dataSource = self;
  _rangeController.delegate = self;
  _rangeController.layoutController = _layoutController;
  
  _dataController = [[ASCollectionDataController alloc] initWithDataSource:self eventLog:eventLog];
  _dataController.delegate = _rangeController;
  _dataController.environmentDelegate = self;
  
  _batchContext = [[ASBatchContext alloc] init];
  
  _leadingScreensForBatching = 2.0;
  
  _performingBatchUpdates = NO;
  _batchUpdateBlocks = [NSMutableArray array];
  
  _superIsPendingDataLoad = YES;
  
  _lastBoundsSizeUsedForMeasuringNodes = self.bounds.size;
  // If the initial size is 0, expect a size change very soon which is part of the initial configuration
  // and should not trigger a relayout.
  _ignoreNextBoundsSizeChangeForMeasuringNodes = CGSizeEqualToSize(_lastBoundsSizeUsedForMeasuringNodes, CGSizeZero);
  
  _layoutFacilitator = layoutFacilitator;
  
  _proxyDelegate = [[ASCollectionViewProxy alloc] initWithTarget:nil interceptor:self];
  super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
  
  _proxyDataSource = [[ASCollectionViewProxy alloc] initWithTarget:nil interceptor:self];
  super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
  
  _registeredSupplementaryKinds = [NSMutableSet set];
  
  _cellsForVisibilityUpdates = [NSMutableSet set];
  self.backgroundColor = [UIColor whiteColor];
  
  [self registerClass:[_ASCollectionViewCell class] forCellWithReuseIdentifier:kCellReuseIdentifier];
  
  if (!AS_AT_LEAST_IOS9) {
    _retainedLayer = self.layer;
  }
  
  return self;
}

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  // Sometimes the UIKit classes can call back to their delegate even during deallocation, due to animation completion blocks etc.
  _isDeallocating = YES;
  [self setAsyncDelegate:nil];
  [self setAsyncDataSource:nil];

  // Data controller & range controller may own a ton of nodes, let's deallocate those off-main.
  ASPerformBackgroundDeallocation(_dataController);
  ASPerformBackgroundDeallocation(_rangeController);
}

#pragma mark -
#pragma mark Overrides.

- (void)reloadDataWithCompletion:(void (^)())completion
{
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

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  if ([self validateIndexPath:indexPath]) {
    [super scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  }
}

- (void)reloadDataImmediately
{
  ASDisplayNodeAssertMainThread();
  _superIsPendingDataLoad = YES;
  [_dataController reloadDataImmediatelyWithAnimationOptions:kASCollectionViewAnimationNone];
  [super reloadData];
}

- (void)relayoutItems
{
  [_dataController relayoutAllNodes];
}

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  [_dataController waitUntilAllUpdatesAreCommitted];
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

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  if (proxy == _proxyDelegate) {
    [self setAsyncDelegate:nil];
  } else if (proxy == _proxyDataSource) {
    [self setAsyncDataSource:nil];
  }
}

- (id<ASCollectionDataSource>)asyncDataSource
{
  return _asyncDataSource;
}

- (void)setAsyncDataSource:(id<ASCollectionDataSource>)asyncDataSource
{
  // Changing super.dataSource will trigger a setNeedsLayout, so this must happen on the main thread.
  ASDisplayNodeAssertMainThread();

  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDataSource in the ViewController's dealloc. In this case our _asyncDataSource
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to hold a strong
  // reference to the old dataSource in this case because calls to ASCollectionViewProxy will start failing and cause crashes.
  NS_VALID_UNTIL_END_OF_SCOPE id oldDataSource = super.dataSource;
  
  if (asyncDataSource == nil) {
    _asyncDataSource = nil;
    _proxyDataSource = _isDeallocating ? nil : [[ASCollectionViewProxy alloc] initWithTarget:nil interceptor:self];
    
    memset(&_asyncDataSourceFlags, 0, sizeof(_asyncDataSourceFlags));
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[ASCollectionViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    
    _asyncDataSourceFlags.collectionViewNodeForItem = [_asyncDataSource respondsToSelector:@selector(collectionView:nodeForItemAtIndexPath:)];
    _asyncDataSourceFlags.collectionViewNodeBlockForItem = [_asyncDataSource respondsToSelector:@selector(collectionView:nodeBlockForItemAtIndexPath:)];
    _asyncDataSourceFlags.numberOfSectionsInCollectionView = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)];
    _asyncDataSourceFlags.collectionViewNumberOfItemsInSection = [_asyncDataSource respondsToSelector:@selector(collectionView:numberOfItemsInSection:)];
    _asyncDataSourceFlags.collectionViewNodeForSupplementaryElement = [_asyncDataSource respondsToSelector:@selector(collectionView:nodeForSupplementaryElementOfKind:atIndexPath:)];

    _asyncDataSourceFlags.collectionNodeNodeForItem = [_asyncDataSource respondsToSelector:@selector(collectionNode:nodeForItemAtIndexPath:)];
    _asyncDataSourceFlags.collectionNodeNodeBlockForItem = [_asyncDataSource respondsToSelector:@selector(collectionNode:nodeBlockForItemAtIndexPath:)];
    _asyncDataSourceFlags.numberOfSectionsInCollectionNode = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionNode:)];
    _asyncDataSourceFlags.collectionNodeNumberOfItemsInSection = [_asyncDataSource respondsToSelector:@selector(collectionNode:numberOfItemsInSection:)];
    _asyncDataSourceFlags.collectionNodeContextForSection = [_asyncDataSource respondsToSelector:@selector(collectionNode:contextForSection:)];
    _asyncDataSourceFlags.collectionNodeNodeForSupplementaryElement = [_asyncDataSource respondsToSelector:@selector(collectionNode:nodeForSupplementaryElementOfKind:atIndexPath:)];


    ASDisplayNodeAssert(_asyncDataSourceFlags.collectionNodeNumberOfItemsInSection || _asyncDataSourceFlags.collectionViewNumberOfItemsInSection, @"Data source must implement collectionNode:numberOfItemsInSection:");
    ASDisplayNodeAssert(_asyncDataSourceFlags.collectionNodeNodeBlockForItem
                        || _asyncDataSourceFlags.collectionNodeNodeForItem
                        || _asyncDataSourceFlags.collectionViewNodeBlockForItem
                        || _asyncDataSourceFlags.collectionViewNodeForItem, @"Data source must implement collectionNode:nodeBlockForItemAtIndexPath: or collectionNode:nodeForItemAtIndexPath:");
  }
  
  _dataController.validationErrorSource = asyncDataSource;
  super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
  
  //Cache results of layoutInspector to ensure flags are up to date if getter lazily loads a new one.
  id<ASCollectionViewLayoutInspecting> layoutInspector = self.layoutInspector;
  if (_layoutInspectorFlags.didChangeCollectionViewDataSource) {
    [layoutInspector didChangeCollectionViewDataSource:asyncDataSource];
  }
}

- (id<ASCollectionDelegate>)asyncDelegate
{
  return _asyncDelegate;
}

- (void)setAsyncDelegate:(id<ASCollectionDelegate>)asyncDelegate
{
  // Changing super.delegate will trigger a setNeedsLayout, so this must happen on the main thread.
  ASDisplayNodeAssertMainThread();

  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDelegate in the ViewController's dealloc. In this case our _asyncDelegate
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to hold a strong
  // reference to the old delegate in this case because calls to ASCollectionViewProxy will start failing and cause crashes.
  NS_VALID_UNTIL_END_OF_SCOPE id oldDelegate = super.delegate;
  
  if (asyncDelegate == nil) {
    _asyncDelegate = nil;
    _proxyDelegate = _isDeallocating ? nil : [[ASCollectionViewProxy alloc] initWithTarget:nil interceptor:self];
    
    memset(&_asyncDelegateFlags, 0, sizeof(_asyncDelegateFlags));
  } else {
    _asyncDelegate = asyncDelegate;
    _proxyDelegate = [[ASCollectionViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
    
    _asyncDelegateFlags.scrollViewDidScroll = [_asyncDelegate respondsToSelector:@selector(scrollViewDidScroll:)];
    _asyncDelegateFlags.scrollViewWillEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    _asyncDelegateFlags.scrollViewWillBeginDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _asyncDelegateFlags.scrollViewDidEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
    _asyncDelegateFlags.collectionViewWillDisplayNodeForItem = [_asyncDelegate respondsToSelector:@selector(collectionView:willDisplayNode:forItemAtIndexPath:)];
    if (_asyncDelegateFlags.collectionViewWillDisplayNodeForItem == NO) {
      _asyncDelegateFlags.collectionViewWillDisplayNodeForItemDeprecated = [_asyncDelegate respondsToSelector:@selector(collectionView:willDisplayNodeForItemAtIndexPath:)];
    }
    _asyncDelegateFlags.collectionViewDidEndDisplayingNodeForItem = [_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNode:forItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewWillBeginBatchFetch = [_asyncDelegate respondsToSelector:@selector(collectionView:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.shouldBatchFetchForCollectionView = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForCollectionView:)];
    _asyncDelegateFlags.collectionViewShouldSelectItem = [_asyncDelegate respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewDidSelectItem = [_asyncDelegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewShouldDeselectItem = [_asyncDelegate respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewDidDeselectItem = [_asyncDelegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewShouldHighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewDidHighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionView:didHighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewDidUnhighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewShouldShowMenuForItem = [_asyncDelegate respondsToSelector:@selector(collectionView:shouldShowMenuForItemAtIndexPath:)];
    _asyncDelegateFlags.collectionViewCanPerformActionForItem = [_asyncDelegate respondsToSelector:@selector(collectionView:canPerformAction:forItemAtIndexPath:withSender:)];
    _asyncDelegateFlags.collectionViewPerformActionForItem = [_asyncDelegate respondsToSelector:@selector(collectionView:performAction:forItemAtIndexPath:withSender:)];
    _asyncDelegateFlags.collectionNodeWillDisplayItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:willDisplayItemWithNode:)];
    _asyncDelegateFlags.collectionNodeDidEndDisplayingItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:didEndDisplayingItemWithNode:)];
    _asyncDelegateFlags.collectionNodeWillBeginBatchFetch = [_asyncDelegate respondsToSelector:@selector(collectionNode:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.shouldBatchFetchForCollectionNode = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForCollectionNode:)];
    _asyncDelegateFlags.collectionNodeShouldSelectItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:shouldSelectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeDidSelectItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:didSelectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeShouldDeselectItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:shouldDeselectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeDidDeselectItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:didDeselectItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeShouldHighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:shouldHighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeDidHighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:didHighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeDidUnhighlightItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:didUnhighlightItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeShouldShowMenuForItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:shouldShowMenuForItemAtIndexPath:)];
    _asyncDelegateFlags.collectionNodeCanPerformActionForItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:canPerformAction:forItemAtIndexPath:sender:)];
    _asyncDelegateFlags.collectionNodePerformActionForItem = [_asyncDelegate respondsToSelector:@selector(collectionNode:performAction:forItemAtIndexPath:sender:)];
  }

  super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
  
  //Cache results of layoutInspector to ensure flags are up to date if getter lazily loads a new one.
  id<ASCollectionViewLayoutInspecting> layoutInspector = self.layoutInspector;
  if (_layoutInspectorFlags.didChangeCollectionViewDelegate) {
    [layoutInspector didChangeCollectionViewDelegate:asyncDelegate];
  }
}

- (void)setCollectionViewLayout:(UICollectionViewLayout *)collectionViewLayout
{
  [super setCollectionViewLayout:collectionViewLayout];
  
  // Trigger recreation of layout inspector with new collection view layout
  if (_layoutInspector != nil) {
    _layoutInspector = nil;
    [self layoutInspector];
  }
}

- (id<ASCollectionViewLayoutInspecting>)layoutInspector
{
  if (_layoutInspector == nil) {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
    if (layout == nil) {
      // Layout hasn't been set yet, we're still init'ing
      return nil;
    }
    
    if ([layout asdk_isFlowLayout]) {
      // Register the default layout inspector delegate for flow layouts only
      _defaultLayoutInspector = [[ASCollectionViewFlowLayoutInspector alloc] initWithCollectionView:self flowLayout:layout];
    } else {
      // Register the default layout inspector delegate for custom collection view layouts
      _defaultLayoutInspector = [[ASCollectionViewLayoutInspector alloc] initWithCollectionView:self];
    }
    
    // Explicitly call the setter to wire up the _layoutInspectorFlags
    self.layoutInspector = _defaultLayoutInspector;
  }

  return _layoutInspector;
}

- (void)setLayoutInspector:(id<ASCollectionViewLayoutInspecting>)layoutInspector
{
  _layoutInspector = layoutInspector;
  
  _layoutInspectorFlags.didChangeCollectionViewDataSource = [_layoutInspector respondsToSelector:@selector(didChangeCollectionViewDataSource:)];
  _layoutInspectorFlags.didChangeCollectionViewDelegate = [_layoutInspector respondsToSelector:@selector(didChangeCollectionViewDelegate:)];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [_rangeController setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [_rangeController tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  [_rangeController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [_rangeController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [[self nodeForItemAtIndexPath:indexPath] calculatedSize];
}

- (NSArray<NSArray <ASCellNode *> *> *)completedNodes
{
  return [_dataController completedNodes];
}

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtCompletedIndexPath:indexPath];
}

- (NSIndexPath *)convertIndexPathFromCollectionNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait
{
  // If this is a section index path, we don't currently have a method
  // to do a mapping.
  if (indexPath.item == NSNotFound) {
    return indexPath;
  } else {
    ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
    NSIndexPath *viewIndexPath = [self indexPathForNode:node];
    if (viewIndexPath == nil && wait) {
      [self waitUntilAllUpdatesAreCommitted];
      viewIndexPath = [self indexPathForNode:node];
    }
    return viewIndexPath;
  }
}

/**
 * Asserts that the index path is a valid view-index-path, and returns it if so, nil otherwise.
 */
- (nullable NSIndexPath *)validateIndexPath:(nullable NSIndexPath *)indexPath
{
  if (indexPath == nil) {
    return nil;
  }

  NSInteger section = indexPath.section;
  if (section >= self.numberOfSections) {
    ASDisplayNodeFailAssert(@"Collection view index path has invalid section %lu, section count = %lu", (unsigned long)section, (unsigned long)self.numberOfSections);
    return nil;
  }

  NSInteger item = indexPath.item;
  // item == NSNotFound means e.g. "scroll to this section" and is acceptable
  if (item != NSNotFound && item >= [self numberOfItemsInSection:section]) {
    ASDisplayNodeFailAssert(@"Collection view index path has invalid item %lu in section %lu, item count = %lu", (unsigned long)indexPath.item, (unsigned long)section, (unsigned long)[self numberOfItemsInSection:section]);
    return nil;
  }

  return indexPath;
}

- (NSIndexPath *)convertIndexPathToCollectionNode:(NSIndexPath *)indexPath
{
  if ([self validateIndexPath:indexPath] == nil) {
    return nil;
  }

  // If this is a section index path, we don't currently have a method
  // to do a mapping.
  if (indexPath.item == NSNotFound) {
    return indexPath;
  } else {
    ASCellNode *node = [self nodeForItemAtIndexPath:indexPath];
    return [_dataController indexPathForNode:node];
  }
}

- (NSArray<NSIndexPath *> *)convertIndexPathsToCollectionNode:(NSArray<NSIndexPath *> *)indexPaths
{
  if (indexPaths == nil) {
    return nil;
  }

  NSMutableArray<NSIndexPath *> *indexPathsArray = [NSMutableArray arrayWithCapacity:indexPaths.count];

  for (NSIndexPath *indexPathInView in indexPaths) {
    NSIndexPath *indexPath = [self convertIndexPathToCollectionNode:indexPathInView];
    if (indexPath != nil) {
      [indexPathsArray addObject:indexPath];
    }
  }
  return indexPathsArray;
}

- (ASCellNode *)supplementaryNodeForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController supplementaryNodeOfKind:elementKind atIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self validateIndexPath:[_dataController completedIndexPathForNode:cellNode]];
}

- (NSArray *)visibleNodes
{
  NSArray *indexPaths = [self indexPathsForVisibleItems];
  NSMutableArray *visibleNodes = [[NSMutableArray alloc] init];
  
  for (NSIndexPath *indexPath in indexPaths) {
    ASCellNode *node = [self nodeForItemAtIndexPath:indexPath];
    if (node) {
      // It is possible for UICollectionView to return indexPaths before the node is completed.
      [visibleNodes addObject:node];
    }
  }
  
  return visibleNodes;
}

#pragma mark Internal

/**
 Performing nested batch updates with super (e.g. resizing a cell node & updating collection view during same frame)
 can cause super to throw data integrity exceptions because it checks the data source counts before
 the update is complete.
 
 Always call [self _superPerform:] rather than [super performBatch:] so that we can keep our `superPerformingBatchUpdates` flag updated.
*/
- (void)_superPerformBatchUpdates:(void(^)())updates completion:(void(^)(BOOL finished))completion
{
  ASDisplayNodeAssertMainThread();
  
  _superBatchUpdateCount++;
  [super performBatchUpdates:updates completion:completion];
  _superBatchUpdateCount--;
}

#pragma mark Assertions.

- (ASDataController *)dataController
{
  return _dataController;
}

- (void)performBatchAnimated:(BOOL)animated updates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  
  [_dataController beginUpdates];
  if (updates) {
    updates();
  }
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
  if (sections.count == 0) { return; }
  [_dataController insertSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [_dataController deleteSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [_dataController reloadSections:sections withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  [_dataController moveSection:section toSection:newSection withAnimationOptions:kASCollectionViewAnimationNone];
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [_dataController contextForSection:section];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:kASCollectionViewAnimationNone];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
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

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  _superIsPendingDataLoad = NO;
  return [_dataController completedNumberOfSections];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_dataController completedNumberOfRowsInSection:section];
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [[self nodeForItemAtIndexPath:indexPath] calculatedSize];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *identifier = [self __reuseIdentifierForKind:kind];
  UICollectionReusableView *view = [self dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:identifier forIndexPath:indexPath];
  ASCellNode *node = [_dataController supplementaryNodeOfKind:kind atIndexPath:indexPath];
  ASDisplayNodeAssert(node != nil, @"Supplementary node should exist.  Kind = %@, indexPath = %@, collectionDataSource = %@", kind, indexPath, self);
  [_rangeController configureContentView:view forCellNode:node];
  return view;
}



- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  _ASCollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:kCellReuseIdentifier forIndexPath:indexPath];
  
  ASCellNode *node = [self nodeForItemAtIndexPath:indexPath];
  cell.node = node;
  [_rangeController configureContentView:cell.contentView forCellNode:node];
  
  if (!AS_AT_LEAST_IOS8) {
    // Even though UICV was introduced in iOS 6, and UITableView has always had the equivalent method,
    // -willDisplayCell: was not introduced until iOS 8 for UICV.  didEndDisplayingCell, however, is available.
    [self collectionView:collectionView willDisplayCell:cell forItemAtIndexPath:indexPath];
  }
  
  return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(_ASCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *cellNode = [cell node];
  cellNode.scrollView = collectionView;
  
  // Under iOS 10+, cells may be removed/re-added to the collection view without
  // receiving prepareForReuse/applyLayoutAttributes, as an optimization for e.g.
  // if the user is scrolling back and forth across a small set of items.
  // In this case, we have to fetch the layout attributes manually.
  // This may be possible under iOS < 10 but it has not been observed yet.
  if (cell.layoutAttributes == nil) {
    cell.layoutAttributes = [collectionView layoutAttributesForItemAtIndexPath:indexPath];
  }

  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with cell that will be displayed not to be nil. indexPath: %@", indexPath);

  if (_asyncDelegateFlags.collectionNodeWillDisplayItem) {
    if (ASCollectionNode *collectionNode = self.collectionNode) {
    	[_asyncDelegate collectionNode:collectionNode willDisplayItemWithNode:cellNode];
    }
  } else if (_asyncDelegateFlags.collectionViewWillDisplayNodeForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self willDisplayNode:cellNode forItemAtIndexPath:indexPath];
  } else if (_asyncDelegateFlags.collectionViewWillDisplayNodeForItemDeprecated) {
    [_asyncDelegate collectionView:self willDisplayNodeForItemAtIndexPath:indexPath];
  }
#pragma clang diagnostic pop
  
  [_rangeController setNeedsUpdate];
  
  if (ASSubclassOverridesSelector([ASCellNode class], [cellNode class], @selector(cellNodeVisibilityEvent:inScrollView:withCellFrame:))) {
    [_cellsForVisibilityUpdates addObject:cell];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(_ASCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *cellNode = [cell node];
  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with removed cell not to be nil.");

  if (_asyncDelegateFlags.collectionNodeDidEndDisplayingItem) {
    if (ASCollectionNode *collectionNode = self.collectionNode) {
    	[_asyncDelegate collectionNode:collectionNode didEndDisplayingItemWithNode:cellNode];
    }
  } else if (_asyncDelegateFlags.collectionViewDidEndDisplayingNodeForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self didEndDisplayingNode:cellNode forItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  
  [_rangeController setNeedsUpdate];
  
  [_cellsForVisibilityUpdates removeObject:cell];
  
  cellNode.scrollView = nil;
  cell.layoutAttributes = nil;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeWillDisplaySupplementaryElement) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    ASCellNode *node = [self supplementaryNodeForElementKind:elementKind atIndexPath:indexPath];
    ASDisplayNodeAssert([node.supplementaryElementKind isEqualToString:elementKind], @"Expected node for supplementary element to have kind '%@', got '%@'.", elementKind, node.supplementaryElementKind);
    [_asyncDelegate collectionNode:collectionNode willDisplaySupplementaryElementWithNode:node];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeDidEndDisplayingSupplementaryElement) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    ASCellNode *node = [self supplementaryNodeForElementKind:elementKind atIndexPath:indexPath];
    ASDisplayNodeAssert([node.supplementaryElementKind isEqualToString:elementKind], @"Expected node for supplementary element to have kind '%@', got '%@'.", elementKind, node.supplementaryElementKind);
    [_asyncDelegate collectionNode:collectionNode didEndDisplayingSupplementaryElementWithNode:node];
  }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeShouldSelectItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate collectionNode:collectionNode shouldSelectItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewShouldSelectItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate collectionView:self shouldSelectItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeDidSelectItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate collectionNode:collectionNode didSelectItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewDidSelectItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self didSelectItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeShouldDeselectItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate collectionNode:collectionNode shouldDeselectItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewShouldDeselectItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate collectionView:self shouldDeselectItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeDidDeselectItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate collectionNode:collectionNode didDeselectItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewDidDeselectItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self didDeselectItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeShouldHighlightItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate collectionNode:collectionNode shouldHighlightItemAtIndexPath:indexPath];
    } else {
      return YES;
    }
  } else if (_asyncDelegateFlags.collectionViewShouldHighlightItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate collectionView:self shouldHighlightItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeDidHighlightItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate collectionNode:collectionNode didHighlightItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewDidHighlightItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self didHighlightItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeDidUnhighlightItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate collectionNode:collectionNode didUnhighlightItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewDidUnhighlightItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self didUnhighlightItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.collectionNodeShouldShowMenuForItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate collectionNode:collectionNode shouldShowMenuForItemAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.collectionViewShouldShowMenuForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate collectionView:self shouldShowMenuForItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(nonnull SEL)action forItemAtIndexPath:(nonnull NSIndexPath *)indexPath withSender:(nullable id)sender
{
  if (_asyncDelegateFlags.collectionNodeCanPerformActionForItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate collectionNode:collectionNode canPerformAction:action forItemAtIndexPath:indexPath sender:sender];
    }
  } else if (_asyncDelegateFlags.collectionViewCanPerformActionForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate collectionView:self canPerformAction:action forItemAtIndexPath:indexPath withSender:sender];
#pragma clang diagnostic pop
  }
  return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(nonnull SEL)action forItemAtIndexPath:(nonnull NSIndexPath *)indexPath withSender:(nullable id)sender
{
  if (_asyncDelegateFlags.collectionNodePerformActionForItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
    indexPath = [self convertIndexPathToCollectionNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate collectionNode:collectionNode performAction:action forItemAtIndexPath:indexPath sender:sender];
    }
  } else if (_asyncDelegateFlags.collectionViewPerformActionForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate collectionView:self performAction:action forItemAtIndexPath:indexPath withSender:sender];
#pragma clang diagnostic pop
  }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  // If a scroll happenes the current range mode needs to go to full
  ASInterfaceState interfaceState = [self interfaceStateForRangeController:_rangeController];
  if (ASInterfaceStateIncludesVisible(interfaceState)) {
    [_rangeController updateCurrentRangeWithMode:ASLayoutRangeModeFull];
    [self _checkForBatchFetching];
  }
  
  for (_ASCollectionViewCell *collectionCell in _cellsForVisibilityUpdates) {
    // Only nodes that respond to the selector are added to _cellsForVisibilityUpdates
    [[collectionCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventVisibleRectChanged
                                      inScrollView:scrollView
                                     withCellFrame:collectionCell.frame];
  }
  if (_asyncDelegateFlags.scrollViewDidScroll) {
    [_asyncDelegate scrollViewDidScroll:scrollView];
  }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
  CGPoint contentOffset = scrollView.contentOffset;
  _deceleratingVelocity = CGPointMake(
    contentOffset.x - ((targetContentOffset != NULL) ? targetContentOffset->x : 0),
    contentOffset.y - ((targetContentOffset != NULL) ? targetContentOffset->y : 0)
  );

  if (targetContentOffset != NULL) {
    ASDisplayNodeAssert(_batchContext != nil, @"Batch context should exist");
    [self _beginBatchFetchingIfNeededWithContentOffset:*targetContentOffset];
  }
  
  if (_asyncDelegateFlags.scrollViewWillEndDragging) {
    [_asyncDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:(targetContentOffset ? : &contentOffset)];
  }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  for (_ASCollectionViewCell *collectionCell in _cellsForVisibilityUpdates) {
    [[collectionCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventWillBeginDragging
                                          inScrollView:scrollView
                                         withCellFrame:collectionCell.frame];
  }
  if (_asyncDelegateFlags.scrollViewWillBeginDragging) {
    [_asyncDelegate scrollViewWillBeginDragging:scrollView];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    for (_ASCollectionViewCell *collectionCell in _cellsForVisibilityUpdates) {
        [[collectionCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventDidEndDragging
                                          inScrollView:scrollView
                                         withCellFrame:collectionCell.frame];
    }
    if (_asyncDelegateFlags.scrollViewDidEndDragging) {
        [_asyncDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

#pragma mark - Scroll Direction.

- (ASScrollDirection)scrollDirection
{
  CGPoint scrollVelocity;
  if (self.isTracking) {
    scrollVelocity = [self.panGestureRecognizer velocityInView:self.superview];
  } else {
    scrollVelocity = _deceleratingVelocity;
  }
  
  ASScrollDirection scrollDirection = [self _scrollDirectionForVelocity:scrollVelocity];
  return ASScrollDirectionApplyTransform(scrollDirection, self.transform);
}

- (ASScrollDirection)_scrollDirectionForVelocity:(CGPoint)scrollVelocity
{
  ASScrollDirection direction = ASScrollDirectionNone;
  ASScrollDirection scrollableDirections = [self scrollableDirections];
  
  if (ASScrollDirectionContainsHorizontalDirection(scrollableDirections)) { // Can scroll horizontally.
    if (scrollVelocity.x < 0.0) {
      direction |= ASScrollDirectionRight;
    } else if (scrollVelocity.x > 0.0) {
      direction |= ASScrollDirectionLeft;
    }
  }
  if (ASScrollDirectionContainsVerticalDirection(scrollableDirections)) { // Can scroll vertically.
    if (scrollVelocity.y < 0.0) {
      direction |= ASScrollDirectionDown;
    } else if (scrollVelocity.y > 0.0) {
      direction |= ASScrollDirectionUp;
    }
  }
  
  return direction;
}

- (ASScrollDirection)scrollableDirections
{
  ASDisplayNodeAssertNotNil(self.layoutInspector, @"Layout inspector should be assigned.");
  return [self.layoutInspector scrollableDirections];
}

- (ASScrollDirection)flowLayoutScrollableDirections:(UICollectionViewFlowLayout *)flowLayout {
  return (flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) ? ASScrollDirectionHorizontalDirections : ASScrollDirectionVerticalDirections;
}

- (void)layoutSubviews
{
  // Flush any pending invalidation action if needed.
  ASCollectionViewInvalidationStyle invalidationStyle = _nextLayoutInvalidationStyle;
  _nextLayoutInvalidationStyle = ASCollectionViewInvalidationStyleNone;
  switch (invalidationStyle) {
    case ASCollectionViewInvalidationStyleWithAnimation:
      if (0 == _superBatchUpdateCount) {
        [self _superPerformBatchUpdates:^{ } completion:nil];
      }
      break;
    case ASCollectionViewInvalidationStyleWithoutAnimation:
      [self.collectionViewLayout invalidateLayout];
      break;
    default:
      break;
  }
  
  // To ensure _maxSizeForNodesConstrainedSize is up-to-date for every usage, this call to super must be done last
  [super layoutSubviews];
    
  if (_zeroContentInsets) {
    self.contentInset = UIEdgeInsetsZero;
  }
  
  // Update range controller immediately if possible & needed.
  // Calling -updateIfNeeded in here with self.window == nil (early in the collection view's life)
  // may cause UICollectionView data related crashes. We'll update in -didMoveToWindow anyway.
  if (self.window != nil) {
    [_rangeController updateIfNeeded];
  }
}


#pragma mark - Batch Fetching

- (ASBatchContext *)batchContext
{
  return _batchContext;
}

- (BOOL)canBatchFetch
{
  // if the delegate does not respond to this method, there is no point in starting to fetch
  BOOL canFetch = _asyncDelegateFlags.collectionNodeWillBeginBatchFetch || _asyncDelegateFlags.collectionViewWillBeginBatchFetch;
  if (canFetch && _asyncDelegateFlags.shouldBatchFetchForCollectionNode) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, NO);
    return [_asyncDelegate shouldBatchFetchForCollectionNode:collectionNode];
  } else if (canFetch && _asyncDelegateFlags.shouldBatchFetchForCollectionView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate shouldBatchFetchForCollectionView:self];
#pragma clang diagnostic pop
  } else {
    return canFetch;
  }
}

- (void)_scheduleCheckForBatchFetchingForNumberOfChanges:(NSUInteger)changes
{
  // Prevent fetching will continually trigger in a loop after reaching end of content and no new content was provided
  if (changes == 0 && _hasEverCheckedForBatchFetchingDueToUpdate) {
    return;
  }
  _hasEverCheckedForBatchFetchingDueToUpdate = YES;
  
  // Push this to the next runloop to be sure the scroll view has the right content size
  dispatch_async(dispatch_get_main_queue(), ^{
    [self _checkForBatchFetching];
  });
}

- (void)_checkForBatchFetching
{
  // Dragging will be handled in scrollViewWillEndDragging:withVelocity:targetContentOffset:
  if (self.isDragging || self.isTracking) {
    return;
  }
  
  [self _beginBatchFetchingIfNeededWithContentOffset:self.contentOffset];
}

- (void)_beginBatchFetchingIfNeededWithContentOffset:(CGPoint)contentOffset
{
  if (ASDisplayShouldFetchBatchForScrollView(self, self.scrollDirection, self.scrollableDirections, contentOffset)) {
    [self _beginBatchFetching];
  }
}

- (void)_beginBatchFetching
{
  [_batchContext beginBatchFetching];
  if (_asyncDelegateFlags.collectionNodeWillBeginBatchFetch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      GET_COLLECTIONNODE_OR_RETURN(collectionNode, (void)0);
      [_asyncDelegate collectionNode:collectionNode willBeginBatchFetchWithContext:_batchContext];
    });
  } else if (_asyncDelegateFlags.collectionViewWillBeginBatchFetch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      [_asyncDelegate collectionView:self willBeginBatchFetchWithContext:_batchContext];
#pragma clang diagnostic pop
    });
  }
}


#pragma mark - ASDataControllerSource

- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath {
  ASCellNodeBlock block = nil;

  if (_asyncDataSourceFlags.collectionNodeNodeBlockForItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, ^{ return [[ASCellNode alloc] init]; });
    block = [_asyncDataSource collectionNode:collectionNode nodeBlockForItemAtIndexPath:indexPath];
  } else if (_asyncDataSourceFlags.collectionNodeNodeForItem) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, ^{ return [[ASCellNode alloc] init]; });
    ASCellNode *node = [_asyncDataSource collectionNode:collectionNode nodeForItemAtIndexPath:indexPath];
    if ([node isKindOfClass:[ASCellNode class]]) {
      block = ^{
        return node;
      };
    } else {
      ASDisplayNodeFailAssert(@"Data source returned invalid node from tableNode:nodeForRowAtIndexPath:. Node: %@", node);
    }
  } else if (_asyncDataSourceFlags.collectionViewNodeBlockForItem) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    block = [_asyncDataSource collectionView:self nodeBlockForItemAtIndexPath:indexPath];
  } else if (_asyncDataSourceFlags.collectionViewNodeForItem) {
    ASCellNode *node = [_asyncDataSource collectionView:self nodeForItemAtIndexPath:indexPath];
#pragma clang diagnostic pop
    if ([node isKindOfClass:[ASCellNode class]]) {
      block = ^{
        return node;
      };
    } else {
      ASDisplayNodeFailAssert(@"Data source returned invalid node from tableView:nodeForRowAtIndexPath:. Node: %@", node);
    }
  }

  // Handle nil node block
  if (block == nil) {
    ASDisplayNodeFailAssert(@"ASTableNode could not get a node block for row at index path %@", indexPath);
    block = ^{
      return [[ASCellNode alloc] init];
    };
  }

  // Wrap the node block
  __weak __typeof__(self) weakSelf = self;
  return ^{
    __typeof__(self) strongSelf = weakSelf;
    ASCellNode *node = (block != nil ? block() : [[ASCellNode alloc] init]);
    [node enterHierarchyState:ASHierarchyStateRangeManaged];
    if (node.interactionDelegate == nil) {
      node.interactionDelegate = strongSelf;
    }
    return node;
  };
  return block;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [self.layoutInspector collectionView:self constrainedSizeForNodeAtIndexPath:indexPath];
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  if (_asyncDataSourceFlags.collectionNodeNumberOfItemsInSection) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, 0);
    return [_asyncDataSource collectionNode:collectionNode numberOfItemsInSection:section];
  } else if (_asyncDataSourceFlags.collectionViewNumberOfItemsInSection) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDataSource collectionView:self numberOfItemsInSection:section];
#pragma clang diagnostic pop
  } else {
    return 0;
  }
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController {
  if (_asyncDataSourceFlags.numberOfSectionsInCollectionNode) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, 0);
    return [_asyncDataSource numberOfSectionsInCollectionNode:collectionNode];
  } else if (_asyncDataSourceFlags.numberOfSectionsInCollectionView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDataSource numberOfSectionsInCollectionView:self];
#pragma clang diagnostic pop
  } else {
    return 1;
  }
}

- (id<ASEnvironment>)dataControllerEnvironment
{
  return self.collectionNode;
}

#pragma mark - ASCollectionViewDataControllerSource

- (ASCellNode *)dataController:(ASCollectionDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = nil;
  if (_asyncDataSourceFlags.collectionNodeNodeForSupplementaryElement) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, [[ASCellNode alloc] init] );
    node = [_asyncDataSource collectionNode:collectionNode nodeForSupplementaryElementOfKind:kind atIndexPath:indexPath];
  } else if (_asyncDataSourceFlags.collectionViewNodeForSupplementaryElement) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    node = [_asyncDataSource collectionView:self nodeForSupplementaryElementOfKind:kind atIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  ASDisplayNodeAssert(node != nil, @"A node must be returned for supplementary element of kind '%@' at index path '%@'", kind, indexPath);
  return node;
}

// TODO: Lock this
- (NSArray *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController
{
  return [_registeredSupplementaryKinds allObjects];
}

- (ASSizeRange)dataController:(ASCollectionDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  return [self.layoutInspector collectionView:self constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:indexPath];
}

- (NSUInteger)dataController:(ASCollectionDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  if (_asyncDataSource == nil) {
    return 0;
  }

  return [self.layoutInspector collectionView:self supplementaryNodesOfKind:kind inSection:section];
}

- (id<ASSectionContext>)dataController:(ASDataController *)dataController contextForSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  id<ASSectionContext> context = nil;
  
  if (_asyncDataSourceFlags.collectionNodeContextForSection) {
    GET_COLLECTIONNODE_OR_RETURN(collectionNode, nil);
    context = [_asyncDataSource collectionNode:collectionNode contextForSection:section];
  }
  
  if (context != nil) {
    context.collectionView = self;
  }
  return context;
}

#pragma mark - ASRangeControllerDataSource

- (ASRangeController *)rangeController
{
  return _rangeController;
}

- (NSArray *)visibleNodeIndexPathsForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  // Calling -indexPathsForVisibleItems will trigger UIKit to call reloadData if it never has, which can result
  // in incorrect layout if performed at zero size.  We can use the fact that nothing can be visible at zero size to return fast.
  BOOL isZeroSized = CGSizeEqualToSize(self.bounds.size, CGSizeZero);
  return isZeroSized ? @[] : [self indexPathsForVisibleItems];
}

- (ASScrollDirection)scrollDirectionForRangeController:(ASRangeController *)rangeController
{
  return self.scrollDirection;
}

- (CGSize)viewportSizeForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
}

- (ASInterfaceState)interfaceStateForRangeController:(ASRangeController *)rangeController
{
  return ASInterfaceStateForDisplayNode(self.collectionNode, self.window);
}

- (ASDisplayNode *)rangeController:(ASRangeController *)rangeController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [self nodeForItemAtIndexPath:indexPath];
}

- (NSString *)nameForRangeControllerDataSource
{
  return self.asyncDataSource ? NSStringFromClass([self.asyncDataSource class]) : NSStringFromClass([self class]);
}

#pragma mark - ASRangeControllerDelegate

- (void)didBeginUpdatesInRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  _performingBatchUpdates = YES;
}

- (void)rangeController:(ASRangeController *)rangeController didEndUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    if (completion) {
      completion(NO);
    }
    _performingBatchUpdates = NO;
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  ASPerformBlockWithoutAnimation(!animated, ^{
    NSUInteger numberOfUpdateBlocks = _batchUpdateBlocks.count;
    [_layoutFacilitator collectionViewWillPerformBatchUpdates];
    [self _superPerformBatchUpdates:^{
      for (dispatch_block_t block in _batchUpdateBlocks) {
        block();
      }
    } completion:^(BOOL finished){
      // Flush any range changes that happened as part of the update animations ending.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:numberOfUpdateBlocks];
      if (completion) { completion(finished); }
    }];
    // Flush any range changes that happened as part of submitting the update.
    [_rangeController updateIfNeeded];
  });
  
  [_batchUpdateBlocks removeAllObjects];
  _performingBatchUpdates = NO;
}

- (void)rangeController:(ASRangeController *)rangeController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  [_layoutFacilitator collectionViewWillEditCellsAtIndexPaths:indexPaths batched:_performingBatchUpdates];
  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super insertItemsAtIndexPaths:indexPaths];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super insertItemsAtIndexPaths:indexPaths];
      // Flush any range changes that happened as part of submitting the update.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexPaths.count];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  [_layoutFacilitator collectionViewWillEditCellsAtIndexPaths:indexPaths batched:_performingBatchUpdates];
  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super deleteItemsAtIndexPaths:indexPaths];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super deleteItemsAtIndexPaths:indexPaths];
      // Flush any range changes that happened as part of submitting the update.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexPaths.count];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  [_layoutFacilitator collectionViewWillEditSectionsAtIndexSet:indexSet batched:_performingBatchUpdates];
  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super insertSections:indexSet];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super insertSections:indexSet];
      // Flush any range changes that happened as part of submitting the update.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexSet.count];
    }];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _superIsPendingDataLoad) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  [_layoutFacilitator collectionViewWillEditSectionsAtIndexSet:indexSet batched:_performingBatchUpdates];
  if (_performingBatchUpdates) {
    [_batchUpdateBlocks addObject:^{
      [super deleteSections:indexSet];
    }];
  } else {
    [UIView performWithoutAnimation:^{
      [super deleteSections:indexSet];
      // Flush any range changes that happened as part of submitting the update.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexSet.count];
    }];
  }
}

#pragma mark - ASCellNodeDelegate
- (void)nodeSelectedStateDidChange:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath) {
    if (node.isSelected) {
      [super selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    } else {
      [super deselectItemAtIndexPath:indexPath animated:NO];
    }
  }
}

- (void)nodeHighlightedStateDidChange:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath) {
    [self cellForItemAtIndexPath:indexPath].highlighted = node.isHighlighted;
  }
}

- (void)nodeDidRelayout:(ASCellNode *)node sizeChanged:(BOOL)sizeChanged
{
  ASDisplayNodeAssertMainThread();
  
  if (!sizeChanged) {
    return;
  }
  
  NSIndexPath *uikitIndexPath = [self indexPathForNode:node];
  if (uikitIndexPath == nil) {
    return;
  }

  [_layoutFacilitator collectionViewWillEditCellsAtIndexPaths:@[ uikitIndexPath ] batched:NO];
  
  ASCollectionViewInvalidationStyle invalidationStyle = _nextLayoutInvalidationStyle;
  if (invalidationStyle == ASCollectionViewInvalidationStyleNone) {
    [self setNeedsLayout];
    invalidationStyle = ASCollectionViewInvalidationStyleWithAnimation;
  }

  // If we think we're going to animate, check if this node will prevent it.
  if (invalidationStyle == ASCollectionViewInvalidationStyleWithAnimation) {
    // TODO: Incorporate `shouldAnimateSizeChanges` into ASEnvironmentState for performance benefit.
    static dispatch_once_t onceToken;
    static BOOL (^shouldNotAnimateBlock)(ASDisplayNode *);
    dispatch_once(&onceToken, ^{
      shouldNotAnimateBlock = ^BOOL(ASDisplayNode * _Nonnull node) {
        return (node.shouldAnimateSizeChanges == NO);
      };
    });
    if (ASDisplayNodeFindFirstNode(node, shouldNotAnimateBlock) != nil) {
      // One single non-animated node causes the whole layout update to be non-animated
      invalidationStyle = ASCollectionViewInvalidationStyleWithoutAnimation;
    }
  }
  
  _nextLayoutInvalidationStyle = invalidationStyle;
}

#pragma mark - _ASDisplayView behavior substitutions
// Need these to drive interfaceState so we know when we are visible, if not nested in another range-managing element.
// Because our superclass is a true UIKit class, we cannot also subclass _ASDisplayView.
- (void)willMoveToWindow:(UIWindow *)newWindow
{
  BOOL visible = (newWindow != nil);
  ASDisplayNode *node = self.collectionNode;
  if (visible && !node.inHierarchy) {
    [node __enterHierarchy];
  }
}

- (void)didMoveToWindow
{
  BOOL visible = (self.window != nil);
  ASDisplayNode *node = self.collectionNode;
  if (!visible && node.inHierarchy) {
    [node __exitHierarchy];
  }

  // Updating the visible node index paths only for not range managed nodes. Range managed nodes will get their
  // their update in the layout pass
  if (![node supportsRangeManagedInterfaceState]) {
    [_rangeController setNeedsUpdate];
    [_rangeController updateIfNeeded];
  }

  // When we aren't visible, we will only fetch up to the visible area. Now that we are visible,
  // we will fetch visible area + leading screens, so we need to check.
  if (visible) {
    [self _checkForBatchFetching];
  }
}

#pragma mark ASCALayerExtendedDelegate

/**
 * UICollectionView inadvertently triggers a -prepareLayout call to its layout object
 * between [super setFrame:] and [self layoutSubviews] during size changes. So we need
 * to get in there and re-measure our nodes before that -prepareLayout call.
 * We can't wait until -layoutSubviews or the end of -setFrame:.
 *
 * @see @p testThatNodeCalculatedSizesAreUpdatedBeforeFirstPrepareLayoutAfterRotation
 */
- (void)layer:(CALayer *)layer didChangeBoundsWithOldValue:(CGRect)oldBounds newValue:(CGRect)newBounds
{
  if (self.collectionViewLayout == nil) {
    return;
  }
  CGSize lastUsedSize = _lastBoundsSizeUsedForMeasuringNodes;
  if (CGSizeEqualToSize(lastUsedSize, newBounds.size)) {
    return;
  }
  _lastBoundsSizeUsedForMeasuringNodes = newBounds.size;

  // First size change occurs during initial configuration. An expensive relayout pass is unnecessary at that time
  // and should be avoided, assuming that the initial data loading automatically runs shortly afterward.
  if (_ignoreNextBoundsSizeChangeForMeasuringNodes) {
    _ignoreNextBoundsSizeChangeForMeasuringNodes = NO;
  } else {
    // Laying out all nodes is expensive, and performing an empty update may be unsafe
    // if the data source has pending changes that it hasn't reported yet – the collection
    // view will requery the new counts and expect them to match the previous counts.
    //
    // We only need to do this if the bounds changed in the non-scrollable direction.
    // If, for example, a vertical flow layout has its height changed due to a status bar
    // appearance update, we do not need to relayout all nodes.
    // For a more permanent fix to the unsafety mentioned above, see https://github.com/facebook/AsyncDisplayKit/pull/2182
    ASScrollDirection scrollDirection = self.scrollableDirections;
    BOOL fixedVertically = (ASScrollDirectionContainsVerticalDirection(scrollDirection) == NO);
    BOOL fixedHorizontally = (ASScrollDirectionContainsHorizontalDirection(scrollDirection) == NO);

    BOOL changedInNonScrollingDirection = (fixedHorizontally && newBounds.size.width != lastUsedSize.width) || (fixedVertically && newBounds.size.height != lastUsedSize.height);

    if (changedInNonScrollingDirection) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      // This actually doesn't perform an animation, but prevents the transaction block from being processed in the
      // data controller's prevent animation block that would interrupt an interrupted relayout happening in an animation block
      // ie. ASCollectionView bounds change on rotation or multi-tasking split view resize.
      [self performBatchAnimated:YES updates:^{
        [_dataController relayoutAllNodes];
      } completion:nil];
      // We need to ensure the size requery is done before we update our layout.
      [self waitUntilAllUpdatesAreCommitted];
      [self.collectionViewLayout invalidateLayout];
    }
#pragma clang diagnostic pop
  }
}

#pragma mark - UICollectionView dead-end intercepts

#if ASDISPLAYNODE_ASSERTIONS_ENABLED // Remove implementations entirely for efficiency if not asserting.

// intercepted due to not being supported by ASCollectionView (prevent bugs caused by usage)

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath NS_AVAILABLE_IOS(9_0)
{
  ASDisplayNodeAssert(![self.asyncDataSource respondsToSelector:_cmd], @"%@ is not supported by ASCollectionView - please remove or disable this data source method.", NSStringFromSelector(_cmd));
  return NO;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath*)destinationIndexPath NS_AVAILABLE_IOS(9_0)
{
  ASDisplayNodeAssert(![self.asyncDataSource respondsToSelector:_cmd], @"%@ is not supported by ASCollectionView - please remove or disable this data source method.", NSStringFromSelector(_cmd));
}

#endif

@end

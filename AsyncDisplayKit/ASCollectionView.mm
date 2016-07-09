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
#import "ASDisplayNode+Beta.h"
#import "ASInternalHelpers.h"
#import "UICollectionViewLayout+ASConvenience.h"
#import "ASRangeController.h"
#import "ASCollectionNode.h"
#import "_ASDisplayLayer.h"
#import "ASCollectionViewLayoutFacilitatorProtocol.h"


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
static const ASSizeRange kInvalidSizeRange = {CGSizeZero, CGSizeZero};
static NSString * const kCellReuseIdentifier = @"_ASCollectionViewCell";

#pragma mark -
#pragma mark ASCellNode<->UICollectionViewCell bridging.

@class _ASCollectionViewCell;

@interface _ASCollectionViewCell : UICollectionViewCell
@property (nonatomic, weak) ASCellNode *node;
@end

@implementation _ASCollectionViewCell

- (void)setNode:(ASCellNode *)node
{
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

- (void)prepareForReuse
{
  // Need to clear node pointer before UIKit calls setSelected:NO / setHighlighted:NO on its cells
  self.node = nil;
  [super prepareForReuse];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  [_node applyLayoutAttributes:layoutAttributes];
}

@end

#pragma mark -
#pragma mark ASCollectionView.

@interface ASCollectionView () <ASRangeControllerDataSource, ASRangeControllerDelegate, ASDataControllerSource, ASCellNodeInteractionDelegate, ASDelegateProxyInterceptor, ASBatchFetchingScrollView, ASDataControllerEnvironmentDelegate> {
  ASCollectionViewProxy *_proxyDataSource;
  ASCollectionViewProxy *_proxyDelegate;
  
  ASCollectionDataController *_dataController;
  ASRangeController *_rangeController;
  ASCollectionViewLayoutController *_layoutController;
  ASCollectionViewFlowLayoutInspector *_flowLayoutInspector;
  NSMutableSet *_cellsForVisibilityUpdates;
  id<ASCollectionViewLayoutFacilitatorProtocol> _layoutFacilitator;
  
  BOOL _performingBatchUpdates;
  BOOL _superPerformingBatchUpdates;
  NSMutableArray *_batchUpdateBlocks;

  BOOL _isDeallocating;
  
  ASBatchContext *_batchContext;
  
  CGSize _maxSizeForNodesConstrainedSize;
  BOOL _ignoreMaxSizeChange;
  
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
    
  struct {
    unsigned int asyncDelegateScrollViewDidScroll:1;
    unsigned int asyncDelegateScrollViewWillBeginDragging:1;
    unsigned int asyncDelegateScrollViewDidEndDragging:1;
    unsigned int asyncDelegateScrollViewWillEndDraggingWithVelocityTargetContentOffset:1;
    unsigned int asyncDelegateCollectionViewWillDisplayNodeForItemAtIndexPath:1;
    unsigned int asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPath:1;
    unsigned int asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPathDeprecated:1;
    unsigned int asyncDelegateCollectionViewWillBeginBatchFetchWithContext:1;
    unsigned int asyncDelegateShouldBatchFetchForCollectionView:1;
  } _asyncDelegateFlags;
  
  struct {
    unsigned int asyncDataSourceConstrainedSizeForNode:1;
    unsigned int asyncDataSourceNodeForItemAtIndexPath:1;
    unsigned int asyncDataSourceNodeBlockForItemAtIndexPath:1;
    unsigned int asyncDataSourceNumberOfSectionsInCollectionView:1;
    unsigned int asyncDataSourceCollectionViewConstrainedSizeForNodeAtIndexPath:1;
  } _asyncDataSourceFlags;
}

// Used only when ASCollectionView is created directly rather than through ASCollectionNode.
// We create a node so that logic related to appearance, memory management, etc can be located there
// for both the node-based and view-based version of the table.
// This also permits sharing logic with ASTableNode, as the superclass is not UIKit-controlled.
@property (nonatomic, strong) ASCollectionNode *strongCollectionNode;

// Always set, whether ASCollectionView is created directly or via ASCollectionNode.
@property (nonatomic, weak)   ASCollectionNode *collectionNode;

@end

@interface ASCollectionNode ()
- (instancetype)_initWithCollectionView:(ASCollectionView *)collectionView;
@end

@implementation ASCollectionView

// Using _ASDisplayLayer ensures things like -layout are properly forwarded to ASCollectionNode.
+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self _initWithFrame:CGRectZero collectionViewLayout:layout ownedByNode:NO];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self _initWithFrame:frame collectionViewLayout:layout ownedByNode:NO];
}

// FIXME: This method is deprecated and will probably be removed in or shortly after 2.0.
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  return [self _initWithFrame:frame collectionViewLayout:layout ownedByNode:NO];
}

- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout ownedByNode:(BOOL)ownedByNode
{
  return [self _initWithFrame:frame collectionViewLayout:layout layoutFacilitator:nil ownedByNode:ownedByNode];
}

- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator ownedByNode:(BOOL)ownedByNode
{
  if (!(self = [super initWithFrame:frame collectionViewLayout:layout]))
    return nil;
  
  if (!ownedByNode) {
    // See commentary at the definition of .strongCollectionNode for why we create an ASCollectionNode.
    // FIXME: The _view pointer of the node retains us, but the node will die immediately if we don't
    // retain it.  At the moment there isn't a great solution to this, so we can't yet move our core
    // logic to ASCollectionNode (required to have a shared superclass with ASTable*).
    ASCollectionNode *collectionNode = nil; //[[ASCollectionNode alloc] _initWithCollectionView:self];
    self.strongCollectionNode = collectionNode;
  }
  
  _layoutController = [[ASCollectionViewLayoutController alloc] initWithCollectionView:self];
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.dataSource = self;
  _rangeController.delegate = self;
  _rangeController.layoutController = _layoutController;
  
  _dataController = [[ASCollectionDataController alloc] init];
  _dataController.delegate = _rangeController;
  _dataController.dataSource = self;
  _dataController.environmentDelegate = self;
  
  _batchContext = [[ASBatchContext alloc] init];
  
  _leadingScreensForBatching = 2.0;
  
  _performingBatchUpdates = NO;
  _batchUpdateBlocks = [NSMutableArray array];
  
  _superIsPendingDataLoad = YES;
  
  _maxSizeForNodesConstrainedSize = self.bounds.size;
  // If the initial size is 0, expect a size change very soon which is part of the initial configuration
  // and should not trigger a relayout.
  _ignoreMaxSizeChange = CGSizeEqualToSize(_maxSizeForNodesConstrainedSize, CGSizeZero);
  
  // Register the default layout inspector delegate for flow layouts only, custom layouts
  // will need to roll their own ASCollectionViewLayoutInspecting implementation and set a layout delegate
  if ([layout asdk_isFlowLayout]) {
    _layoutInspector = [self flowLayoutInspector];
  }
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
  // Sometimes the UIKit classes can call back to their delegate even during deallocation, due to animation completion blocks etc.
  _isDeallocating = YES;
  [self setAsyncDelegate:nil];
  [self setAsyncDataSource:nil];
}

/**
 * A layout inspector implementation specific for the sizing behavior of UICollectionViewFlowLayouts
 */
- (ASCollectionViewFlowLayoutInspector *)flowLayoutInspector
{
  if (_flowLayoutInspector == nil) {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionViewLayout;
    ASDisplayNodeAssertNotNil(layout, @"Collection view layout must be a flow layout to use the built-in inspector");
    _flowLayoutInspector = [[ASCollectionViewFlowLayoutInspector alloc] initWithCollectionView:self flowLayout:layout];
  }
  return _flowLayoutInspector;
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

- (void)setAsyncDataSource:(id<ASCollectionViewDataSource>)asyncDataSource
{
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
    
    _asyncDataSourceFlags.asyncDataSourceConstrainedSizeForNode = [_asyncDataSource respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)];
    _asyncDataSourceFlags.asyncDataSourceNodeForItemAtIndexPath = [_asyncDataSource respondsToSelector:@selector(collectionView:nodeForItemAtIndexPath:)];
    _asyncDataSourceFlags.asyncDataSourceNodeBlockForItemAtIndexPath = [_asyncDataSource respondsToSelector:@selector(collectionView:nodeBlockForItemAtIndexPath:)];
    _asyncDataSourceFlags.asyncDataSourceNumberOfSectionsInCollectionView = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)];
    _asyncDataSourceFlags.asyncDataSourceCollectionViewConstrainedSizeForNodeAtIndexPath = [_asyncDataSource respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)];

    // Data-source must implement collectionView:nodeForItemAtIndexPath: or collectionView:nodeBlockForItemAtIndexPath:
    ASDisplayNodeAssertTrue(_asyncDataSourceFlags.asyncDataSourceNodeBlockForItemAtIndexPath || _asyncDataSourceFlags.asyncDataSourceNodeForItemAtIndexPath);
  }
  
  super.dataSource = (id<UICollectionViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASCollectionViewDelegate>)asyncDelegate
{
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
    
    _asyncDelegateFlags.asyncDelegateScrollViewDidScroll = [_asyncDelegate respondsToSelector:@selector(scrollViewDidScroll:)];
    _asyncDelegateFlags.asyncDelegateScrollViewWillEndDraggingWithVelocityTargetContentOffset = [_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    _asyncDelegateFlags.asyncDelegateCollectionViewWillDisplayNodeForItemAtIndexPath = [_asyncDelegate respondsToSelector:@selector(collectionView:willDisplayNodeForItemAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPathDeprecated = [_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNodeForItemAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPath = [_asyncDelegate respondsToSelector:@selector(collectionView:didEndDisplayingNode:forItemAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateCollectionViewWillBeginBatchFetchWithContext = [_asyncDelegate respondsToSelector:@selector(collectionView:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.asyncDelegateShouldBatchFetchForCollectionView = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForCollectionView:)];
    _asyncDelegateFlags.asyncDelegateScrollViewWillBeginDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _asyncDelegateFlags.asyncDelegateScrollViewDidEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
  }

  super.delegate = (id<UICollectionViewDelegate>)_proxyDelegate;
  
  [_layoutInspector didChangeCollectionViewDelegate:asyncDelegate];
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
  return [[_dataController nodeAtIndexPath:indexPath] calculatedSize];
}

- (NSArray<NSArray <ASCellNode *> *> *)completedNodes
{
  return [_dataController completedNodes];
}

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

- (ASCellNode *)supplementaryNodeForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController supplementaryNodeOfKind:elementKind atIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [_dataController indexPathForNode:cellNode];
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
  ASDisplayNodeAssert(_superPerformingBatchUpdates == NO, @"Nested batch updates being sent to UICollectionView. This is not expected.");
  
  _superPerformingBatchUpdates = YES;
  [super performBatchUpdates:updates completion:completion];
  _superPerformingBatchUpdates = NO;
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
  return [_dataController numberOfSections];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_dataController numberOfRowsInSection:section];
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
  ASDisplayNodeAssert(node != nil, @"Supplementary node should exist.  Kind = %@, indexPath = %@, collectionDataSource = %@", kind, indexPath, self);
  [_rangeController configureContentView:view forCellNode:node];
  return view;
}



- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  _ASCollectionViewCell *cell = [self dequeueReusableCellWithReuseIdentifier:kCellReuseIdentifier forIndexPath:indexPath];
  
  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
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
  
  if (_asyncDelegateFlags.asyncDelegateCollectionViewWillDisplayNodeForItemAtIndexPath) {
    [_asyncDelegate collectionView:self willDisplayNodeForItemAtIndexPath:indexPath];
  }
  
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
  
  if (cellNode.neverShowPlaceholders) {
    [cellNode recursivelyEnsureDisplaySynchronously:YES];
  }
  if (ASSubclassOverridesSelector([ASCellNode class], [cellNode class], @selector(cellNodeVisibilityEvent:inScrollView:withCellFrame:))) {
    [_cellsForVisibilityUpdates addObject:cell];
  }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(_ASCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
  
  ASCellNode *cellNode = [cell node];

  if (_asyncDelegateFlags.asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPath) {
    ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with removed cell not to be nil.");
    [_asyncDelegate collectionView:self didEndDisplayingNode:cellNode forItemAtIndexPath:indexPath];
  }
  
  if ([_cellsForVisibilityUpdates containsObject:cell]) {
    [_cellsForVisibilityUpdates removeObject:cell];
  }
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (_asyncDelegateFlags.asyncDelegateCollectionViewDidEndDisplayingNodeForItemAtIndexPathDeprecated) {
    [_asyncDelegate collectionView:self didEndDisplayingNodeForItemAtIndexPath:indexPath];
  }
#pragma clang diagnostic pop
  
  cellNode.scrollView = nil;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  // If a scroll happenes the current range mode needs to go to full
  ASInterfaceState interfaceState = [self interfaceStateForRangeController:_rangeController];
  if (ASInterfaceStateIncludesVisible(interfaceState)) {
    [_rangeController updateCurrentRangeWithMode:ASLayoutRangeModeFull];
  }
  
  for (_ASCollectionViewCell *collectionCell in _cellsForVisibilityUpdates) {
    // Only nodes that respond to the selector are added to _cellsForVisibilityUpdates
    [[collectionCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventVisibleRectChanged
                                      inScrollView:scrollView
                                     withCellFrame:collectionCell.frame];
  }
  if (_asyncDelegateFlags.asyncDelegateScrollViewDidScroll) {
    [_asyncDelegate scrollViewDidScroll:scrollView];
  }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
  _deceleratingVelocity = CGPointMake(
    scrollView.contentOffset.x - ((targetContentOffset != NULL) ? targetContentOffset->x : 0),
    scrollView.contentOffset.y - ((targetContentOffset != NULL) ? targetContentOffset->y : 0)
  );

  if (targetContentOffset != NULL) {
    ASDisplayNodeAssert(_batchContext != nil, @"Batch context should exist");
    [self _beginBatchFetchingIfNeededWithScrollView:self forScrollDirection:[self scrollDirection] contentOffset:*targetContentOffset];
  }
  
  if (_asyncDelegateFlags.asyncDelegateScrollViewWillEndDraggingWithVelocityTargetContentOffset) {
    [_asyncDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
  }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  for (_ASCollectionViewCell *collectionCell in _cellsForVisibilityUpdates) {
    [[collectionCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventWillBeginDragging
                                          inScrollView:scrollView
                                         withCellFrame:collectionCell.frame];
  }
  if (_asyncDelegateFlags.asyncDelegateScrollViewWillBeginDragging) {
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
    if (_asyncDelegateFlags.asyncDelegateScrollViewDidEndDragging) {
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
  CGFloat totalContentWidth = self.contentSize.width + self.contentInset.left + self.contentInset.right;
  CGFloat totalContentHeight = self.contentSize.height + self.contentInset.top + self.contentInset.bottom;
  
  if (self.alwaysBounceHorizontal || totalContentWidth > self.bounds.size.width) { // Can scroll horizontally.
    scrollableDirection |= ASScrollDirectionHorizontalDirections;
  }
  if (self.alwaysBounceVertical || totalContentHeight > self.bounds.size.height) { // Can scroll vertically.
    scrollableDirection |= ASScrollDirectionVerticalDirections;
  }
  return scrollableDirection;
}

- (void)layoutSubviews
{
  if (_zeroContentInsets) {
    self.contentInset = UIEdgeInsetsZero;
  }
  
  if (! CGSizeEqualToSize(_maxSizeForNodesConstrainedSize, self.bounds.size)) {
    _maxSizeForNodesConstrainedSize = self.bounds.size;
    
    // First size change occurs during initial configuration. An expensive relayout pass is unnecessary at that time
    // and should be avoided, assuming that the initial data loading automatically runs shortly afterward.
    if (_ignoreMaxSizeChange) {
      _ignoreMaxSizeChange = NO;
    } else {
      // This actually doesn't perform an animation, but prevents the transaction block from being processed in the
      // data controller's prevent animation block that would interrupt an interrupted relayout happening in an animation block
      // ie. ASCollectionView bounds change on rotation or multi-tasking split view resize.
      [self performBatchAnimated:YES updates:^{
        [_dataController relayoutAllNodes];
      } completion:nil];
      // We need to ensure the size requery is done before we update our layout.
      [self waitUntilAllUpdatesAreCommitted];
    }
  }
  
  // Flush any pending invalidation action if needed.
  ASCollectionViewInvalidationStyle invalidationStyle = _nextLayoutInvalidationStyle;
  _nextLayoutInvalidationStyle = ASCollectionViewInvalidationStyleNone;
  switch (invalidationStyle) {
    case ASCollectionViewInvalidationStyleWithAnimation:
      if (!_superPerformingBatchUpdates) {
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
}


#pragma mark - Batch Fetching

- (ASBatchContext *)batchContext
{
  return _batchContext;
}

- (BOOL)canBatchFetch
{
  // if the delegate does not respond to this method, there is no point in starting to fetch
  BOOL canFetch = _asyncDelegateFlags.asyncDelegateCollectionViewWillBeginBatchFetchWithContext;
  if (canFetch && _asyncDelegateFlags.asyncDelegateShouldBatchFetchForCollectionView) {
    return [_asyncDelegate shouldBatchFetchForCollectionView:self];
  } else {
    return canFetch;
  }
}

- (void)_scheduleCheckForBatchFetchingForNumberOfChanges:(NSUInteger)changes
{
  // Prevent fetching will continually trigger in a loop after reaching end of content and no new content was provided
  if (changes == 0) {
    return;
  }
  
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
  
  [self _beginBatchFetchingIfNeededWithScrollView:self forScrollDirection:[self scrollableDirections] contentOffset:self.contentOffset];
}

- (void)_beginBatchFetchingIfNeededWithScrollView:(UIScrollView<ASBatchFetchingScrollView> *)scrollView forScrollDirection:(ASScrollDirection)scrollDirection contentOffset:(CGPoint)contentOffset
{
  if (ASDisplayShouldFetchBatchForScrollView(self, scrollDirection, contentOffset)) {
    [self _beginBatchFetching];
  }
}

- (void)_beginBatchFetching
{
  [_batchContext beginBatchFetching];
  if (_asyncDelegateFlags.asyncDelegateCollectionViewWillBeginBatchFetchWithContext) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [_asyncDelegate collectionView:self willBeginBatchFetchWithContext:_batchContext];
    });
  }
}


#pragma mark - ASDataControllerSource

- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath
{
  if (!_asyncDataSourceFlags.asyncDataSourceNodeBlockForItemAtIndexPath) {
    ASCellNode *node = [_asyncDataSource collectionView:self nodeForItemAtIndexPath:indexPath];
    ASDisplayNodeAssert([node isKindOfClass:ASCellNode.class], @"invalid node class, expected ASCellNode");
    __weak __typeof__(self) weakSelf = self;
    return ^{
      __typeof__(self) strongSelf = weakSelf;
      [node enterHierarchyState:ASHierarchyStateRangeManaged];
      if (node.interactionDelegate == nil) {
        node.interactionDelegate = strongSelf;
      }
      return node;
    };
  }

  ASCellNodeBlock block = [_asyncDataSource collectionView:self nodeBlockForItemAtIndexPath:indexPath];
  ASDisplayNodeAssertNotNil(block, @"Invalid block, expected nonnull ASCellNodeBlock");
  __weak __typeof__(self) weakSelf = self;
  return ^{
    __typeof__(self) strongSelf = weakSelf;

    ASCellNode *node = block();
    [node enterHierarchyState:ASHierarchyStateRangeManaged];
    if (node.interactionDelegate == nil) {
      node.interactionDelegate = strongSelf;
    }
    return node;
  };
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange constrainedSize = kInvalidSizeRange;
  if (_layoutInspector) {
    constrainedSize = [_layoutInspector collectionView:self constrainedSizeForNodeAtIndexPath:indexPath];
  }
  
  if (!ASSizeRangeEqualToSizeRange(constrainedSize, kInvalidSizeRange)) {
    return constrainedSize;
  }
  
  // TODO: Move this logic into the flow layout inspector. Create a simple inspector for non-flow layouts that don't
  // implement a custom inspector.
  if (_asyncDataSourceFlags.asyncDataSourceConstrainedSizeForNode) {
    constrainedSize = [_asyncDataSource collectionView:self constrainedSizeForNodeAtIndexPath:indexPath];
  } else {
    CGSize maxSize = CGSizeEqualToSize(_maxSizeForNodesConstrainedSize, CGSizeZero) ? self.bounds.size : _maxSizeForNodesConstrainedSize;
    if (ASScrollDirectionContainsHorizontalDirection([self scrollableDirections])) {
      maxSize.width = FLT_MAX;
    } else {
      maxSize.height = FLT_MAX;
    }
    constrainedSize = ASSizeRangeMake(CGSizeZero, maxSize);
  }
  
  return constrainedSize;
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  return [_asyncDataSource collectionView:self numberOfItemsInSection:section];
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController {
  if (_asyncDataSourceFlags.asyncDataSourceNumberOfSectionsInCollectionView) {
    return [_asyncDataSource numberOfSectionsInCollectionView:self];
  } else {
    return 1;
  }
}

- (id<ASEnvironment>)dataControllerEnvironment
{
  if (self.collectionNode) {
    return self.collectionNode;
  }
  return self.strongCollectionNode;
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

#pragma mark - ASRangeControllerDataSource

- (ASRangeController *)rangeController
{
  return _rangeController;
}

- (NSArray *)visibleNodeIndexPathsForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  
  // Calling visibleNodeIndexPathsForRangeController: will trigger UIKit to call reloadData if it never has, which can result
  // in incorrect layout if performed at zero size.  We can use the fact that nothing can be visible at zero size to return fast.
  BOOL isZeroSized = CGRectEqualToRect(self.bounds, CGRectZero);
  return isZeroSized ? @[] : [self indexPathsForVisibleItems];
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

- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths
{
  return [_dataController nodesAtIndexPaths:indexPaths];
}

- (ASDisplayNode *)rangeController:(ASRangeController *)rangeController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
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
  NSUInteger numberOfUpdateBlocks = _batchUpdateBlocks.count;
  if (numberOfUpdateBlocks == 0 || !self.asyncDataSource || _superIsPendingDataLoad) {
    if (completion) {
      completion(NO);
    }
    _performingBatchUpdates = NO;
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  ASPerformBlockWithoutAnimation(!animated, ^{
    [_layoutFacilitator collectionViewWillPerformBatchUpdates];
    [self _superPerformBatchUpdates:^{
      for (dispatch_block_t block in _batchUpdateBlocks) {
        block();
      }
    } completion:^(BOOL finished){
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:numberOfUpdateBlocks];
      if (completion) { completion(finished); }
    }];
  });
  
  [_batchUpdateBlocks removeAllObjects];
  _performingBatchUpdates = NO;
}

- (void)didCompleteUpdatesInRangeController:(ASRangeController *)rangeController
{
  [self _checkForBatchFetching];
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
      [self selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    } else {
      [self deselectItemAtIndexPath:indexPath animated:NO];
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
  
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath == nil) {
    return;
  }

  [_layoutFacilitator collectionViewWillEditCellsAtIndexPaths:@[ indexPath ] batched:NO];
  
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

#pragma mark - Memory Management

- (void)clearContents
{
  [_rangeController clearContents];
}

- (void)clearFetchedData
{
  [_rangeController clearFetchedData];
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
    [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];
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

- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(![self.asyncDataSource respondsToSelector:_cmd], @"%@ is not supported by ASCollectionView - please remove or disable this delegate method.", NSStringFromSelector(_cmd));
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingSupplementaryView:(UICollectionReusableView *)view forElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(![self.asyncDataSource respondsToSelector:_cmd], @"%@ is not supported by ASCollectionView - please remove or disable this delegate method.", NSStringFromSelector(_cmd));
}

#endif

@end

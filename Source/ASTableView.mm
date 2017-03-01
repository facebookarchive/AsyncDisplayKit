//
//  ASTableView.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableViewInternal.h>

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASBatchFetching.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASDelegateProxy.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASTableNode.h>
#import <AsyncDisplayKit/ASRangeController.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASTableLayoutController.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>
#import <AsyncDisplayKit/ASBatchContext.h>

static NSString * const kCellReuseIdentifier = @"_ASTableViewCell";

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

/**
 * See note at the top of ASCollectionView.mm near declaration of macro GET_COLLECTIONNODE_OR_RETURN
 */
#define GET_TABLENODE_OR_RETURN(__var, __val) \
  ASTableNode *__var = self.tableNode; \
  if (__var == nil) { \
    return __val; \
  }

#pragma mark -
#pragma mark ASCellNode<->UITableViewCell bridging.

@class _ASTableViewCell;

@protocol _ASTableViewCellDelegate <NSObject>
- (void)didLayoutSubviewsOfTableViewCell:(_ASTableViewCell *)tableViewCell;
@end

@interface _ASTableViewCell : UITableViewCell
@property (nonatomic, weak) id<_ASTableViewCellDelegate> delegate;
@property (nonatomic, weak) ASCellNode *node;
@end

@implementation _ASTableViewCell
// TODO add assertions to prevent use of view-backed UITableViewCell properties (eg .textLabel)

- (void)layoutSubviews
{
  [super layoutSubviews];
  [_delegate didLayoutSubviewsOfTableViewCell:self];
}

- (void)didTransitionToState:(UITableViewCellStateMask)state
{
  [self setNeedsLayout];
  [self layoutIfNeeded];
  [super didTransitionToState:state];
}

- (void)setNode:(ASCellNode *)node
{
  _node = node;
  
  if (node) {
    self.backgroundColor = node.backgroundColor;
    self.selectionStyle = node.selectionStyle;
    self.selectedBackgroundView = node.selectedBackgroundView;
    self.separatorInset = node.separatorInset;
    self.selectionStyle = node.selectionStyle;
    self.accessoryType = node.accessoryType;
    
    // the following ensures that we clip the entire cell to it's bounds if node.clipsToBounds is set (the default)
    // This is actually a workaround for a bug we are seeing in some rare cases (selected background view
    // overlaps other cells if size of ASCellNode has changed.)
    self.clipsToBounds = node.clipsToBounds;
  }
  
  [node __setSelectedFromUIKit:self.selected];
  [node __setHighlightedFromUIKit:self.highlighted];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];
  [_node __setSelectedFromUIKit:selected];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
  [super setHighlighted:highlighted animated:animated];
  [_node __setHighlightedFromUIKit:highlighted];
}

- (void)prepareForReuse
{
  // Need to clear node pointer before UIKit calls setSelected:NO / setHighlighted:NO on its cells
  self.node = nil;
  [super prepareForReuse];
}

@end

#pragma mark -
#pragma mark ASTableView

@interface ASTableView () <ASRangeControllerDataSource, ASRangeControllerDelegate, ASDataControllerSource, _ASTableViewCellDelegate, ASCellNodeInteractionDelegate, ASDelegateProxyInterceptor, ASBatchFetchingScrollView, ASDataControllerEnvironmentDelegate>
{
  ASTableViewProxy *_proxyDataSource;
  ASTableViewProxy *_proxyDelegate;

  ASTableLayoutController *_layoutController;

  ASRangeController *_rangeController;

  ASBatchContext *_batchContext;

  // When we update our data controller in response to an interactive move,
  // we don't want to tell the table view about the change (it knows!)
  BOOL _updatingInResponseToInteractiveMove;

  // The top cell node that was visible before the update.
  __weak ASCellNode *_contentOffsetAdjustmentTopVisibleNode;
  // The y-offset of the top visible row's origin before the update.
  CGFloat _contentOffsetAdjustmentTopVisibleNodeOffset;
  
  CGPoint _deceleratingVelocity;
  
  /**
   * Our layer, retained. Under iOS < 9, when table views are removed from the hierarchy,
   * their layers may be deallocated and become dangling pointers. This puts the table view
   * into a very dangerous state where pretty much any call will crash it. So we manually retain our layer.
   *
   * You should never access this, and it will be nil under iOS >= 9.
   */
  CALayer *_retainedLayer;

  CGFloat _nodesConstrainedWidth;
  BOOL _queuedNodeHeightUpdate;
  BOOL _isDeallocating;
  NSMutableSet *_cellsForVisibilityUpdates;
  
  BOOL _remeasuringCellNodes;
  NSMutableSet *_cellsForLayoutUpdates;

  // See documentation on same property in ASCollectionView
  BOOL _hasEverCheckedForBatchFetchingDueToUpdate;

  // The section index overlay view, if there is one present.
  // This is useful because we need to measure our row nodes against (width - indexView.width).
  __weak UIView *_sectionIndexView;
  
  /**
   * The change set that we're currently building, if any.
   */
  _ASHierarchyChangeSet *_changeSet;
  
  /**
   * Counter used to keep track of nested batch updates.
   */
  NSInteger _batchUpdateCount;
  
  struct {
    unsigned int scrollViewDidScroll:1;
    unsigned int scrollViewWillBeginDragging:1;
    unsigned int scrollViewDidEndDragging:1;
    unsigned int scrollViewWillEndDragging:1;
    unsigned int scrollViewDidEndDecelerating:1;
    unsigned int tableNodeWillDisplayNodeForRow:1;
    unsigned int tableViewWillDisplayNodeForRow:1;
    unsigned int tableViewWillDisplayNodeForRowDeprecated:1;
    unsigned int tableNodeDidEndDisplayingNodeForRow:1;
    unsigned int tableViewDidEndDisplayingNodeForRow:1;
    unsigned int tableNodeWillBeginBatchFetch:1;
    unsigned int tableViewWillBeginBatchFetch:1;
    unsigned int shouldBatchFetchForTableView:1;
    unsigned int shouldBatchFetchForTableNode:1;
    unsigned int tableViewConstrainedSizeForRow:1;
    unsigned int tableNodeConstrainedSizeForRow:1;
    unsigned int tableViewWillSelectRow:1;
    unsigned int tableNodeWillSelectRow:1;
    unsigned int tableViewDidSelectRow:1;
    unsigned int tableNodeDidSelectRow:1;
    unsigned int tableViewWillDeselectRow:1;
    unsigned int tableNodeWillDeselectRow:1;
    unsigned int tableViewDidDeselectRow:1;
    unsigned int tableNodeDidDeselectRow:1;
    unsigned int tableViewShouldHighlightRow:1;
    unsigned int tableNodeShouldHighlightRow:1;
    unsigned int tableViewDidHighlightRow:1;
    unsigned int tableNodeDidHighlightRow:1;
    unsigned int tableViewDidUnhighlightRow:1;
    unsigned int tableNodeDidUnhighlightRow:1;
    unsigned int tableViewShouldShowMenuForRow:1;
    unsigned int tableNodeShouldShowMenuForRow:1;
    unsigned int tableViewCanPerformActionForRow:1;
    unsigned int tableNodeCanPerformActionForRow:1;
    unsigned int tableViewPerformActionForRow:1;
    unsigned int tableNodePerformActionForRow:1;
  } _asyncDelegateFlags;
  
  struct {
    unsigned int numberOfSectionsInTableView:1;
    unsigned int numberOfSectionsInTableNode:1;
    unsigned int tableNodeNumberOfRowsInSection:1;
    unsigned int tableViewNumberOfRowsInSection:1;
    unsigned int tableViewNodeBlockForRow:1;
    unsigned int tableNodeNodeBlockForRow:1;
    unsigned int tableViewNodeForRow:1;
    unsigned int tableNodeNodeForRow:1;
    unsigned int tableViewCanMoveRow:1;
    unsigned int tableNodeCanMoveRow:1;
    unsigned int tableViewMoveRow:1;
    unsigned int tableNodeMoveRow:1;
    unsigned int sectionIndexMethods:1; // if both section index methods are implemented
  } _asyncDataSourceFlags;
}

@property (nonatomic, strong, readwrite) ASDataController *dataController;

@property (nonatomic, weak)   ASTableNode *tableNode;

@property (nonatomic) BOOL test_enableSuperUpdateCallLogging;
@end

@implementation ASTableView
{
  __weak id<ASTableDelegate> _asyncDelegate;
  __weak id<ASTableDataSource> _asyncDataSource;
}

// Using _ASDisplayLayer ensures things like -layout are properly forwarded to ASTableNode.
+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

+ (Class)dataControllerClass
{
  return [ASDataController class];
}

#pragma mark -
#pragma mark Lifecycle

- (void)configureWithDataControllerClass:(Class)dataControllerClass eventLog:(ASEventLog *)eventLog
{
  _layoutController = [[ASTableLayoutController alloc] initWithTableView:self];
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.layoutController = _layoutController;
  _rangeController.dataSource = self;
  _rangeController.delegate = self;
  
  _dataController = [[dataControllerClass alloc] initWithDataSource:self eventLog:eventLog];
  _dataController.delegate = _rangeController;
  _dataController.environmentDelegate = self;

  _leadingScreensForBatching = 2.0;
  _batchContext = [[ASBatchContext alloc] init];

  _automaticallyAdjustsContentOffset = NO;
  
  _nodesConstrainedWidth = self.bounds.size.width;
  
  _proxyDelegate = [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
  
  _proxyDataSource = [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
  
  [self registerClass:_ASTableViewCell.class forCellReuseIdentifier:kCellReuseIdentifier];
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  return [self _initWithFrame:frame style:style dataControllerClass:nil eventLog:nil];
}

- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass eventLog:(ASEventLog *)eventLog
{
  if (!(self = [super initWithFrame:frame style:style])) {
    return nil;
  }
  _cellsForVisibilityUpdates = [NSMutableSet set];
  _cellsForLayoutUpdates = [NSMutableSet set];
  if (!dataControllerClass) {
    dataControllerClass = [[self class] dataControllerClass];
  }
  
  [self configureWithDataControllerClass:dataControllerClass eventLog:eventLog];
  
  if (!AS_AT_LEAST_IOS9) {
    _retainedLayer = self.layer;
  }
  
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  NSLog(@"Warning: AsyncDisplayKit is not designed to be used with Interface Builder.  Table properties set in IB will be lost.");
  return [self initWithFrame:CGRectZero style:UITableViewStylePlain];
}

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeCAssert(_batchUpdateCount == 0, @"ASTableView deallocated in the middle of a batch update.");
  
  // Sometimes the UIKit classes can call back to their delegate even during deallocation.
  _isDeallocating = YES;
  [self setAsyncDelegate:nil];
  [self setAsyncDataSource:nil];

  // Data controller & range controller may own a ton of nodes, let's deallocate those off-main
  ASPerformBackgroundDeallocation(_dataController);
  ASPerformBackgroundDeallocation(_rangeController);
}

#pragma mark -
#pragma mark Overrides

- (void)setDataSource:(id<UITableViewDataSource>)dataSource
{
  // UIKit can internally generate a call to this method upon changing the asyncDataSource; only assert for non-nil.
  ASDisplayNodeAssert(dataSource == nil, @"ASTableView uses asyncDataSource, not UITableView's dataSource property.");
}

- (void)setDelegate:(id<UITableViewDelegate>)delegate
{
  // Our UIScrollView superclass sets its delegate to nil on dealloc. Only assert if we get a non-nil value here.
  ASDisplayNodeAssert(delegate == nil, @"ASTableView uses asyncDelegate, not UITableView's delegate property.");
}

- (id<ASTableDataSource>)asyncDataSource
{
  return _asyncDataSource;
}

- (void)setAsyncDataSource:(id<ASTableDataSource>)asyncDataSource
{
  // Changing super.dataSource will trigger a setNeedsLayout, so this must happen on the main thread.
  ASDisplayNodeAssertMainThread();

  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDataSource in the ViewController's dealloc. In this case our _asyncDataSource
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to hold a strong
  // reference to the old dataSource in this case because calls to ASTableViewProxy will start failing and cause crashes.
  NS_VALID_UNTIL_END_OF_SCOPE id oldDataSource = self.dataSource;
  
  if (asyncDataSource == nil) {
    _asyncDataSource = nil;
    _proxyDataSource = _isDeallocating ? nil : [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
    
    memset(&_asyncDataSourceFlags, 0, sizeof(_asyncDataSourceFlags));
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[ASTableViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    
    _asyncDataSourceFlags.numberOfSectionsInTableView = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)];
    _asyncDataSourceFlags.numberOfSectionsInTableNode = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableNode:)];
    _asyncDataSourceFlags.tableViewNumberOfRowsInSection = [_asyncDataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)];
    _asyncDataSourceFlags.tableNodeNumberOfRowsInSection = [_asyncDataSource respondsToSelector:@selector(tableNode:numberOfRowsInSection:)];
    _asyncDataSourceFlags.tableViewNodeForRow = [_asyncDataSource respondsToSelector:@selector(tableView:nodeForRowAtIndexPath:)];
    _asyncDataSourceFlags.tableNodeNodeForRow = [_asyncDataSource respondsToSelector:@selector(tableNode:nodeForRowAtIndexPath:)];
    _asyncDataSourceFlags.tableViewNodeBlockForRow = [_asyncDataSource respondsToSelector:@selector(tableView:nodeBlockForRowAtIndexPath:)];
    _asyncDataSourceFlags.tableNodeNodeBlockForRow = [_asyncDataSource respondsToSelector:@selector(tableNode:nodeBlockForRowAtIndexPath:)];
    _asyncDataSourceFlags.tableViewCanMoveRow = [_asyncDataSource respondsToSelector:@selector(tableView:canMoveRowAtIndexPath:)];
    _asyncDataSourceFlags.tableViewMoveRow = [_asyncDataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)];
    _asyncDataSourceFlags.sectionIndexMethods = [_asyncDataSource respondsToSelector:@selector(sectionIndexTitlesForTableView:)] && [_asyncDataSource respondsToSelector:@selector(tableView:sectionForSectionIndexTitle:atIndex:)];
    
    ASDisplayNodeAssert(_asyncDataSourceFlags.tableViewNodeBlockForRow
                        || _asyncDataSourceFlags.tableViewNodeForRow
                        || _asyncDataSourceFlags.tableNodeNodeBlockForRow
                        || _asyncDataSourceFlags.tableNodeNodeForRow, @"Data source must implement tableNode:nodeBlockForRowAtIndexPath: or tableNode:nodeForRowAtIndexPath:");
    ASDisplayNodeAssert(_asyncDataSourceFlags.tableNodeNumberOfRowsInSection || _asyncDataSourceFlags.tableViewNumberOfRowsInSection, @"Data source must implement tableNode:numberOfRowsInSection:");
  }
  
  _dataController.validationErrorSource = asyncDataSource;
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
}

- (id<ASTableDelegate>)asyncDelegate
{
  return _asyncDelegate;
}

- (void)setAsyncDelegate:(id<ASTableDelegate>)asyncDelegate
{
  // Changing super.delegate will trigger a setNeedsLayout, so this must happen on the main thread.
  ASDisplayNodeAssertMainThread();

  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDelegate in the ViewController's dealloc. In this case our _asyncDelegate
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to hold a strong
  // reference to the old delegate in this case because calls to ASTableViewProxy will start failing and cause crashes.
  NS_VALID_UNTIL_END_OF_SCOPE id oldDelegate = super.delegate;
  
  if (asyncDelegate == nil) {
    _asyncDelegate = nil;
    _proxyDelegate = _isDeallocating ? nil : [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
    
    memset(&_asyncDelegateFlags, 0, sizeof(_asyncDelegateFlags));
  } else {
    _asyncDelegate = asyncDelegate;
    _proxyDelegate = [[ASTableViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
    
    _asyncDelegateFlags.scrollViewDidScroll = [_asyncDelegate respondsToSelector:@selector(scrollViewDidScroll:)];

    _asyncDelegateFlags.tableViewWillDisplayNodeForRow = [_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNode:forRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeWillDisplayNodeForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:willDisplayRowWithNode:)];
    if (_asyncDelegateFlags.tableViewWillDisplayNodeForRow == NO) {
      _asyncDelegateFlags.tableViewWillDisplayNodeForRowDeprecated = [_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)];
    }
    _asyncDelegateFlags.tableViewDidEndDisplayingNodeForRow = [_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNode:forRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeDidEndDisplayingNodeForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:didEndDisplayingRowWithNode:)];
    _asyncDelegateFlags.scrollViewWillEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    _asyncDelegateFlags.scrollViewDidEndDecelerating = [_asyncDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)];
    _asyncDelegateFlags.tableViewWillBeginBatchFetch = [_asyncDelegate respondsToSelector:@selector(tableView:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.tableNodeWillBeginBatchFetch = [_asyncDelegate respondsToSelector:@selector(tableNode:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.shouldBatchFetchForTableView = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForTableView:)];
    _asyncDelegateFlags.shouldBatchFetchForTableNode = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForTableNode:)];
    _asyncDelegateFlags.scrollViewWillBeginDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _asyncDelegateFlags.scrollViewDidEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
    _asyncDelegateFlags.tableViewConstrainedSizeForRow = [_asyncDelegate respondsToSelector:@selector(tableView:constrainedSizeForRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeConstrainedSizeForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:constrainedSizeForRowAtIndexPath:)];

    _asyncDelegateFlags.tableViewWillSelectRow = [_asyncDelegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeWillSelectRow = [_asyncDelegate respondsToSelector:@selector(tableNode:willSelectRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewDidSelectRow = [_asyncDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeDidSelectRow = [_asyncDelegate respondsToSelector:@selector(tableNode:didSelectRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewWillDeselectRow = [_asyncDelegate respondsToSelector:@selector(tableView:willDeselectRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeWillDeselectRow = [_asyncDelegate respondsToSelector:@selector(tableNode:willDeselectRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewDidDeselectRow = [_asyncDelegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeDidDeselectRow = [_asyncDelegate respondsToSelector:@selector(tableNode:didDeselectRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewShouldHighlightRow = [_asyncDelegate respondsToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeShouldHighlightRow = [_asyncDelegate respondsToSelector:@selector(tableNode:shouldHighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewDidHighlightRow = [_asyncDelegate respondsToSelector:@selector(tableView:didHighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeDidHighlightRow = [_asyncDelegate respondsToSelector:@selector(tableNode:didHighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewDidUnhighlightRow = [_asyncDelegate respondsToSelector:@selector(tableView:didUnhighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeDidUnhighlightRow = [_asyncDelegate respondsToSelector:@selector(tableNode:didUnhighlightRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewShouldShowMenuForRow = [_asyncDelegate respondsToSelector:@selector(tableView:shouldShowMenuForRowAtIndexPath:)];
    _asyncDelegateFlags.tableNodeShouldShowMenuForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:shouldShowMenuForRowAtIndexPath:)];
    _asyncDelegateFlags.tableViewCanPerformActionForRow = [_asyncDelegate respondsToSelector:@selector(tableView:canPerformAction:forRowAtIndexPath:withSender:)];
    _asyncDelegateFlags.tableNodeCanPerformActionForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:canPerformAction:forRowAtIndexPath:withSender:)];
    _asyncDelegateFlags.tableViewPerformActionForRow = [_asyncDelegate respondsToSelector:@selector(tableView:performAction:forRowAtIndexPath:withSender:)];
    _asyncDelegateFlags.tableNodePerformActionForRow = [_asyncDelegate respondsToSelector:@selector(tableNode:performAction:forRowAtIndexPath:withSender:)];
  }
  
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
}

- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy
{
  if (proxy == _proxyDelegate) {
    [self setAsyncDelegate:nil];
  } else if (proxy == _proxyDataSource) {
    [self setAsyncDataSource:nil];
  }
}

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssertMainThread();
  
  if (! _dataController.initialReloadDataHasBeenCalled) {
    // If this is the first reload, forward to super immediately to prevent it from triggering more "initial" loads while our data controller is working. 
    [super reloadData];
  }
  
  void (^batchUpdatesCompletion)(BOOL);
  if (completion) {
    batchUpdatesCompletion = ^(BOOL) {
      completion();
    };
  }
  
  [self beginUpdates];
  [_changeSet reloadData];
  [self endUpdatesWithCompletion:batchUpdatesCompletion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)reloadDataImmediately
{
  ASDisplayNodeAssertMainThread();
  [self reloadData];
  [_dataController waitUntilAllUpdatesAreCommitted];
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  if ([self validateIndexPath:indexPath]) {
    [super scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  }
}

- (void)relayoutItems
{
  [_dataController relayoutAllNodes];
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

- (ASTableNode *)tableNode
{
  return (ASTableNode *)ASViewToDisplayNode(self);
}

- (ASElementMap *)elementMapForRangeController:(ASRangeController *)rangeController
{
  return _dataController.visibleMap;
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController.visibleMap elementForItemAtIndexPath:indexPath].node;
}

- (NSIndexPath *)convertIndexPathFromTableNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait
{
  // If this is a section index path, we don't currently have a method
  // to do a mapping.
  if (indexPath == nil || indexPath.row == NSNotFound) {
    return indexPath;
  } else {
    NSIndexPath *viewIndexPath = [_dataController.visibleMap convertIndexPath:indexPath fromMap:_dataController.pendingMap];
    if (viewIndexPath == nil && wait) {
      [self waitUntilAllUpdatesAreCommitted];
      return [self convertIndexPathFromTableNode:indexPath waitingIfNeeded:NO];
    }
    return viewIndexPath;
  }
}

- (NSIndexPath *)convertIndexPathToTableNode:(NSIndexPath *)indexPath
{
  if ([self validateIndexPath:indexPath] == nil) {
    return nil;
  }

  // If this is a section index path, we don't currently have a method
  // to do a mapping.
  if (indexPath.row == NSNotFound) {
    return indexPath;
  } else {
    return [_dataController.pendingMap convertIndexPath:indexPath fromMap:_dataController.visibleMap];
  }
}

- (NSArray<NSIndexPath *> *)convertIndexPathsToTableNode:(NSArray<NSIndexPath *> *)indexPaths
{
  if (indexPaths == nil) {
    return nil;
  }

  NSMutableArray<NSIndexPath *> *indexPathsArray = [NSMutableArray new];

  for (NSIndexPath *indexPathInView in indexPaths) {
    NSIndexPath *indexPath = [self convertIndexPathToTableNode:indexPathInView];
    if (indexPath != nil) {
      [indexPathsArray addObject:indexPath];
    }
  }
  return indexPathsArray;
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self indexPathForNode:cellNode waitingIfNeeded:NO];
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
    ASDisplayNodeFailAssert(@"Table view index path has invalid section %lu, section count = %lu", (unsigned long)section, (unsigned long)self.numberOfSections);
    return nil;
  }

  NSInteger item = indexPath.item;
  // item == NSNotFound means e.g. "scroll to this section" and is acceptable
  if (item != NSNotFound && item >= [self numberOfRowsInSection:section]) {
    ASDisplayNodeFailAssert(@"Table view index path has invalid item %lu in section %lu, item count = %lu", (unsigned long)indexPath.item, (unsigned long)section, (unsigned long)[self numberOfRowsInSection:section]);
    return nil;
  }

  return indexPath;
}

- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode waitingIfNeeded:(BOOL)wait
{
  if (cellNode == nil) {
    return nil;
  }

  NSIndexPath *indexPath = [_dataController.visibleMap indexPathForElement:cellNode.collectionElement];
  indexPath = [self validateIndexPath:indexPath];
  if (indexPath == nil && wait) {
    [self waitUntilAllUpdatesAreCommitted];
    return [self indexPathForNode:cellNode waitingIfNeeded:NO];
  }
  return indexPath;
}

- (NSArray<ASCellNode *> *)visibleNodes
{
  NSArray<ASCollectionElement *> *elements = [self visibleElementsForRangeController:_rangeController];
  return ASArrayByFlatMapping(elements, ASCollectionElement *e, e.node);
}

- (void)beginUpdates
{
  ASDisplayNodeAssertMainThread();
  // _changeSet must be available during batch update
  ASDisplayNodeAssertTrue((_batchUpdateCount > 0) == (_changeSet != nil));
  
  if (_batchUpdateCount == 0) {
    _changeSet = [[_ASHierarchyChangeSet alloc] initWithOldData:[_dataController itemCountsFromDataSource]];
  }
  _batchUpdateCount++;
}

- (void)endUpdates
{
  [self endUpdatesWithCompletion:nil];
}

- (void)endUpdatesWithCompletion:(void (^)(BOOL completed))completion
{
  // We capture the current state of whether animations are enabled if they don't provide us with one.
  [self endUpdatesAnimated:[UIView areAnimationsEnabled] completion:completion];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL completed))completion
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertNotNil(_changeSet, @"_changeSet must be available when batch update ends");
  
  _batchUpdateCount--;
  // Prevent calling endUpdatesAnimated:completion: in an unbalanced way
  NSAssert(_batchUpdateCount >= 0, @"endUpdatesAnimated:completion: called without having a balanced beginUpdates call");
  
  [_changeSet addCompletionHandler:completion];

  if (_batchUpdateCount == 0) {
    _ASHierarchyChangeSet *changeSet = _changeSet;
    // Nil out _changeSet before forwarding to _dataController to allow the change set to cause subsequent batch updates on the same run loop
    _changeSet = nil;
    changeSet.animated = animated;
    [_dataController updateWithChangeSet:changeSet];
  } 
}

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  if (_batchUpdateCount > 0) {
    // This assertion will be enabled soon.
    //    ASDisplayNodeFailAssert(@"Should not call %@ during batch update", NSStringFromSelector(_cmd));
    return;
  }
  
  [_dataController waitUntilAllUpdatesAreCommitted];
}

- (void)layoutSubviews
{
  // Remeasure all rows if our row width has changed.
  _remeasuringCellNodes = YES;
  CGFloat constrainedWidth = self.bounds.size.width - [self sectionIndexWidth];
  if (constrainedWidth > 0 && _nodesConstrainedWidth != constrainedWidth) {
    _nodesConstrainedWidth = constrainedWidth;

    [self beginUpdates];
    [_dataController relayoutAllNodes];
    [self endUpdatesAnimated:(ASDisplayNodeLayerHasAnimations(self.layer) == NO) completion:nil];
  } else {
    if (_cellsForLayoutUpdates.count > 0) {
      NSMutableArray *nodesSizesChanged = [NSMutableArray array];
      [_dataController relayoutNodes:_cellsForLayoutUpdates nodesSizeChanged:nodesSizesChanged];
      if (nodesSizesChanged.count > 0) {
        [self requeryNodeHeights];
      }
    }
  }
  [_cellsForLayoutUpdates removeAllObjects];
  _remeasuringCellNodes = NO;

  // To ensure _nodesConstrainedWidth is up-to-date for every usage, this call to super must be done last
  [super layoutSubviews];
  [_rangeController updateIfNeeded];
}

#pragma mark -
#pragma mark Editing

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [self beginUpdates];
  [_changeSet insertSections:sections animationOptions:animation];
  [self endUpdates];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [self beginUpdates];
  [_changeSet deleteSections:sections animationOptions:animation];
  [self endUpdates];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [self beginUpdates];
  [_changeSet reloadSections:sections animationOptions:animation];
  [self endUpdates];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet moveSection:section toSection:newSection animationOptions:UITableViewRowAnimationNone];
  [self endUpdates];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [self beginUpdates];
  [_changeSet insertItems:indexPaths animationOptions:animation];
  [self endUpdates];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [self beginUpdates];
  [_changeSet deleteItems:indexPaths animationOptions:animation];
  [self endUpdates];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [self beginUpdates];
  [_changeSet reloadItems:indexPaths animationOptions:animation];
  [self endUpdates];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  [self beginUpdates];
  [_changeSet moveItemAtIndexPath:indexPath toIndexPath:newIndexPath animationOptions:UITableViewRowAnimationNone];
  [self endUpdates];
}

#pragma mark -
#pragma mark adjust content offset

- (void)beginAdjustingContentOffset
{
  NSIndexPath *firstVisibleIndexPath = [self.indexPathsForVisibleRows sortedArrayUsingSelector:@selector(compare:)].firstObject;
  if (firstVisibleIndexPath) {
    ASCellNode *node = [self nodeForRowAtIndexPath:firstVisibleIndexPath];
    if (node) {
      _contentOffsetAdjustmentTopVisibleNode = node;
      _contentOffsetAdjustmentTopVisibleNodeOffset = [self rectForRowAtIndexPath:firstVisibleIndexPath].origin.y - self.bounds.origin.y;
    }
  }
}

- (void)endAdjustingContentOffsetAnimated:(BOOL)animated
{
  // We can't do this for animated updates.
  if (animated) {
    return;
  }
  
  // We can't do this if we didn't have a top visible row before.
  if (_contentOffsetAdjustmentTopVisibleNode == nil) {
    return;
  }
  
  NSIndexPath *newIndexPathForTopVisibleRow = [self indexPathForNode:_contentOffsetAdjustmentTopVisibleNode];
  // We can't do this if our top visible row was deleted
  if (newIndexPathForTopVisibleRow == nil) {
    return;
  }
  
  CGFloat newRowOriginYInSelf = [self rectForRowAtIndexPath:newIndexPathForTopVisibleRow].origin.y - self.bounds.origin.y;
  CGPoint newContentOffset = self.contentOffset;
  newContentOffset.y += (newRowOriginYInSelf - _contentOffsetAdjustmentTopVisibleNodeOffset);
  self.contentOffset = newContentOffset;
  _contentOffsetAdjustmentTopVisibleNode = nil;
}

#pragma mark - Intercepted selectors

- (void)setTableHeaderView:(UIView *)tableHeaderView
{
  // Typically the view will be nil before setting it, but reset state if it is being re-hosted.
  [self.tableHeaderView.asyncdisplaykit_node exitHierarchyState:ASHierarchyStateRangeManaged];
  [super setTableHeaderView:tableHeaderView];
  [self.tableHeaderView.asyncdisplaykit_node enterHierarchyState:ASHierarchyStateRangeManaged];
}

- (void)setTableFooterView:(UIView *)tableFooterView
{
  // Typically the view will be nil before setting it, but reset state if it is being re-hosted.
  [self.tableFooterView.asyncdisplaykit_node exitHierarchyState:ASHierarchyStateRangeManaged];
  [super setTableFooterView:tableFooterView];
  [self.tableFooterView.asyncdisplaykit_node enterHierarchyState:ASHierarchyStateRangeManaged];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  _ASTableViewCell *cell = [self dequeueReusableCellWithIdentifier:kCellReuseIdentifier forIndexPath:indexPath];
  cell.delegate = self;

  ASCellNode *node = [_dataController.visibleMap elementForItemAtIndexPath:indexPath].node;
  if (node) {
    [_rangeController configureContentView:cell.contentView forCellNode:node];

    cell.node = node;
  }

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_dataController.visibleMap elementForItemAtIndexPath:indexPath].node;
  CGFloat height = node.calculatedSize.height;
  
  /**
   * Weirdly enough, Apple expects the return value here to _include_ the height
   * of the separator, if there is one! So if our node wants to be 43.5, we need
   * to return 44. UITableView will make a cell of height 44 with a content view
   * of height 43.5.
   */
  if (tableView.separatorStyle != UITableViewCellSeparatorStyleNone) {
    height += 1.0 / ASScreenScale();
  }
  return height;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return _dataController.visibleMap.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_dataController.visibleMap numberOfItemsInSection:section];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (_asyncDataSourceFlags.tableViewCanMoveRow) {
    return [_asyncDataSource tableView:self canMoveRowAtIndexPath:indexPath];
  } else {
    return NO;
  }
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
  if (_asyncDataSourceFlags.tableViewMoveRow) {
    [_asyncDataSource tableView:self moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
  }

  // Move node after informing data source in case they call nodeAtIndexPath:
  // Get up to date
  [self waitUntilAllUpdatesAreCommitted];
  // Set our flag to suppress informing super about the change.
  _updatingInResponseToInteractiveMove = YES;
  // Submit the move
  [self moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
  // Wait for it to finish – should be fast!
  [self waitUntilAllUpdatesAreCommitted];
  // Clear the flag
  _updatingInResponseToInteractiveMove = NO;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(_ASTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *cellNode = [cell node];
  cellNode.scrollView = tableView;

  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with cell that will be displayed not to be nil. indexPath: %@", indexPath);

  if (_asyncDelegateFlags.tableNodeWillDisplayNodeForRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    [_asyncDelegate tableNode:tableNode willDisplayRowWithNode:cellNode];
  } else if (_asyncDelegateFlags.tableViewWillDisplayNodeForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self willDisplayNode:cellNode forRowAtIndexPath:indexPath];
  } else if (_asyncDelegateFlags.tableViewWillDisplayNodeForRowDeprecated) {
    [_asyncDelegate tableView:self willDisplayNodeForRowAtIndexPath:indexPath];
  }
#pragma clang diagnostic pop
  
  [_rangeController setNeedsUpdate];
  
  if (ASSubclassOverridesSelector([ASCellNode class], [cellNode class], @selector(cellNodeVisibilityEvent:inScrollView:withCellFrame:))) {
    [_cellsForVisibilityUpdates addObject:cell];
  }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(_ASTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *cellNode = [cell node];

  [_rangeController setNeedsUpdate];

  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with removed cell not to be nil.");
  if (_asyncDelegateFlags.tableNodeDidEndDisplayingNodeForRow) {
    if (ASTableNode *tableNode = self.tableNode) {
    	[_asyncDelegate tableNode:tableNode didEndDisplayingRowWithNode:cellNode];
    }
  } else if (_asyncDelegateFlags.tableViewDidEndDisplayingNodeForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self didEndDisplayingNode:cellNode forRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }

  [_cellsForVisibilityUpdates removeObject:cell];
  
  cellNode.scrollView = nil;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeWillSelectRow) {
    GET_TABLENODE_OR_RETURN(tableNode, indexPath);
    NSIndexPath *result = [self convertIndexPathToTableNode:indexPath];
    // If this item was is gone, just let the table view do its default behavior and select.
    if (result == nil) {
      return indexPath;
    } else {
      result = [_asyncDelegate tableNode:tableNode willSelectRowAtIndexPath:result];
      result = [self convertIndexPathFromTableNode:result waitingIfNeeded:YES];
      return result;
    }
  } else if (_asyncDelegateFlags.tableViewWillSelectRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate tableView:self willSelectRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  } else {
    return indexPath;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeDidSelectRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:tableNode didSelectRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewDidSelectRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self didSelectRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeWillDeselectRow) {
    GET_TABLENODE_OR_RETURN(tableNode, indexPath);
    NSIndexPath *result = [self convertIndexPathToTableNode:indexPath];
    // If this item was is gone, just let the table view do its default behavior and deselect.
    if (result == nil) {
      return indexPath;
    } else {
      result = [_asyncDelegate tableNode:tableNode willDeselectRowAtIndexPath:result];
      result = [self convertIndexPathFromTableNode:result waitingIfNeeded:YES];
      return result;
    }
  } else if (_asyncDelegateFlags.tableViewWillDeselectRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate tableView:self willDeselectRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return indexPath;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeDidDeselectRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:tableNode didDeselectRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewDidDeselectRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self didDeselectRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeShouldHighlightRow) {
    GET_TABLENODE_OR_RETURN(tableNode, NO);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:tableNode shouldHighlightRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewShouldHighlightRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate tableView:self shouldHighlightRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return YES;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeDidHighlightRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:tableNode didHighlightRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewDidHighlightRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self didHighlightRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeDidHighlightRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:tableNode didUnhighlightRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewDidUnhighlightRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self didUnhighlightRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  if (_asyncDelegateFlags.tableNodeShouldShowMenuForRow) {
    GET_TABLENODE_OR_RETURN(tableNode, NO);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:tableNode shouldShowMenuForRowAtIndexPath:indexPath];
    }
  } else if (_asyncDelegateFlags.tableViewShouldShowMenuForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate tableView:self shouldShowMenuForRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
  }
  return NO;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(nonnull SEL)action forRowAtIndexPath:(nonnull NSIndexPath *)indexPath withSender:(nullable id)sender
{
  if (_asyncDelegateFlags.tableNodeCanPerformActionForRow) {
    GET_TABLENODE_OR_RETURN(tableNode, NO);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:tableNode canPerformAction:action forRowAtIndexPath:indexPath withSender:sender];
    }
  } else if (_asyncDelegateFlags.tableViewCanPerformActionForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate tableView:self canPerformAction:action forRowAtIndexPath:indexPath withSender:sender];
#pragma clang diagnostic pop
  }
  return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(nonnull SEL)action forRowAtIndexPath:(nonnull NSIndexPath *)indexPath withSender:(nullable id)sender
{
  if (_asyncDelegateFlags.tableNodePerformActionForRow) {
    GET_TABLENODE_OR_RETURN(tableNode, (void)0);
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:tableNode performAction:action forRowAtIndexPath:indexPath withSender:sender];
    }
  } else if (_asyncDelegateFlags.tableViewPerformActionForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_asyncDelegate tableView:self performAction:action forRowAtIndexPath:indexPath withSender:sender];
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
  
  for (_ASTableViewCell *tableCell in _cellsForVisibilityUpdates) {
    [[tableCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventVisibleRectChanged
                                 inScrollView:scrollView
                                withCellFrame:tableCell.frame];
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

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  _deceleratingVelocity = CGPointZero;

  if (_asyncDelegateFlags.scrollViewDidEndDecelerating) {
      [_asyncDelegate scrollViewDidEndDecelerating:scrollView];
  }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  for (_ASTableViewCell *tableViewCell in _cellsForVisibilityUpdates) {
    [[tableViewCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventWillBeginDragging
                                          inScrollView:scrollView
                                         withCellFrame:tableViewCell.frame];
  }
  if (_asyncDelegateFlags.scrollViewWillBeginDragging) {
    [_asyncDelegate scrollViewWillBeginDragging:scrollView];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
  for (_ASTableViewCell *tableViewCell in _cellsForVisibilityUpdates) {
    [[tableViewCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventDidEndDragging
                                          inScrollView:scrollView
                                         withCellFrame:tableViewCell.frame];
  }
  if (_asyncDelegateFlags.scrollViewDidEndDragging) {
    [_asyncDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
  }
}

#pragma mark - Scroll Direction

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


#pragma mark - Batch Fetching

- (ASBatchContext *)batchContext
{
  return _batchContext;
}

- (BOOL)canBatchFetch
{
  // if the delegate does not respond to this method, there is no point in starting to fetch
  BOOL canFetch = _asyncDelegateFlags.tableNodeWillBeginBatchFetch || _asyncDelegateFlags.tableViewWillBeginBatchFetch;
  if (canFetch && _asyncDelegateFlags.shouldBatchFetchForTableNode) {
    GET_TABLENODE_OR_RETURN(tableNode, NO);
    return [_asyncDelegate shouldBatchFetchForTableNode:tableNode];
  } else if (canFetch && _asyncDelegateFlags.shouldBatchFetchForTableView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDelegate shouldBatchFetchForTableView:self];
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
  if (ASDisplayShouldFetchBatchForScrollView(self, self.scrollDirection, ASScrollDirectionVerticalDirections, contentOffset)) {
    [self _beginBatchFetching];
  }
}

- (void)_beginBatchFetching
{
  [_batchContext beginBatchFetching];
  if (_asyncDelegateFlags.tableNodeWillBeginBatchFetch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      GET_TABLENODE_OR_RETURN(tableNode, (void)0);
      [_asyncDelegate tableNode:tableNode willBeginBatchFetchWithContext:_batchContext];
    });
  } else if (_asyncDelegateFlags.tableViewWillBeginBatchFetch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      [_asyncDelegate tableView:self willBeginBatchFetchWithContext:_batchContext];
#pragma clang diagnostic pop
    });
  }
}

#pragma mark - ASRangeControllerDataSource

- (ASRangeController *)rangeController
{
    return _rangeController;
}

- (NSArray<ASCollectionElement *> *)visibleElementsForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  
  CGRect bounds = self.bounds;
  // Calling indexPathsForVisibleRows will trigger UIKit to call reloadData if it never has, which can result
  // in incorrect layout if performed at zero size.  We can use the fact that nothing can be visible at zero size to return fast.
  if (CGRectIsEmpty(bounds)) {
    return @[];
  }

  NSArray *visibleIndexPaths = self.indexPathsForVisibleRows;

  // In some cases (grouped-style tables with particular geometry) indexPathsForVisibleRows will return extra index paths.
  // This is a very serious issue because we rely on the fact that any node that is marked Visible is hosted inside of a cell,
  // or else we may not mark it invisible before the node is released. See testIssue2252.
  // Calling indexPathForCell: and cellForRowAtIndexPath: are both pretty expensive – this is the quickest approach we have.
  // It would be possible to cache this NSPredicate as an ivar, but that would require unsafeifying self and calling @c bounds
  // for each item. Since the performance cost is pretty small, prefer simplicity.
  if (self.style == UITableViewStyleGrouped && visibleIndexPaths.count != self.visibleCells.count) {
    visibleIndexPaths = [visibleIndexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *indexPath, NSDictionary<NSString *,id> * _Nullable bindings) {
      return CGRectIntersectsRect(bounds, [self rectForRowAtIndexPath:indexPath]);
    }]];
  }

  ASElementMap *map = _dataController.visibleMap;
  return ASArrayByFlatMapping(visibleIndexPaths, NSIndexPath *indexPath, [map elementForItemAtIndexPath:indexPath]);
}

- (ASScrollDirection)scrollDirectionForRangeController:(ASRangeController *)rangeController
{
  return self.scrollDirection;
}

- (ASInterfaceState)interfaceStateForRangeController:(ASRangeController *)rangeController
{
  return ASInterfaceStateForDisplayNode(self.tableNode, self.window);
}

- (NSString *)nameForRangeControllerDataSource
{
  return self.asyncDataSource ? NSStringFromClass([self.asyncDataSource class]) : NSStringFromClass([self class]);
}

#pragma mark - ASRangeControllerDelegate

- (void)rangeController:(ASRangeController *)rangeController willUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  if (_automaticallyAdjustsContentOffset && !changeSet.includesReloadData) {
    [self beginAdjustingContentOffset];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  if (!self.asyncDataSource || _updatingInResponseToInteractiveMove) {
    [changeSet executeCompletionHandlerWithFinished:NO];
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }
  
  if (changeSet.includesReloadData) {
    LOG(@"UITableView reloadData");
    ASPerformBlockWithoutAnimation(!changeSet.animated, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super reloadData]");
      }
      [super reloadData];
      // Flush any range changes that happened as part of submitting the reload.
      [_rangeController updateIfNeeded];
      [self _scheduleCheckForBatchFetchingForNumberOfChanges:1];
      [changeSet executeCompletionHandlerWithFinished:YES];
    });
    return;
  }
  
  NSUInteger numberOfUpdates = 0;
  
  LOG(@"--- UITableView beginUpdates");
  [super beginUpdates];
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeReload]) {
    NSArray<NSIndexPath *> *indexPaths = change.indexPaths;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView reloadRows:%ld rows", indexPaths.count);
    BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super reloadRowsAtIndexPaths]: %@", indexPaths);
      }
      [super reloadRowsAtIndexPaths:indexPaths withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeReload]) {
    NSIndexSet *sectionIndexes = change.indexSet;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView reloadSections:%@", sectionIndexes);
    BOOL preventAnimation = (animationOptions == UITableViewRowAnimationNone);
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super reloadSections]: %@", sectionIndexes);
      }
      [super reloadSections:sectionIndexes withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeOriginalDelete]) {
    NSArray<NSIndexPath *> *indexPaths = change.indexPaths;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView deleteRows:%ld rows", indexPaths.count);
    BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super deleteRowsAtIndexPaths]: %@", indexPaths);
      }
      [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeOriginalDelete]) {
    NSIndexSet *sectionIndexes = change.indexSet;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView deleteSections:%@", sectionIndexes);
    BOOL preventAnimation = (animationOptions == UITableViewRowAnimationNone);
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super deleteSections]: %@", sectionIndexes);
      }
      [super deleteSections:sectionIndexes withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }
  
  for (_ASHierarchySectionChange *change in [changeSet sectionChangesOfType:_ASHierarchyChangeTypeOriginalInsert]) {
    NSIndexSet *sectionIndexes = change.indexSet;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView insertSections:%@", sectionIndexes);
    BOOL preventAnimation = (animationOptions == UITableViewRowAnimationNone);
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super insertSections]: %@", sectionIndexes);
      }
      [super insertSections:sectionIndexes withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }
  
  for (_ASHierarchyItemChange *change in [changeSet itemChangesOfType:_ASHierarchyChangeTypeOriginalInsert]) {
    NSArray<NSIndexPath *> *indexPaths = change.indexPaths;
    UITableViewRowAnimation animationOptions = (UITableViewRowAnimation)change.animationOptions;
    
    LOG(@"UITableView insertRows:%ld rows", indexPaths.count);
    BOOL preventAnimation = (animationOptions == UITableViewRowAnimationNone);
    ASPerformBlockWithoutAnimation(preventAnimation, ^{
      if (self.test_enableSuperUpdateCallLogging) {
        NSLog(@"-[super insertRowsAtIndexPaths]: %@", indexPaths);
      }
      [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animationOptions];
    });
    
    numberOfUpdates++;
  }

  LOG(@"--- UITableView endUpdates");
  ASPerformBlockWithoutAnimation(!changeSet.animated, ^{
    [super endUpdates];
    [_rangeController updateIfNeeded];
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:numberOfUpdates];
  });
  if (_automaticallyAdjustsContentOffset) {
    [self endAdjustingContentOffsetAnimated:changeSet.animated];
  }
  [changeSet executeCompletionHandlerWithFinished:YES];
}

#pragma mark - ASDataControllerSource

- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath {
  ASCellNodeBlock block = nil;

  if (_asyncDataSourceFlags.tableNodeNodeBlockForRow) {
    if (ASTableNode *tableNode = self.tableNode) {
      block = [_asyncDataSource tableNode:tableNode nodeBlockForRowAtIndexPath:indexPath];
    }
  } else if (_asyncDataSourceFlags.tableNodeNodeForRow) {
    ASCellNode *node = nil;
    if (ASTableNode *tableNode = self.tableNode) {
    	node = [_asyncDataSource tableNode:tableNode nodeForRowAtIndexPath:indexPath];
    }
    if ([node isKindOfClass:[ASCellNode class]]) {
      block = ^{
        return node;
      };
    } else {
      ASDisplayNodeFailAssert(@"Data source returned invalid node from tableNode:nodeForRowAtIndexPath:. Node: %@", node);
    }
  } else if (_asyncDataSourceFlags.tableViewNodeBlockForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    block = [_asyncDataSource tableView:self nodeBlockForRowAtIndexPath:indexPath];
  } else if (_asyncDataSourceFlags.tableViewNodeForRow) {
    ASCellNode *node = [_asyncDataSource tableView:self nodeForRowAtIndexPath:indexPath];
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
    if (_inverted) {
        node.transform = CATransform3DMakeScale(1, -1, 1) ;
    }
    return node;
  };
  return block;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange constrainedSize = ASSizeRangeZero;
  if (_asyncDelegateFlags.tableNodeConstrainedSizeForRow) {
    GET_TABLENODE_OR_RETURN(tableNode, constrainedSize);
    ASSizeRange delegateConstrainedSize = [_asyncDelegate tableNode:tableNode constrainedSizeForRowAtIndexPath:indexPath];
    // ignore widths in the returned size range (for TableView)
    constrainedSize = ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.min.height),
                                      CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.max.height));
  } else if (_asyncDelegateFlags.tableViewConstrainedSizeForRow) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    ASSizeRange delegateConstrainedSize = [_asyncDelegate tableView:self constrainedSizeForRowAtIndexPath:indexPath];
#pragma clang diagnostic pop
    // ignore widths in the returned size range (for TableView)
    constrainedSize = ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.min.height),
                                      CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.max.height));
  } else {
    constrainedSize = ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, 0),
                                      CGSizeMake(_nodesConstrainedWidth, CGFLOAT_MAX));
  }
  return constrainedSize;
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  if (_asyncDataSourceFlags.tableNodeNumberOfRowsInSection) {
    GET_TABLENODE_OR_RETURN(tableNode, 0);
    return [_asyncDataSource tableNode:tableNode numberOfRowsInSection:section];
  } else if (_asyncDataSourceFlags.tableViewNumberOfRowsInSection) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDataSource tableView:self numberOfRowsInSection:section];
#pragma clang diagnostic pop
  } else {
    return 0;
  }
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController
{
  if (_asyncDataSourceFlags.numberOfSectionsInTableNode) {
    GET_TABLENODE_OR_RETURN(tableNode, 0);
    return [_asyncDataSource numberOfSectionsInTableNode:tableNode];
  } else if (_asyncDataSourceFlags.numberOfSectionsInTableView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDataSource numberOfSectionsInTableView:self];
#pragma clang diagnostic pop
  } else {
    return 1; // default section number
  }
}

- (BOOL)dataController:(ASDataController *)dataController presentedSizeForElement:(ASCollectionElement *)element matchesSize:(CGSize)size
{
  NSIndexPath *indexPath = [self indexPathForNode:element.node];
  CGRect rect = [self rectForRowAtIndexPath:indexPath];
  
  /**
   * Weirdly enough, Apple expects the return value in tableView:heightForRowAtIndexPath: to _include_ the height
   * of the separator, if there is one! So if rectForRow would return 44.0 we need to use 43.5.
   */
  if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
    rect.size.height -= 1.0 / ASScreenScale();
  }

  return (fabs(rect.size.height - size.height) < FLT_EPSILON);
}

#pragma mark - ASDataControllerEnvironmentDelegate

- (id<ASTraitEnvironment>)dataControllerEnvironment
{
  return self.tableNode;
}

#pragma mark - _ASTableViewCellDelegate

- (void)didLayoutSubviewsOfTableViewCell:(_ASTableViewCell *)tableViewCell
{
  ASCellNode *node = tableViewCell.node;
  if (node == nil || _asyncDataSource == nil) {
    return;
  }
  
  CGFloat contentViewWidth = tableViewCell.contentView.bounds.size.width;
  ASSizeRange constrainedSize = node.constrainedSizeForCalculatedLayout;
  
  // Table view cells should always fill its content view width.
  // Normally the content view width equals to the constrained size width (which equals to the table view width).
  // If there is a mismatch between these values, for example after the table view entered or left editing mode,
  // content view width is preferred and used to re-measure the cell node.
  if (CGSizeEqualToSize(node.calculatedSize, CGSizeZero) == NO && contentViewWidth != constrainedSize.max.width) {
    constrainedSize.min.width = contentViewWidth;
    constrainedSize.max.width = contentViewWidth;

    // Re-measurement is done on main to ensure thread affinity. In the worst case, this is as fast as UIKit's implementation.
    //
    // Unloaded nodes *could* be re-measured off the main thread, but only with the assumption that content view width
    // is the same for all cells (because there is no easy way to get that individual value before the node being assigned to a _ASTableViewCell).
    // Also, in many cases, some nodes may not need to be re-measured at all, such as when user enters and then immediately leaves editing mode.
    // To avoid premature optimization and making such assumption, as well as to keep ASTableView simple, re-measurement is strictly done on main.
    CGSize oldSize = node.bounds.size;
    const CGSize calculatedSize = [node layoutThatFits:constrainedSize].size;
    node.frame = { .size = calculatedSize };

    // If the node height changed, trigger a height requery.
    if (oldSize.height != calculatedSize.height) {
      [self beginUpdates];
      [self endUpdatesAnimated:(ASDisplayNodeLayerHasAnimations(self.layer) == NO) completion:nil];
    }
  }
}

#pragma mark - ASCellNodeDelegate

- (void)nodeSelectedStateDidChange:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath) {
    if (node.isSelected) {
      [self selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    } else {
      [self deselectRowAtIndexPath:indexPath animated:NO];
    }
  }
}

- (void)nodeHighlightedStateDidChange:(ASCellNode *)node
{
  NSIndexPath *indexPath = [self indexPathForNode:node];
  if (indexPath) {
    [self cellForRowAtIndexPath:indexPath].highlighted = node.isHighlighted;
  }
}

- (void)nodeDidInvalidateSize:(ASCellNode *)node
{
  [_cellsForLayoutUpdates addObject:node];
  [self setNeedsLayout];
}

- (void)nodeDidRelayout:(ASCellNode *)node sizeChanged:(BOOL)sizeChanged
{
  ASDisplayNodeAssertMainThread();

  if (!sizeChanged || _queuedNodeHeightUpdate || _remeasuringCellNodes) {
    return;
  }

  _queuedNodeHeightUpdate = YES;
  [self performSelector:@selector(requeryNodeHeights)
             withObject:nil
             afterDelay:0
                inModes:@[ NSRunLoopCommonModes ]];
}

// Cause UITableView to requery for the new height of this node
- (void)requeryNodeHeights
{
  _queuedNodeHeightUpdate = NO;

  [super beginUpdates];
  [super endUpdates];
}

#pragma mark - Helper Methods

// Note: This is called every layout, and so it is very performance sensitive.
- (CGFloat)sectionIndexWidth
{
  // If they don't implement the methods, then there's no section index.
  if (_asyncDataSourceFlags.sectionIndexMethods == NO) {
    return 0;
  }

  UIView *indexView = _sectionIndexView;
  if (indexView.superview == self) {
    return indexView.frame.size.width;
  }

  CGRect bounds = self.bounds;
  for (UIView *view in self.subviews) {
    CGRect frame = view.frame;
    // Section index is right-aligned and less than half-width.
    if (CGRectGetMaxX(frame) == CGRectGetMaxX(bounds) && frame.size.width * 2 < bounds.size.width) {
      _sectionIndexView = view;
      return frame.size.width;
    }
  }
  return 0;
}

#pragma mark - _ASDisplayView behavior substitutions
// Need these to drive interfaceState so we know when we are visible, if not nested in another range-managing element.
// Because our superclass is a true UIKit class, we cannot also subclass _ASDisplayView.
- (void)willMoveToWindow:(UIWindow *)newWindow
{
  BOOL visible = (newWindow != nil);
  ASDisplayNode *node = self.tableNode;
  if (visible && !node.inHierarchy) {
    [node __enterHierarchy];
  }
}

- (void)didMoveToWindow
{
  BOOL visible = (self.window != nil);
  ASDisplayNode *node = self.tableNode;
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

@end

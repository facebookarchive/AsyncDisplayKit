//
//  ASTableView.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASTableViewInternal.h"

#import "ASAssert.h"
#import "ASAvailability.h"
#import "ASBatchFetching.h"
#import "ASCellNode+Internal.h"
#import "ASChangeSetDataController.h"
#import "ASDelegateProxy.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "_ASDisplayLayer.h"
#import "ASTableNode.h"
#import "ASEqualityHelpers.h"
#import "ASTableView+Undeprecated.h"

static const ASSizeRange kInvalidSizeRange = {CGSizeZero, CGSizeZero};
static NSString * const kCellReuseIdentifier = @"_ASTableViewCell";

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

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

@interface ASTableNode ()
- (instancetype)_initWithTableView:(ASTableView *)tableView;
@end

@interface ASTableView () <ASRangeControllerDataSource, ASRangeControllerDelegate, ASDataControllerSource, _ASTableViewCellDelegate, ASCellNodeInteractionDelegate, ASDelegateProxyInterceptor, ASBatchFetchingScrollView, ASDataControllerEnvironmentDelegate>
{
  ASTableViewProxy *_proxyDataSource;
  ASTableViewProxy *_proxyDelegate;

  ASFlowLayoutController *_layoutController;

  ASRangeController *_rangeController;

  ASBatchContext *_batchContext;

  NSIndexPath *_pendingVisibleIndexPath;

  NSIndexPath *_contentOffsetAdjustmentTopVisibleRow;
  CGFloat _contentOffsetAdjustment;
  
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
  BOOL _ignoreNodesConstrainedWidthChange;
  BOOL _queuedNodeHeightUpdate;
  BOOL _isDeallocating;
  BOOL _performingBatchUpdates;
  NSMutableSet *_cellsForVisibilityUpdates;
  
  struct {
    unsigned int scrollViewDidScroll:1;
    unsigned int scrollViewWillBeginDragging:1;
    unsigned int scrollViewDidEndDragging:1;
    unsigned int scrollViewWillEndDragging:1;
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
  } _asyncDataSourceFlags;
}

@property (nonatomic, strong, readwrite) ASDataController *dataController;

@property (nonatomic, weak)   ASTableNode *tableNode;

@property (nonatomic) BOOL test_enableSuperUpdateCallLogging;
@end

@implementation ASTableView

// Using _ASDisplayLayer ensures things like -layout are properly forwarded to ASTableNode.
+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

+ (Class)dataControllerClass
{
  return [ASChangeSetDataController class];
}

#pragma mark -
#pragma mark Lifecycle

- (void)configureWithDataControllerClass:(Class)dataControllerClass
{
  _layoutController = [[ASFlowLayoutController alloc] initWithScrollOption:ASFlowLayoutDirectionVertical];
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.layoutController = _layoutController;
  _rangeController.dataSource = self;
  _rangeController.delegate = self;
  
  _dataController = [[dataControllerClass alloc] initWithDataSource:self];
  _dataController.delegate = _rangeController;
  _dataController.environmentDelegate = self;
  
  _layoutController.dataSource = _dataController;

  _leadingScreensForBatching = 2.0;
  _batchContext = [[ASBatchContext alloc] init];

  _automaticallyAdjustsContentOffset = NO;
  
  _nodesConstrainedWidth = self.bounds.size.width;
  // If the initial size is 0, expect a size change very soon which is part of the initial configuration
  // and should not trigger a relayout.
  _ignoreNodesConstrainedWidthChange = (_nodesConstrainedWidth == 0);
  
  _proxyDelegate = [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
  
  _proxyDataSource = [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;

  [self registerClass:_ASTableViewCell.class forCellReuseIdentifier:kCellReuseIdentifier];
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  return [self _initWithFrame:frame style:style dataControllerClass:nil];
}

- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass
{
  if (!(self = [super initWithFrame:frame style:style])) {
    return nil;
  }
  _cellsForVisibilityUpdates = [NSMutableSet set];
  if (!dataControllerClass) {
    dataControllerClass = [[self class] dataControllerClass];
  }
  
  [self configureWithDataControllerClass:dataControllerClass];
  
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
  // Sometimes the UIKit classes can call back to their delegate even during deallocation.
  _isDeallocating = YES;
  [self setAsyncDelegate:nil];
  [self setAsyncDataSource:nil];
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

- (void)setAsyncDataSource:(id<ASTableDataSource>)asyncDataSource
{
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
    
    ASDisplayNodeAssert(_asyncDataSourceFlags.tableViewNodeBlockForRow
                        || _asyncDataSourceFlags.tableViewNodeForRow
                        || _asyncDataSourceFlags.tableNodeNodeBlockForRow
                        || _asyncDataSourceFlags.tableNodeNodeForRow, @"Data source must implement tableNode:nodeBlockForRowAtIndexPath: or tableNode:nodeForRowAtIndexPath:");
    ASDisplayNodeAssert(_asyncDataSourceFlags.tableNodeNumberOfRowsInSection || _asyncDataSourceFlags.tableViewNumberOfRowsInSection, @"Data source must implement tableNode:numberOfRowsInSection:");
  }
  
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASTableDelegate>)asyncDelegate
{
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
    if (_asyncDelegateFlags.tableViewWillDisplayNodeForRow == NO) {
      _asyncDelegateFlags.tableViewWillDisplayNodeForRowDeprecated = [_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)];
    }
    _asyncDelegateFlags.tableViewDidEndDisplayingNodeForRow = [_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNode:forRowAtIndexPath:)];
    _asyncDelegateFlags.scrollViewWillEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
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
  ASPerformBlockOnMainThread(^{
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOptions:UITableViewRowAnimationNone completion:completion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)reloadDataImmediately
{
  ASDisplayNodeAssertMainThread();
  [_dataController reloadDataImmediatelyWithAnimationOptions:UITableViewRowAnimationNone];
  [super reloadData];
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

- (NSArray<NSArray <ASCellNode *> *> *)completedNodes
{
  return [_dataController completedNodes];
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtCompletedIndexPath:indexPath];
}

- (NSIndexPath *)convertIndexPathFromTableNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait
{
  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  return [self indexPathForNode:node waitingIfNeeded:wait];
}

- (NSIndexPath *)convertIndexPathToTableNode:(NSIndexPath *)indexPath
{
  ASCellNode *node = [self nodeForRowAtIndexPath:indexPath];
  return [_dataController indexPathForNode:node];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self indexPathForNode:cellNode waitingIfNeeded:NO];
}

- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode waitingIfNeeded:(BOOL)wait
{
  NSIndexPath *indexPath = [_dataController completedIndexPathForNode:cellNode];
  if (indexPath == nil && wait) {
    [_dataController waitUntilAllUpdatesAreCommitted];
    indexPath = [_dataController completedIndexPathForNode:cellNode];
  }
  return indexPath;
}

- (NSArray<ASCellNode *> *)visibleNodes
{
  NSArray *indexPaths = [self visibleNodeIndexPathsForRangeController:_rangeController];
  
  NSMutableArray<ASCellNode *> *visibleNodes = [NSMutableArray array];
  for (NSIndexPath *indexPath in indexPaths) {
    ASCellNode *node = [self nodeForRowAtIndexPath:indexPath];
    if (node) {
      // It is possible for UITableView to return indexPaths before the node is completed.
      [visibleNodes addObject:node];
    }
  }
  
  return visibleNodes;
}

- (void)beginUpdates
{
  ASDisplayNodeAssertMainThread();
  [_dataController beginUpdates];
}

- (void)endUpdates
{
  [self endUpdatesAnimated:YES completion:nil];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL completed))completion;
{
  ASDisplayNodeAssertMainThread();
  [_dataController endUpdatesAnimated:animated completion:completion];
}

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  [_dataController waitUntilAllUpdatesAreCommitted];
}

/**
 * TODO: This method was built when the distinction between data source
 * index paths and view index paths was unclear. For compatibility, it
 * still expects data source index paths for the time being.
 * When the behavior is changed (to use the view index path directly)
 * we should also remove the @c convertIndexPathFromTableNode: method.
 */
- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();

  indexPath = [self convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [super scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  } else {
    NSLog(@"Warning: Ignoring request to scroll to row at index path %@ because the item did not reach the table view.", indexPath);
  }
}

/**
 * TODO: This method was built when the distinction between data source
 * index paths and view index paths was unclear. For compatibility, it
 * still expects data source index paths for the time being.
 */
- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
  ASDisplayNodeAssertMainThread();
  
  indexPath = [self convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [super selectRowAtIndexPath:indexPath animated:YES scrollPosition:scrollPosition];
  } else {
    NSLog(@"Warning: Ignoring request to select row at index path %@ because the item did not reach the table view.", indexPath);
  }
}

- (void)layoutSubviews
{
  if (_nodesConstrainedWidth != self.bounds.size.width) {
    _nodesConstrainedWidth = self.bounds.size.width;

    // First width change occurs during initial configuration. An expensive relayout pass is unnecessary at that time
    // and should be avoided, assuming that the initial data loading automatically runs shortly afterward.
    if (_ignoreNodesConstrainedWidthChange) {
      _ignoreNodesConstrainedWidthChange = NO;
    } else {
      [self beginUpdates];
      [_dataController relayoutAllNodes];
      [self endUpdates];
    }
  }
  
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
  [_dataController insertSections:sections withAnimationOptions:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [_dataController deleteSections:sections withAnimationOptions:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (sections.count == 0) { return; }
  [_dataController reloadSections:sections withAnimationOptions:animation];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  [_dataController moveSection:section toSection:newSection withAnimationOptions:UITableViewRowAnimationNone];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (indexPaths.count == 0) { return; }
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOptions:UITableViewRowAnimationNone];
}

#pragma mark -
#pragma mark adjust content offset

- (void)beginAdjustingContentOffset
{
  ASDisplayNodeAssert(_automaticallyAdjustsContentOffset, @"this method should only be called when _automaticallyAdjustsContentOffset == YES");
  _contentOffsetAdjustment = 0;
  _contentOffsetAdjustmentTopVisibleRow = self.indexPathsForVisibleRows.firstObject;
}

- (void)endAdjustingContentOffset
{
  ASDisplayNodeAssert(_automaticallyAdjustsContentOffset, @"this method should only be called when _automaticallyAdjustsContentOffset == YES");
  if (_contentOffsetAdjustment != 0) {
    self.contentOffset = CGPointMake(0, self.contentOffset.y+_contentOffsetAdjustment);
  }

  _contentOffsetAdjustment = 0;
  _contentOffsetAdjustmentTopVisibleRow = nil;
}

- (void)adjustContentOffsetWithNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths inserting:(BOOL)inserting {
  // Maintain the users visible window when inserting or deleting cells by adjusting the content offset for nodes
  // before the visible area. If in a begin/end updates block this will update _contentOffsetAdjustment, otherwise it will
  // update self.contentOffset directly.

  ASDisplayNodeAssert(_automaticallyAdjustsContentOffset, @"this method should only be called when _automaticallyAdjustsContentOffset == YES");

  CGFloat dir = (inserting) ? +1 : -1;
  CGFloat adjustment = 0;
  NSIndexPath *top = _contentOffsetAdjustmentTopVisibleRow ? : self.indexPathsForVisibleRows.firstObject;

  for (int index = 0; index < indexPaths.count; index++) {
    NSIndexPath *indexPath = indexPaths[index];
    if ([indexPath compare:top] <= 0) { // if this row is before or equal to the topmost visible row, make adjustments...
      ASCellNode *cellNode = nodes[index];
      adjustment += cellNode.calculatedSize.height * dir;
      if (indexPath.section == top.section) {
        top = [NSIndexPath indexPathForRow:top.row+dir inSection:top.section];
      }
    }
  }

  if (_contentOffsetAdjustmentTopVisibleRow) { // true of we are in a begin/end update block (see beginAdjustingContentOffset)
    _contentOffsetAdjustmentTopVisibleRow = top;
    _contentOffsetAdjustment += adjustment;
  } else if (adjustment != 0) {
    self.contentOffset = CGPointMake(0, self.contentOffset.y+adjustment);
  }
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

  ASCellNode *node = [_dataController nodeAtCompletedIndexPath:indexPath];
  if (node) {
    [_rangeController configureContentView:cell.contentView forCellNode:node];

    cell.node = node;
    cell.backgroundColor = node.backgroundColor;
    cell.selectionStyle = node.selectionStyle;

    // the following ensures that we clip the entire cell to it's bounds if node.clipsToBounds is set (the default)
    // This is actually a workaround for a bug we are seeing in some rare cases (selected background view
    // overlaps other cells if size of ASCellNode has changed.)
    cell.clipsToBounds = node.clipsToBounds;
  }

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  return node.calculatedSize.height;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [_dataController completedNumberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_dataController completedNumberOfRowsInSection:section];
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
  [_dataController moveCompletedNodeAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(_ASTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  _pendingVisibleIndexPath = indexPath;
  
  ASCellNode *cellNode = [cell node];
  cellNode.scrollView = tableView;

  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with cell that will be displayed not to be nil. indexPath: %@", indexPath);

  if (_asyncDelegateFlags.tableNodeWillDisplayNodeForRow) {
    [_asyncDelegate tableNode:self.tableNode willDisplayRowWithNode:cellNode];
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
  if (ASObjectIsEqual(_pendingVisibleIndexPath, indexPath)) {
    _pendingVisibleIndexPath = nil;
  }
  
  ASCellNode *cellNode = [cell node];

  [_rangeController setNeedsUpdate];

  ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with removed cell not to be nil.");
  if (_asyncDelegateFlags.tableNodeDidEndDisplayingNodeForRow) {
    [_asyncDelegate tableNode:self.tableNode didEndDisplayingRowWithNode:cellNode];
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
    NSIndexPath *result = [self convertIndexPathToTableNode:indexPath];
    // If this item was is gone, just let the table view do its default behavior and select.
    if (result == nil) {
      return indexPath;
    } else {
      result = [_asyncDelegate tableNode:self.tableNode willSelectRowAtIndexPath:result];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:self.tableNode didSelectRowAtIndexPath:indexPath];
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
    NSIndexPath *result = [self convertIndexPathToTableNode:indexPath];
    // If this item was is gone, just let the table view do its default behavior and deselect.
    if (result == nil) {
      return indexPath;
    } else {
      result = [_asyncDelegate tableNode:self.tableNode willDeselectRowAtIndexPath:result];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:self.tableNode didDeselectRowAtIndexPath:indexPath];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:self.tableNode shouldHighlightRowAtIndexPath:indexPath];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:self.tableNode didHighlightRowAtIndexPath:indexPath];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:self.tableNode didUnhighlightRowAtIndexPath:indexPath];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:self.tableNode shouldShowMenuForRowAtIndexPath:indexPath];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      return [_asyncDelegate tableNode:self.tableNode canPerformAction:action forRowAtIndexPath:indexPath withSender:sender];
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
    indexPath = [self convertIndexPathToTableNode:indexPath];
    if (indexPath != nil) {
      [_asyncDelegate tableNode:self.tableNode performAction:action forRowAtIndexPath:indexPath withSender:sender];
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
    [self _beginBatchFetchingIfNeededWithScrollView:self forScrollDirection:[self scrollDirection] contentOffset:*targetContentOffset];
  }
  
  if (_asyncDelegateFlags.scrollViewWillEndDragging) {
    [_asyncDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:(targetContentOffset ? : &contentOffset)];
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
    return [_asyncDelegate shouldBatchFetchForTableNode:self.tableNode];
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
  if (_asyncDelegateFlags.tableNodeWillBeginBatchFetch) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [_asyncDelegate tableNode:self.tableNode willBeginBatchFetchWithContext:_batchContext];
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

- (NSArray *)visibleNodeIndexPathsForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  
  // Calling indexPathsForVisibleRows will trigger UIKit to call reloadData if it never has, which can result
  // in incorrect layout if performed at zero size.  We can use the fact that nothing can be visible at zero size to return fast.
  if (CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
    return @[];
  }
  
  // NOTE: A prior comment claimed that `indexPathsForVisibleRows` may return extra index paths for grouped-style
  // tables. This is seen as an acceptable issue for the time being.
  
  NSIndexPath *pendingVisibleIndexPath = _pendingVisibleIndexPath;
  if (pendingVisibleIndexPath == nil) {
    return self.indexPathsForVisibleRows;
  }
  
  NSMutableArray *visibleIndexPaths = [self.indexPathsForVisibleRows mutableCopy];
  [visibleIndexPaths sortUsingSelector:@selector(compare:)];

  BOOL isPendingIndexPathVisible = (NSNotFound != [visibleIndexPaths indexOfObject:pendingVisibleIndexPath inSortedRange:NSMakeRange(0, visibleIndexPaths.count) options:kNilOptions usingComparator:^(id  _Nonnull obj1, id  _Nonnull obj2) {
    return [obj1 compare:obj2];
  }]);
  
  if (isPendingIndexPathVisible) {
    _pendingVisibleIndexPath = nil; // once it has shown up in visibleIndexPaths, we can stop tracking it
  } else if ([self isIndexPath:visibleIndexPaths.firstObject immediateSuccessorOfIndexPath:pendingVisibleIndexPath]) {
    [visibleIndexPaths insertObject:pendingVisibleIndexPath atIndex:0];
  } else if ([self isIndexPath:pendingVisibleIndexPath immediateSuccessorOfIndexPath:visibleIndexPaths.lastObject]) {
    [visibleIndexPaths addObject:pendingVisibleIndexPath];
  } else {
    _pendingVisibleIndexPath = nil; // not contiguous, ignore.
  }
  return visibleIndexPaths;
}

- (ASScrollDirection)scrollDirectionForRangeController:(ASRangeController *)rangeController
{
  return self.scrollDirection;
}

- (ASDisplayNode *)rangeController:(ASRangeController *)rangeController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

- (CGSize)viewportSizeForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
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

- (void)didBeginUpdatesInRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  LOG(@"--- UITableView beginUpdates");

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  _performingBatchUpdates = YES;
  [super beginUpdates];

  if (_automaticallyAdjustsContentOffset) {
    [self beginAdjustingContentOffset];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didEndUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  LOG(@"--- UITableView endUpdates");

  if (!self.asyncDataSource) {
    if (completion) {
      completion(NO);
    }
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  if (_automaticallyAdjustsContentOffset) {
    [self endAdjustingContentOffset];
  }

  ASPerformBlockWithoutAnimation(!animated, ^{
    [super endUpdates];
    [_rangeController updateIfNeeded];
  });

  _performingBatchUpdates = NO;
  if (completion) {
    completion(YES);
  }
}

- (void)didCompleteUpdatesInRangeController:(ASRangeController *)rangeController
{
  [self _checkForBatchFetching];
}

- (void)rangeController:(ASRangeController *)rangeController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  LOG(@"UITableView insertRows:%ld rows", indexPaths.count);

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    if (self.test_enableSuperUpdateCallLogging) {
      NSLog(@"-[super insertRowsAtIndexPaths]: %@", indexPaths);
    }
    [super insertRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
    if (!_performingBatchUpdates) {
      [_rangeController updateIfNeeded];
    }
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexPaths.count];
  });

  if (_automaticallyAdjustsContentOffset) {
    [self adjustContentOffsetWithNodes:nodes atIndexPaths:indexPaths inserting:YES];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  LOG(@"UITableView deleteRows:%ld rows", indexPaths.count);

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    if (self.test_enableSuperUpdateCallLogging) {
      NSLog(@"-[super deleteRowsAtIndexPaths]: %@", indexPaths);
    }
    [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
    if (!_performingBatchUpdates) {
      [_rangeController updateIfNeeded];
    }
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexPaths.count];
  });

  if (_automaticallyAdjustsContentOffset) {
    [self adjustContentOffsetWithNodes:nodes atIndexPaths:indexPaths inserting:NO];
  }
}

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  LOG(@"UITableView insertSections:%@", indexSet);


  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    if (self.test_enableSuperUpdateCallLogging) {
      NSLog(@"-[super insertSections]: %@", indexSet);
    }
    [super insertSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
    if (!_performingBatchUpdates) {
      [_rangeController updateIfNeeded];
    }
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexSet.count];
  });
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  LOG(@"UITableView deleteSections:%@", indexSet);

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    if (self.test_enableSuperUpdateCallLogging) {
      NSLog(@"-[super deleteSections]: %@", indexSet);
    }
    [super deleteSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
    if (!_performingBatchUpdates) {
      [_rangeController updateIfNeeded];
    }
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexSet.count];
  });
}

#pragma mark - ASDataControllerDelegate

- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath {
  ASCellNodeBlock block = nil;

  if (_asyncDataSourceFlags.tableNodeNodeBlockForRow) {
    block = [_asyncDataSource tableNode:self.tableNode nodeBlockForRowAtIndexPath:indexPath];
  } else if (_asyncDataSourceFlags.tableNodeNodeBlockForRow) {
    ASCellNode *node = [_asyncDataSource tableNode:self.tableNode nodeForRowAtIndexPath:indexPath];
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
    return node;
  };
  return block;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange constrainedSize = kInvalidSizeRange;
  if (_asyncDelegateFlags.tableNodeConstrainedSizeForRow) {
    ASSizeRange delegateConstrainedSize = [_asyncDelegate tableNode:self.tableNode constrainedSizeForRowAtIndexPath:indexPath];
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
    return [_asyncDataSource tableNode:self.tableNode numberOfRowsInSection:section];
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
    return [_asyncDataSource numberOfSectionsInTableNode:self.tableNode];
  } else if (_asyncDataSourceFlags.numberOfSectionsInTableView) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [_asyncDataSource numberOfSectionsInTableView:self];
#pragma clang diagnostic pop
  } else {
    return 1; // default section number
  }
}

#pragma mark - ASDataControllerEnvironmentDelegate

- (id<ASEnvironment>)dataControllerEnvironment
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
  if (contentViewWidth != constrainedSize.max.width) {
    constrainedSize.min.width = contentViewWidth;
    constrainedSize.max.width = contentViewWidth;

    // Re-measurement is done on main to ensure thread affinity. In the worst case, this is as fast as UIKit's implementation.
    //
    // Unloaded nodes *could* be re-measured off the main thread, but only with the assumption that content view width
    // is the same for all cells (because there is no easy way to get that individual value before the node being assigned to a _ASTableViewCell).
    // Also, in many cases, some nodes may not need to be re-measured at all, such as when user enters and then immediately leaves editing mode.
    // To avoid premature optimization and making such assumption, as well as to keep ASTableView simple, re-measurement is strictly done on main.
    [self beginUpdates];
    const CGSize calculatedSize = [node layoutThatFits:constrainedSize].size;
    node.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
    [self endUpdates];
  }
}

#pragma mark - ASCellNodeDelegate

- (void)nodeSelectedStateDidChange:(ASCellNode *)node
{
  NSIndexPath *indexPath = [_dataController completedIndexPathForNode:node];
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
  NSIndexPath *indexPath = [_dataController completedIndexPathForNode:node];
  if (indexPath) {
    [self cellForRowAtIndexPath:indexPath].highlighted = node.isHighlighted;
  }
}

- (void)nodeDidRelayout:(ASCellNode *)node sizeChanged:(BOOL)sizeChanged
{
  ASDisplayNodeAssertMainThread();

  if (!sizeChanged || _queuedNodeHeightUpdate) {
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

#pragma mark - Memory Management

- (void)clearContents
{
  [_rangeController clearContents];
}

- (void)clearFetchedData
{
  [_rangeController clearFetchedData];
}

#pragma mark - Helper Methods

/// @note This should be a UIKit index path.
- (BOOL)isIndexPath:(NSIndexPath *)indexPath immediateSuccessorOfIndexPath:(NSIndexPath *)anchor
{
  if (!anchor || !indexPath) {
    return NO;
  }
  if (indexPath.section == anchor.section) {
    return (indexPath.row == anchor.row+1); // assumes that indexes are valid
    
  } else if (indexPath.section > anchor.section && indexPath.row == 0) {
    if (anchor.row != [_dataController completedNumberOfRowsInSection:anchor.section] -1) {
      return NO;  // anchor is not at the end of the section
    }
    
    NSInteger nextSection = anchor.section+1;
    while([_dataController completedNumberOfRowsInSection:nextSection] == 0) {
      ++nextSection;
    }
    
    return indexPath.section == nextSection;
  }
  
  return NO;
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
}

@end

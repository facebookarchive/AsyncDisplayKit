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
#import "ASBatchFetching.h"
#import "ASCellNode+Internal.h"
#import "ASChangeSetDataController.h"
#import "ASDelegateProxy.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+Beta.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "_ASDisplayLayer.h"
#import "ASTableNode.h"

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

  CGFloat _nodesConstrainedWidth;
  BOOL _ignoreNodesConstrainedWidthChange;
  BOOL _queuedNodeHeightUpdate;
  BOOL _isDeallocating;
  NSMutableSet *_cellsForVisibilityUpdates;
  
  struct {
    unsigned int asyncDelegateScrollViewDidScroll:1;
    unsigned int asyncDelegateScrollViewWillBeginDragging:1;
    unsigned int asyncDelegateScrollViewDidEndDragging:1;
    unsigned int asyncDelegateTableViewWillDisplayNodeForRowAtIndexPath:1;
    unsigned int asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPath:1;
    unsigned int asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPathDeprecated:1;
    unsigned int asyncDelegateScrollViewWillEndDraggingWithVelocityTargetContentOffset:1;
    unsigned int asyncDelegateTableViewWillBeginBatchFetchWithContext:1;
    unsigned int asyncDelegateShouldBatchFetchForTableView:1;
    unsigned int asyncDelegateTableViewConstrainedSizeForRowAtIndexPath:1;
  } _asyncDelegateFlags;
  
  struct {
    unsigned int asyncDataSourceNumberOfSectionsInTableView:1;
    unsigned int asyncDataSourceTableViewNodeBlockForRowAtIndexPath:1;
    unsigned int asyncDataSourceTableViewNodeForRowAtIndexPath:1;
  } _asyncDataSourceFlags;
}

@property (nonatomic, strong, readwrite) ASDataController *dataController;

// Used only when ASTableView is created directly rather than through ASTableNode.
// We create a node so that logic related to appearance, memory management, etc can be located there
// for both the node-based and view-based version of the table.
// This also permits sharing logic with ASCollectionNode, as the superclass is not UIKit-controlled.
@property (nonatomic, strong) ASTableNode *strongTableNode;

// Always set, whether ASCollectionView is created directly or via ASCollectionNode.
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
  
  _dataController = [[dataControllerClass alloc] init];
  _dataController.dataSource = self;
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
  return [self _initWithFrame:frame style:style dataControllerClass:nil ownedByNode:NO];
}

// FIXME: This method is deprecated and will probably be removed in or shortly after 2.0.
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  return [self _initWithFrame:frame style:style dataControllerClass:nil ownedByNode:NO];
}

- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass ownedByNode:(BOOL)ownedByNode
{
  if (!(self = [super initWithFrame:frame style:style])) {
    return nil;
  }
  _cellsForVisibilityUpdates = [NSMutableSet set];
  if (!dataControllerClass) {
    dataControllerClass = [[self class] dataControllerClass];
  }
  
  [self configureWithDataControllerClass:dataControllerClass];
  
  if (!ownedByNode) {
    // See commentary at the definition of .strongTableNode for why we create an ASTableNode.
    // FIXME: The _view pointer of the node retains us, but the node will die immediately if we don't
    // retain it.  At the moment there isn't a great solution to this, so we can't yet move our core
    // logic to ASTableNode (required to have a shared superclass with ASCollection*).
    ASTableNode *tableNode = nil; //[[ASTableNode alloc] _initWithTableView:self];
    self.strongTableNode = tableNode;
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

- (void)setAsyncDataSource:(id<ASTableViewDataSource>)asyncDataSource
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
    
    _asyncDataSourceFlags.asyncDataSourceNumberOfSectionsInTableView = [_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)];
    _asyncDataSourceFlags.asyncDataSourceTableViewNodeForRowAtIndexPath = [_asyncDataSource respondsToSelector:@selector(tableView:nodeForRowAtIndexPath:)];
    _asyncDataSourceFlags.asyncDataSourceTableViewNodeBlockForRowAtIndexPath = [_asyncDataSource respondsToSelector:@selector(tableView:nodeBlockForRowAtIndexPath:)];
    
    // Data source must implement tableView:nodeBlockForRowAtIndexPath: or tableView:nodeForRowAtIndexPath:
    ASDisplayNodeAssertTrue(_asyncDataSourceFlags.asyncDataSourceTableViewNodeBlockForRowAtIndexPath || _asyncDataSourceFlags.asyncDataSourceTableViewNodeForRowAtIndexPath);
  }
  
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASTableViewDelegate>)asyncDelegate
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
    
    _asyncDelegateFlags.asyncDelegateScrollViewDidScroll = [_asyncDelegate respondsToSelector:@selector(scrollViewDidScroll:)];
    _asyncDelegateFlags.asyncDelegateTableViewWillDisplayNodeForRowAtIndexPath = [_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPath = [_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNode:forRowAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPathDeprecated = [_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNodeForRowAtIndexPath:)];
    _asyncDelegateFlags.asyncDelegateScrollViewWillEndDraggingWithVelocityTargetContentOffset = [_asyncDelegate respondsToSelector:@selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)];
    _asyncDelegateFlags.asyncDelegateTableViewWillBeginBatchFetchWithContext = [_asyncDelegate respondsToSelector:@selector(tableView:willBeginBatchFetchWithContext:)];
    _asyncDelegateFlags.asyncDelegateShouldBatchFetchForTableView = [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForTableView:)];
    _asyncDelegateFlags.asyncDelegateScrollViewWillBeginDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)];
    _asyncDelegateFlags.asyncDelegateScrollViewDidEndDragging = [_asyncDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)];
    _asyncDelegateFlags.asyncDelegateTableViewConstrainedSizeForRowAtIndexPath = [_asyncDelegate respondsToSelector:@selector(tableView:constrainedSizeForRowAtIndexPath:)];

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

- (NSArray<NSArray <ASCellNode *> *> *)completedNodes
{
  return [_dataController completedNodes];
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [_dataController indexPathForNode:cellNode];
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

  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  [_rangeController configureContentView:cell.contentView forCellNode:node];

  cell.node = node;
  cell.backgroundColor = node.backgroundColor;
  cell.selectionStyle = node.selectionStyle;

  // the following ensures that we clip the entire cell to it's bounds if node.clipsToBounds is set (the default)
  // This is actually a workaround for a bug we are seeing in some rare cases (selected background view
  // overlaps other cells if size of ASCellNode has changed.)
  cell.clipsToBounds = node.clipsToBounds;

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  return node.calculatedSize.height;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [_dataController numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_dataController numberOfRowsInSection:section];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(_ASTableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  _pendingVisibleIndexPath = indexPath;
  
  ASCellNode *cellNode = [cell node];
  cellNode.scrollView = tableView;

  if (_asyncDelegateFlags.asyncDelegateTableViewWillDisplayNodeForRowAtIndexPath) {
    [_asyncDelegate tableView:self willDisplayNodeForRowAtIndexPath:indexPath];
  }
  
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:[self scrollDirection]];

  if (cellNode.neverShowPlaceholders) {
    [cellNode recursivelyEnsureDisplaySynchronously:YES];
  }
  
  if (ASSubclassOverridesSelector([ASCellNode class], [cellNode class], @selector(cellNodeVisibilityEvent:inScrollView:withCellFrame:))) {
    [_cellsForVisibilityUpdates addObject:cell];
  }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(_ASTableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
  if ([_pendingVisibleIndexPath isEqual:indexPath]) {
    _pendingVisibleIndexPath = nil;
  }
  
  ASCellNode *cellNode = [cell node];

  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:[self scrollDirection]];

  if (_asyncDelegateFlags.asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPath) {
    ASDisplayNodeAssertNotNil(cellNode, @"Expected node associated with removed cell not to be nil.");
    [_asyncDelegate tableView:self didEndDisplayingNode:cellNode forRowAtIndexPath:indexPath];
  }

  if ([_cellsForVisibilityUpdates containsObject:cell]) {
    [_cellsForVisibilityUpdates removeObject:cell];
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if (_asyncDelegateFlags.asyncDelegateTableViewDidEndDisplayingNodeForRowAtIndexPathDeprecated) {
    [_asyncDelegate tableView:self didEndDisplayingNodeForRowAtIndexPath:indexPath];
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
  
  for (_ASTableViewCell *tableCell in _cellsForVisibilityUpdates) {
    [[tableCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventVisibleRectChanged
                                 inScrollView:scrollView
                                withCellFrame:tableCell.frame];
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
  for (_ASTableViewCell *tableViewCell in _cellsForVisibilityUpdates) {
    [[tableViewCell node] cellNodeVisibilityEvent:ASCellNodeVisibilityEventWillBeginDragging
                                          inScrollView:scrollView
                                         withCellFrame:tableViewCell.frame];
  }
  if (_asyncDelegateFlags.asyncDelegateScrollViewWillBeginDragging) {
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
  if (_asyncDelegateFlags.asyncDelegateScrollViewDidEndDragging) {
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
  BOOL canFetch = _asyncDelegateFlags.asyncDelegateTableViewWillBeginBatchFetchWithContext;
  if (canFetch && _asyncDelegateFlags.asyncDelegateShouldBatchFetchForTableView) {
    return [_asyncDelegate shouldBatchFetchForTableView:self];
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
  if (_asyncDelegateFlags.asyncDelegateTableViewWillBeginBatchFetchWithContext) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [_asyncDelegate tableView:self willBeginBatchFetchWithContext:_batchContext];
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
  if (CGRectEqualToRect(self.bounds, CGRectZero)) {
    return @[];
  }
  
  // In this case we cannot use indexPathsForVisibleRows in this case to get all the visible index paths as apparently
  // in a grouped UITableView it would return index paths for cells that are over the edge of the visible area.
  // Unfortunatly this means we never get a call for -tableView:cellForRowAtIndexPath: for that cells, but we will mark
  // mark them as visible in the range controller
  NSMutableArray *visibleIndexPaths = [NSMutableArray array];
  for (id cell in self.visibleCells) {
    [visibleIndexPaths addObject:[self indexPathForCell:cell]];
  }
  
  if (_pendingVisibleIndexPath) {
    NSMutableSet *indexPaths = [NSMutableSet setWithArray:visibleIndexPaths];
    
    BOOL (^isAfter)(NSIndexPath *, NSIndexPath *) = ^BOOL(NSIndexPath *indexPath, NSIndexPath *anchor) {
      if (!anchor || !indexPath) {
        return NO;
      }
      if (indexPath.section == anchor.section) {
        return (indexPath.row == anchor.row+1); // assumes that indexes are valid
        
      } else if (indexPath.section > anchor.section && indexPath.row == 0) {
        if (anchor.row != [_dataController numberOfRowsInSection:anchor.section] -1) {
          return NO;  // anchor is not at the end of the section
        }
        
        NSInteger nextSection = anchor.section+1;
        while([_dataController numberOfRowsInSection:nextSection] == 0) {
          ++nextSection;
        }
        
        return indexPath.section == nextSection;
      }
      
      return NO;
    };
    
    BOOL (^isBefore)(NSIndexPath *, NSIndexPath *) = ^BOOL(NSIndexPath *indexPath, NSIndexPath *anchor) {
      return isAfter(anchor, indexPath);
    };
    
    if ([indexPaths containsObject:_pendingVisibleIndexPath]) {
      _pendingVisibleIndexPath = nil; // once it has shown up in visibleIndexPaths, we can stop tracking it
    } else if (!isBefore(_pendingVisibleIndexPath, visibleIndexPaths.firstObject) &&
               !isAfter(_pendingVisibleIndexPath, visibleIndexPaths.lastObject)) {
      _pendingVisibleIndexPath = nil; // not contiguous, ignore.
    } else {
      [indexPaths addObject:_pendingVisibleIndexPath];
      
      [visibleIndexPaths removeAllObjects];
      [visibleIndexPaths addObjectsFromArray:[indexPaths.allObjects sortedArrayUsingSelector:@selector(compare:)]];
    }
  }
  
  return visibleIndexPaths;
}

- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths
{
  return [_dataController nodesAtIndexPaths:indexPaths];
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

#pragma mark - ASRangeControllerDelegate

- (void)didBeginUpdatesInRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  LOG(@"--- UITableView beginUpdates");

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

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
  });

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
    [self _scheduleCheckForBatchFetchingForNumberOfChanges:indexSet.count];
  });
}

#pragma mark - ASDataControllerDelegate

- (ASCellNodeBlock)dataController:(ASDataController *)dataController nodeBlockAtIndexPath:(NSIndexPath *)indexPath {
  if (![_asyncDataSource respondsToSelector:@selector(tableView:nodeBlockForRowAtIndexPath:)]) {
    ASCellNode *node = [_asyncDataSource tableView:self nodeForRowAtIndexPath:indexPath];
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

  ASCellNodeBlock block = [_asyncDataSource tableView:self nodeBlockForRowAtIndexPath:indexPath];
  __weak __typeof__(self) weakSelf = self;
  ASCellNodeBlock configuredNodeBlock = ^{
    __typeof__(self) strongSelf = weakSelf;
    ASCellNode *node = block();
    [node enterHierarchyState:ASHierarchyStateRangeManaged];
    if (node.interactionDelegate == nil) {
      node.interactionDelegate = strongSelf;
    }
    return node;
  };
  return configuredNodeBlock;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange constrainedSize = kInvalidSizeRange;
  if (_asyncDelegateFlags.asyncDelegateTableViewConstrainedSizeForRowAtIndexPath) {
    ASSizeRange delegateConstrainedSize = [_asyncDelegate tableView:self constrainedSizeForRowAtIndexPath:indexPath];
    // ignore widths in the returned size range (for TableView)
    constrainedSize = ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.min.height),
                                      CGSizeMake(_nodesConstrainedWidth, delegateConstrainedSize.max.height));
  } else {
    constrainedSize = ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, 0),
                                      CGSizeMake(_nodesConstrainedWidth, FLT_MAX));
  }
  return constrainedSize;
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  return [_asyncDataSource tableView:self numberOfRowsInSection:section];
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController
{
  if (_asyncDataSourceFlags.asyncDataSourceNumberOfSectionsInTableView) {
    return [_asyncDataSource numberOfSectionsInTableView:self];
  } else {
    return 1; // default section number
  }
}

#pragma mark - ASDataControllerEnvironmentDelegate

- (id<ASEnvironment>)dataControllerEnvironment
{
  if (self.tableNode) {
    return self.tableNode;
  }
  return self.strongTableNode;
}

#pragma mark - _ASTableViewCellDelegate

- (void)didLayoutSubviewsOfTableViewCell:(_ASTableViewCell *)tableViewCell
{
  CGFloat contentViewWidth = tableViewCell.contentView.bounds.size.width;
  ASCellNode *node = tableViewCell.node;
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
    CGSize calculatedSize = [[node measureWithSizeRange:constrainedSize] size];
    node.frame = CGRectMake(0, 0, calculatedSize.width, calculatedSize.height);
    [self endUpdates];
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
    [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:[self scrollDirection]];
  }
}

@end

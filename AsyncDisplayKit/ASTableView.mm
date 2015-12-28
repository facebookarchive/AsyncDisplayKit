/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTableViewInternal.h"

#import "ASAssert.h"
#import "ASBatchFetching.h"
#import "ASChangeSetDataController.h"
#import "ASCollectionViewLayoutController.h"
#import "ASDelegateProxy.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASLayoutController.h"
#import "ASRangeController.h"

#import <CoreFoundation/CoreFoundation.h>

static NSString * const kCellReuseIdentifier = @"_ASTableViewCell";

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

#pragma mark -
#pragma mark ASCellNode<->UITableViewCell bridging.

@class _ASTableViewCell;

@protocol _ASTableViewCellDelegate <NSObject>
- (void)willLayoutSubviewsOfTableViewCell:(_ASTableViewCell *)tableViewCell;
@end

@interface _ASTableViewCell : UITableViewCell
@property (nonatomic, weak) id<_ASTableViewCellDelegate> delegate;
@property (nonatomic, weak) ASCellNode *node;
@end

@implementation _ASTableViewCell
// TODO add assertions to prevent use of view-backed UITableViewCell properties (eg .textLabel)

- (void)layoutSubviews
{
  [_delegate willLayoutSubviewsOfTableViewCell:self];
  [super layoutSubviews];
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
  node.selected = self.selected;
  node.highlighted = self.highlighted;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
  [super setSelected:selected animated:animated];
  _node.selected = selected;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
  [super setHighlighted:highlighted animated:animated];
  _node.highlighted = highlighted;
}

@end

#pragma mark -
#pragma mark ASTableView

@interface ASTableNode ()
- (instancetype)_initWithTableView:(ASTableView *)tableView;
@end

@interface ASTableView () <ASRangeControllerDataSource, ASRangeControllerDelegate, ASDataControllerSource, _ASTableViewCellDelegate, ASCellNodeLayoutDelegate, ASDelegateProxyInterceptor> {
  ASTableViewProxy *_proxyDataSource;
  ASTableViewProxy *_proxyDelegate;

  ASFlowLayoutController *_layoutController;

  ASRangeController *_rangeController;

  BOOL _asyncDataFetchingEnabled;

  ASBatchContext *_batchContext;

  NSIndexPath *_pendingVisibleIndexPath;

  NSIndexPath *_contentOffsetAdjustmentTopVisibleRow;
  CGFloat _contentOffsetAdjustment;

  CGFloat _nodesConstrainedWidth;
  BOOL _ignoreNodesConstrainedWidthChange;
  BOOL _queuedNodeHeightUpdate;
  BOOL _isDeallocating;
}

@property (atomic, assign) BOOL asyncDataSourceLocked;
@property (nonatomic, retain, readwrite) ASDataController *dataController;

// Used only when ASTableView is created directly rather than through ASTableNode.
// We create a node so that logic related to appearance, memory management, etc can be located there
// for both the node-based and view-based version of the table.
// This also permits sharing logic with ASCollectionNode, as the superclass is not UIKit-controlled.
@property (nonatomic, retain) ASTableNode *strongTableNode;

@end

@implementation ASTableView

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
  
  _dataController = [[dataControllerClass alloc] initWithAsyncDataFetching:NO];
  _dataController.dataSource = self;
  _dataController.delegate = _rangeController;
  
  _layoutController.dataSource = _dataController;

  _asyncDataFetchingEnabled = NO;
  _asyncDataSourceLocked = NO;

  _leadingScreensForBatching = 1.0;
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
  
  if (!dataControllerClass) {
    dataControllerClass = [self.class dataControllerClass];
  }
  
  [self configureWithDataControllerClass:dataControllerClass];
  
  if (!ownedByNode) {
    // See commentary at the definition of .strongTableNode for why we create an ASTableNode.
    ASTableNode *tableNode = [[ASTableNode alloc] _initWithTableView:self];
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
  // will return as nil (ARC magic) even though the _proxyDataSource still exists. It's really important to nil out
  // super.dataSource in this case because calls to ASTableViewProxy will start failing and cause crashes.
  
  super.dataSource = nil;
  
  if (asyncDataSource == nil) {
    _asyncDataSource = nil;
    _proxyDataSource = _isDeallocating ? nil : [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[ASTableViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
  }
  
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASTableViewDelegate>)asyncDelegate
{
  // Note: It's common to check if the value hasn't changed and short-circuit but we aren't doing that here to handle
  // the (common) case of nilling the asyncDelegate in the ViewController's dealloc. In this case our _asyncDelegate
  // will return as nil (ARC magic) even though the _proxyDelegate still exists. It's really important to nil out
  // super.delegate in this case because calls to ASTableViewProxy will start failing and cause crashes.
  
  // Order is important here, the asyncDelegate must be callable while nilling super.delegate to avoid random crashes
  // in UIScrollViewAccessibility.

  super.delegate = nil;
  
  if (asyncDelegate == nil) {
    _asyncDelegate = nil;
    _proxyDelegate = _isDeallocating ? nil : [[ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  } else {
    _asyncDelegate = asyncDelegate;
    _proxyDelegate = [[ASTableViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
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
  ASDisplayNodeAssert(self.asyncDelegate, @"ASTableView's asyncDelegate property must be set.");
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

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [_dataController nodeAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [_dataController indexPathForNode:cellNode];
}

- (NSArray *)visibleNodes
{
  NSArray *indexPaths = [self indexPathsForVisibleRows];
  NSMutableArray *visibleNodes = [[NSMutableArray alloc] init];

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
  [_dataController insertSections:sections withAnimationOptions:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  [_dataController deleteSections:sections withAnimationOptions:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
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
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
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
  // Maintain the users visible window when inserting or deleteing cells by adjusting the content offset for nodes
  // before the visible area. If in a begin/end updates block this will update _contentOffsetAdjustment, otherwise it will
  // update self.contentOffset directly.

  ASDisplayNodeAssert(_automaticallyAdjustsContentOffset, @"this method should only be called when _automaticallyAdjustsContentOffset == YES");

  CGFloat dir = (inserting) ? +1 : -1;
  CGFloat adjustment = 0;
  NSIndexPath *top = _contentOffsetAdjustmentTopVisibleRow ?: self.indexPathsForVisibleRows.firstObject;

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

#pragma mark -
#pragma mark Intercepted selectors

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

- (ASScrollDirection)scrollDirection
{
  CGPoint scrollVelocity = [self.panGestureRecognizer velocityInView:self.superview];
  ASScrollDirection direction = ASScrollDirectionNone;
  if (scrollVelocity.y > 0) {
    direction = ASScrollDirectionDown;
  } else {
    direction = ASScrollDirectionUp;
  }
  
  return direction;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  _pendingVisibleIndexPath = indexPath;

  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self willDisplayNodeForRowAtIndexPath:indexPath];
  }

  ASCellNode *cellNode = [self nodeForRowAtIndexPath:indexPath];
  if (cellNode.neverShowPlaceholders) {
    [cellNode recursivelyEnsureDisplaySynchronously:YES];
  }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
  if ([_pendingVisibleIndexPath isEqual:indexPath]) {
    _pendingVisibleIndexPath = nil;
  }

  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self didEndDisplayingNodeForRowAtIndexPath:indexPath];
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
  BOOL canFetch = [_asyncDelegate respondsToSelector:@selector(tableView:willBeginBatchFetchWithContext:)];
  if (canFetch && [_asyncDelegate respondsToSelector:@selector(shouldBatchFetchForTableView:)]) {
    return [_asyncDelegate shouldBatchFetchForTableView:self];
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
      [_asyncDelegate tableView:self willBeginBatchFetchWithContext:_batchContext];
    });
  }
}

#pragma mark - ASRangeControllerDataSource

- (NSArray *)visibleNodeIndexPathsForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  
  NSArray *visibleIndexPaths = self.indexPathsForVisibleRows;
  
  if (_pendingVisibleIndexPath) {
    NSMutableSet *indexPaths = [NSMutableSet setWithArray:self.indexPathsForVisibleRows];
    
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
      visibleIndexPaths = [indexPaths.allObjects sortedArrayUsingSelector:@selector(compare:)];
    }
  }
  
  return visibleIndexPaths;
}

- (NSArray *)rangeController:(ASRangeController *)rangeController nodesAtIndexPaths:(NSArray *)indexPaths
{
  return [_dataController nodesAtIndexPaths:indexPaths];
}

- (CGSize)viewportSizeForRangeController:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
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

- (void)rangeController:(ASRangeController *)rangeController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  LOG(@"UITableView insertRows:%ld rows", indexPaths.count);

  if (!self.asyncDataSource) {
    return; // if the asyncDataSource has become invalid while we are processing, ignore this request to avoid crashes
  }

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    [super insertRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
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
    [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
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
    [super insertSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
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
    [super deleteSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
  });
}

#pragma mark - ASDataControllerDelegate

- (ASCellNode *)dataController:(ASDataController *)dataController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_asyncDataSource tableView:self nodeForRowAtIndexPath:indexPath];
  [node enterHierarchyState:ASHierarchyStateRangeManaged];
  
  ASDisplayNodeAssert([node isKindOfClass:ASCellNode.class], @"invalid node class, expected ASCellNode");
  if (node.layoutDelegate == nil) {
    node.layoutDelegate = self;
  }
  return node;
}

- (ASSizeRange)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake(CGSizeMake(_nodesConstrainedWidth, 0),
                         CGSizeMake(_nodesConstrainedWidth, FLT_MAX));
}

- (void)dataControllerLockDataSource
{
  ASDisplayNodeAssert(!self.asyncDataSourceLocked, @"The data source has already been locked");

  self.asyncDataSourceLocked = YES;

  if ([_asyncDataSource respondsToSelector:@selector(tableViewLockDataSource:)]) {
    [_asyncDataSource tableViewLockDataSource:self];
  }
}

- (void)dataControllerUnlockDataSource
{
  ASDisplayNodeAssert(self.asyncDataSourceLocked, @"The data source has already been unlocked");

  self.asyncDataSourceLocked = NO;

  if ([_asyncDataSource respondsToSelector:@selector(tableViewUnlockDataSource:)]) {
    [_asyncDataSource tableViewUnlockDataSource:self];
  }
}

- (NSUInteger)dataController:(ASDataController *)dataController rowsInSection:(NSUInteger)section
{
  return [_asyncDataSource tableView:self numberOfRowsInSection:section];
}

- (NSUInteger)numberOfSectionsInDataController:(ASDataController *)dataController
{
  if ([_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
    return [_asyncDataSource numberOfSectionsInTableView:self];
  } else {
    return 1; // default section number
  }
}

#pragma mark - _ASTableViewCellDelegate

- (void)willLayoutSubviewsOfTableViewCell:(_ASTableViewCell *)tableViewCell
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

#pragma mark - ASCellNodeLayoutDelegate

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
  for (NSArray *section in [_dataController completedNodes]) {
    for (ASDisplayNode *node in section) {
      [node recursivelyClearContents];
    }
  }
}

- (void)clearFetchedData
{
  for (NSArray *section in [_dataController completedNodes]) {
    for (ASDisplayNode *node in section) {
      [node recursivelyClearFetchedData];
    }
  }
}

@end

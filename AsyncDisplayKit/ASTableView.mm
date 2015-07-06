/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTableView.h"

#import "ASAssert.h"
#import "ASDataController.h"
#import "ASCollectionViewLayoutController.h"
#import "ASLayoutController.h"
#import "ASRangeController.h"
#import "ASDisplayNodeInternal.h"
#import "ASBatchFetching.h"


#pragma mark -
#pragma mark Proxying.

/**
 * ASTableView intercepts and/or overrides a few of UITableView's critical data source and delegate methods.
 *
 * Any selector included in this function *MUST* be implemented by ASTableView.
 */
static BOOL _isInterceptedSelector(SEL sel)
{
  return (
          // handled by ASTableView node<->cell machinery
          sel == @selector(tableView:cellForRowAtIndexPath:) ||
          sel == @selector(tableView:heightForRowAtIndexPath:) ||

          // handled by ASRangeController
          sel == @selector(numberOfSectionsInTableView:) ||
          sel == @selector(tableView:numberOfRowsInSection:) ||

          // used for ASRangeController visibility updates
          sel == @selector(tableView:willDisplayCell:forRowAtIndexPath:) ||
          sel == @selector(tableView:didEndDisplayingCell:forRowAtIndexPath:) ||

          // used for batch fetching API
          sel == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)
          );
}


/**
 * Stand-in for UITableViewDataSource and UITableViewDelegate.  Any method calls we intercept are routed to ASTableView;
 * everything else leaves AsyncDisplayKit safely and arrives at the original intended data source and delegate.
 */
@interface _ASTableViewProxy : NSProxy
- (instancetype)initWithTarget:(id<NSObject>)target interceptor:(ASTableView *)interceptor;
@end

@implementation _ASTableViewProxy {
  id<NSObject> __weak _target;
  ASTableView * __weak _interceptor;
}

- (instancetype)initWithTarget:(id<NSObject>)target interceptor:(ASTableView *)interceptor
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
#pragma mark ASCellNode<->UITableViewCell bridging.

@interface _ASTableViewCell : UITableViewCell
@end

@implementation _ASTableViewCell
// TODO add assertions to prevent use of view-backed UITableViewCell properties (eg .textLabel)
@end


#pragma mark -
#pragma mark ASTableView

@interface ASTableView () <ASRangeControllerDelegate, ASDataControllerSource> {
  _ASTableViewProxy *_proxyDataSource;
  _ASTableViewProxy *_proxyDelegate;

  ASDataController *_dataController;
  ASFlowLayoutController *_layoutController;

  ASRangeController *_rangeController;

  BOOL _asyncDataFetchingEnabled;

  ASBatchContext *_batchContext;

  NSIndexPath *_pendingVisibleIndexPath;
}

@property (atomic, assign) BOOL asyncDataSourceLocked;

@end

@implementation ASTableView

/**
 @summary Conditionally performs UIView geometry changes in the given block without animation.
 
 Used primarily to circumvent UITableView forcing insertion animations when explicitly told not to via
 `UITableViewRowAnimationNone`. More info: https://github.com/facebook/AsyncDisplayKit/pull/445
 
 @param withoutAnimation Set to `YES` to perform given block without animation
 @param block Perform UIView geometry changes within the passed block
 */
void ASPerformBlockWithoutAnimation(BOOL withoutAnimation, void (^block)()) {
  if (withoutAnimation) {
    BOOL animationsEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    block();
    [UIView setAnimationsEnabled:animationsEnabled];
  } else {
    block();
  }
}

#pragma mark -
#pragma mark Lifecycle

- (void)configureWithAsyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  _layoutController = [[ASFlowLayoutController alloc] initWithScrollOption:ASFlowLayoutDirectionVertical];
  
  _rangeController = [[ASRangeController alloc] init];
  _rangeController.layoutController = _layoutController;
  _rangeController.delegate = self;

  _dataController = [[ASDataController alloc] initWithAsyncDataFetching:asyncDataFetchingEnabled];
  _dataController.dataSource = self;
  _dataController.delegate = _rangeController;
  
  _layoutController.dataSource = _dataController;

  _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  _asyncDataSourceLocked = NO;

  _leadingScreensForBatching = 1.0;
  _batchContext = [[ASBatchContext alloc] init];
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  return [self initWithFrame:frame style:style asyncDataFetching:NO];
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{
  if (!(self = [super initWithFrame:frame style:style]))
    return nil;

  // FIXME: asyncDataFetching is currently unreliable for some use cases.
  // https://github.com/facebook/AsyncDisplayKit/issues/385
  asyncDataFetchingEnabled = NO;
  
  [self configureWithAsyncDataFetching:asyncDataFetchingEnabled];

  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  if (!(self = [super initWithCoder:aDecoder]))
    return nil;

  [self configureWithAsyncDataFetching:NO];

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
#pragma mark Overrides

- (void)setDataSource:(id<UITableViewDataSource>)dataSource
{
  ASDisplayNodeAssert(NO, @"ASTableView uses asyncDataSource, not UITableView's dataSource property.");
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
  // super.dataSource in this case because calls to _ASTableViewProxy will start failing and cause crashes.

  if (asyncDataSource == nil) {
    super.dataSource = nil;
    _asyncDataSource = nil;
    _proxyDataSource = nil;
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[_ASTableViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
  }
}

- (void)setAsyncDelegate:(id<ASTableViewDelegate>)asyncDelegate
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
    _proxyDelegate = [[_ASTableViewProxy alloc] initWithTarget:asyncDelegate interceptor:self];
    super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
  }
}

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssert(self.asyncDelegate, @"ASTableView's asyncDelegate property must be set.");
  ASDisplayNodePerformBlockOnMainThread(^{
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOptions:UITableViewRowAnimationNone completion:completion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
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

- (NSArray *)visibleNodes
{
  NSArray *indexPaths = [self indexPathsForVisibleRows];
  NSMutableArray *visibleNodes = [[NSMutableArray alloc] init];

  [indexPaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    ASCellNode *visibleNode = [self nodeForRowAtIndexPath:obj];
    [visibleNodes addObject:visibleNode];
  }];

  return visibleNodes;
}

- (void)beginUpdates
{
  [_dataController beginUpdates];
}

- (void)endUpdates
{
  [_dataController endUpdates];
}


#pragma mark -
#pragma mark Editing

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController insertSections:sections withAnimationOptions:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController deleteSections:sections withAnimationOptions:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController reloadSections:sections withAnimationOptions:animation];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [_dataController moveSection:section toSection:newSection withAnimationOptions:UITableViewRowAnimationNone];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOptions:animation];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOptions:UITableViewRowAnimationNone];
}

#pragma mark -
#pragma mark Intercepted selectors

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *reuseIdentifier = @"_ASTableViewCell";

  _ASTableViewCell *cell = [self dequeueReusableCellWithIdentifier:reuseIdentifier];
  if (!cell) {
    cell = [[_ASTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
  }

  ASCellNode *node = [_dataController nodeAtIndexPath:indexPath];
  [_rangeController configureContentView:cell.contentView forCellNode:node];

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


#pragma mark -
#pragma mark ASRangeControllerDelegate

- (void)rangeControllerBeginUpdates:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  [super beginUpdates];
}

- (void)rangeControllerEndUpdates:(ASRangeController *)rangeController completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  [super endUpdates];

  if (completion) {
    completion(YES);
  }
}

- (NSArray *)rangeControllerVisibleNodeIndexPaths:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();

  NSArray *visibleIndexPaths = self.indexPathsForVisibleRows;

  if ( _pendingVisibleIndexPath ) {
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

    if ( [indexPaths containsObject:_pendingVisibleIndexPath]) {
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

- (CGSize)rangeControllerViewportSize:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
}

- (void)rangeController:(ASRangeController *)rangeController didInsertNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    [super insertRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
  });
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOptions];
  });
}

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    [super insertSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
  });
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();

  BOOL preventAnimation = animationOptions == UITableViewRowAnimationNone;
  ASPerformBlockWithoutAnimation(preventAnimation, ^{
    [super deleteSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOptions];
  });
}

#pragma mark - ASDataControllerDelegate

- (ASCellNode *)dataController:(ASDataController *)dataController nodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *node = [_asyncDataSource tableView:self nodeForRowAtIndexPath:indexPath];
  ASDisplayNodeAssert([node isKindOfClass:ASCellNode.class], @"invalid node class, expected ASCellNode");
  return node;
}

- (CGSize)dataController:(ASDataController *)dataController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  return CGSizeMake(self.bounds.size.width, FLT_MAX);
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

- (NSUInteger)dataControllerNumberOfSections:(ASDataController *)dataController
{
  if ([_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
    return [_asyncDataSource numberOfSectionsInTableView:self];
  } else {
    return 1; // default section number
  }
}

@end

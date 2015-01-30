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
#import "ASFlowLayoutController.h"
#import "ASLayoutController.h"
#import "ASRangeController.h"
#import "ASDisplayNodeInternal.h"



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
          sel == @selector(tableView:didEndDisplayingCell:forRowAtIndexPath:)
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
}

@property (atomic, assign) BOOL asyncDataSourceLocked;

@end

@implementation ASTableView

#pragma mark -
#pragma mark Lifecycle

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  return [self initWithFrame:frame style:style asyncDataFetching:NO];
}

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style asyncDataFetching:(BOOL)asyncDataFetchingEnabled
{

  if (!(self = [super initWithFrame:frame style:style]))
    return nil;

  _layoutController = [[ASFlowLayoutController alloc] initWithScrollOption:ASFlowLayoutDirectionVertical];

  _rangeController = [[ASRangeController alloc] init];
  _rangeController.layoutController = _layoutController;
  _rangeController.delegate = self;

  _dataController = [[ASDataController alloc] initWithAsyncDataFetching:asyncDataFetchingEnabled];
  _dataController.dataSource = self;
  _dataController.delegate = _rangeController;

  _proxyDelegate = [[_ASTableViewProxy alloc] initWithTarget:nil interceptor:self];
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;

  _asyncDataFetchingEnabled = asyncDataFetchingEnabled;
  _asyncDataSourceLocked = NO;

  return self;
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
  if (_asyncDataSource == asyncDataSource)
    return;

  if (asyncDataSource == nil) {
    _asyncDataSource = nil;
    _proxyDataSource = nil;
    super.dataSource = nil;
  } else {
    _asyncDataSource = asyncDataSource;
    _proxyDataSource = [[_ASTableViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
    super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
  }
}

- (void)setAsyncDelegate:(id<ASTableViewDelegate>)asyncDelegate
{
  if (_asyncDelegate == asyncDelegate)
    return;

  _asyncDelegate = asyncDelegate;
  _proxyDelegate = [[_ASTableViewProxy alloc] initWithTarget:asyncDelegate interceptor:self];
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
}

- (void)reloadData
{
  ASDisplayNodePerformBlockOnMainThread(^{
    [super reloadData];
  });
  [_dataController reloadDataWithAnimationOption:UITableViewRowAnimationNone];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRange:(ASLayoutRange)range
{
  [_layoutController setTuningParameters:tuningParameters forRange:range];
}

- (ASRangeTuningParameters)tuningParametersForRange:(ASLayoutRange)range
{
  return [_layoutController tuningParametersForRange:range];
}

- (ASRangeTuningParameters)rangeTuningParameters
{
  return [self tuningParametersForRange:ASLayoutRangeRender];
}

- (void)setRangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  [self setTuningParameters:tuningParameters forRange:ASLayoutRangeRender];
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
  [_dataController insertSections:sections withAnimationOption:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController deleteSections:sections withAnimationOption:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController reloadSections:sections withAnimationOption:animation];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [_dataController moveSection:section toSection:newSection withAnimationOption:UITableViewRowAnimationNone];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController insertRowsAtIndexPaths:indexPaths withAnimationOption:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController deleteRowsAtIndexPaths:indexPaths withAnimationOption:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [_dataController reloadRowsAtIndexPaths:indexPaths withAnimationOption:animation];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [_dataController moveRowAtIndexPath:indexPath toIndexPath:newIndexPath withAnimationOption:UITableViewRowAnimationNone];
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self willDisplayNodeForRowAtIndexPath:indexPath];
  }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChangeWithScrollDirection:self.scrollDirection];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self didEndDisplayingNodeForRowAtIndexPath:indexPath];
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
  return [self indexPathsForVisibleRows];
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

- (void)rangeController:(ASRangeController *)rangeController didInsertNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  ASDisplayNodeAssertMainThread();

  [super insertRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOption];
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteNodesAtIndexPaths:(NSArray *)indexPaths withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  ASDisplayNodeAssertMainThread();

  [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:(UITableViewRowAnimation)animationOption];
}

- (void)rangeController:(ASRangeController *)rangeController didInsertSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  ASDisplayNodeAssertMainThread();

  [super insertSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOption];
}

- (void)rangeController:(ASRangeController *)rangeController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOption:(ASDataControllerAnimationOptions)animationOption
{
  ASDisplayNodeAssertMainThread();

  [super deleteSections:indexSet withRowAnimation:(UITableViewRowAnimation)animationOption];
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
  ASDisplayNodeAssert(!self.asyncDataSourceLocked, @"The data source has already been locked !");

  self.asyncDataSourceLocked = YES;

  if ([_asyncDataSource respondsToSelector:@selector(tableViewLockDataSource:)]) {
    [_asyncDataSource tableViewLockDataSource:self];
  }
}

- (void)dataControllerUnlockDataSource
{
  ASDisplayNodeAssert(self.asyncDataSourceLocked, @"The data source has already been unlocked !");

  self.asyncDataSourceLocked = NO;

  if ([_asyncDataSource respondsToSelector:@selector(tableViewUnlockDataSource:)]) {
    [_asyncDataSource tableViewUnlockDataSource:self];
  }
}

- (NSUInteger)dataController:(ASDataController *)dataControllre rowsInSection:(NSUInteger)section
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

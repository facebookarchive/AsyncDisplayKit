/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTableView.h"

#import "ASAssert.h"
#import "ASRangeController.h"


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

  ASDisplayNodeAssert(target, @"target must not be nil");
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
#pragma mark ASTableView.

@interface ASTableView () <ASRangeControllerDelegate> {
  _ASTableViewProxy *_proxyDataSource;
  _ASTableViewProxy *_proxyDelegate;

  ASRangeController *_rangeController;
}

@end

@implementation ASTableView

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  if (!(self = [super initWithFrame:frame style:style]))
    return nil;

  _rangeController = [[ASRangeController alloc] init];
  _rangeController.delegate = self;

  return self;
}


#pragma mark -
#pragma mark Overrides.

- (void)reloadData
{
  [_rangeController rebuildData];
  [super reloadData];
}

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

  _asyncDataSource = asyncDataSource;
  _proxyDataSource = [[_ASTableViewProxy alloc] initWithTarget:_asyncDataSource interceptor:self];
  super.dataSource = (id<UITableViewDataSource>)_proxyDataSource;
}

- (void)setAsyncDelegate:(id<ASTableViewDelegate>)asyncDelegate
{
  if (_asyncDelegate == asyncDelegate)
    return;

  _asyncDelegate = asyncDelegate;
  _proxyDelegate = [[_ASTableViewProxy alloc] initWithTarget:_asyncDelegate interceptor:self];
  super.delegate = (id<UITableViewDelegate>)_proxyDelegate;
}

- (ASRangeTuningParameters)rangeTuningParameters
{
  return _rangeController.tuningParameters;
}

- (void)setRangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  _rangeController.tuningParameters = tuningParameters;
}

- (void)appendNodesWithIndexPaths:(NSArray *)indexPaths
{
  [_rangeController appendNodesWithIndexPaths:indexPaths];
}

#pragma mark Assertions.

- (void)throwUnimplementedException
{
  [[NSException exceptionWithName:@"UnimplementedException"
                           reason:@"ASTableView's update/editing support is not yet implemented.  Please see ASTableView.h."
                         userInfo:nil] raise];
}

- (void)beginUpdates
{
  [self throwUnimplementedException];
}

- (void)endUpdates
{
  [self throwUnimplementedException];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [self throwUnimplementedException];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self throwUnimplementedException];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [self throwUnimplementedException];
}

- (void)setEditing:(BOOL)editing
{
  [self throwUnimplementedException];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
  [self throwUnimplementedException];
}


#pragma mark -
#pragma mark Intercepted selectors.

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *reuseIdentifier = @"_ASTableViewCell";

  _ASTableViewCell *cell = [self dequeueReusableCellWithIdentifier:reuseIdentifier];
  if (!cell) {
    cell = [[_ASTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
  }

  [_rangeController configureContentView:cell.contentView forIndexPath:indexPath];

  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [_rangeController calculatedSizeForNodeAtIndexPath:indexPath].height;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [_rangeController numberOfSizedSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_rangeController numberOfSizedRowsInSection:section];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChange];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:willDisplayNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self willDisplayNodeForRowAtIndexPath:indexPath];
  }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
  [_rangeController visibleNodeIndexPathsDidChange];

  if ([_asyncDelegate respondsToSelector:@selector(tableView:didEndDisplayingNodeForRowAtIndexPath:)]) {
    [_asyncDelegate tableView:self didEndDisplayingNodeForRowAtIndexPath:indexPath];
  }
}


#pragma mark -
#pragma mark ASRangeControllerDelegate.

- (NSArray *)rangeControllerVisibleNodeIndexPaths:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return [self indexPathsForVisibleRows];
}

- (CGSize)rangeControllerViewportSize:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  return self.bounds.size;
}

- (NSInteger)rangeControllerSections:(ASRangeController *)rangeController
{
  ASDisplayNodeAssertMainThread();
  if ([_asyncDataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
    return [_asyncDataSource numberOfSectionsInTableView:self];
  } else {
    return 1;
  }
}

- (NSInteger)rangeController:(ASRangeController *)rangeController rowsInSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [_asyncDataSource tableView:self numberOfRowsInSection:section];
}

- (ASCellNode *)rangeController:(ASRangeController *)rangeController nodeForIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotMainThread();
  return [_asyncDataSource tableView:self nodeForRowAtIndexPath:indexPath];
}

- (CGSize)rangeController:(ASRangeController *)rangeController constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertNotMainThread();
  return CGSizeMake(self.bounds.size.width, FLT_MAX);
}

- (void)rangeController:(ASRangeController *)rangeController didSizeNodesWithIndexPaths:(NSArray *)indexPaths
{
  ASDisplayNodeAssertMainThread();
  [UIView performWithoutAnimation:^{
    [super beginUpdates];

    // -insertRowsAtIndexPaths:: is insufficient; UITableView also needs to be notified of section changes
    NSInteger sectionCount = [super numberOfSections];
    NSInteger newSectionCount = [_rangeController numberOfSizedSections];
    if (newSectionCount > sectionCount) {
      NSRange range = NSMakeRange(sectionCount, newSectionCount - sectionCount);
      NSIndexSet *sections = [NSIndexSet indexSetWithIndexesInRange:range];
      [super insertSections:sections withRowAnimation:UITableViewRowAnimationNone];
    }

    [super insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];

    [super endUpdates];
  }];
}


@end

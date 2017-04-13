//
//  ASTableNode.mm
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableNode.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASTableViewInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASRangeController.h>

#pragma mark - _ASTablePendingState

@interface _ASTablePendingState : NSObject
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;
@property (nonatomic, assign) ASLayoutRangeMode rangeMode;
@property (nonatomic, assign) BOOL allowsSelection;
@property (nonatomic, assign) BOOL allowsSelectionDuringEditing;
@property (nonatomic, assign) BOOL allowsMultipleSelection;
@property (nonatomic, assign) BOOL allowsMultipleSelectionDuringEditing;
@property (nonatomic, assign) BOOL inverted;
@end

@implementation _ASTablePendingState
- (instancetype)init
{
  self = [super init];
  if (self) {
    _rangeMode = ASLayoutRangeModeUnspecified;
    _allowsSelection = YES;
    _allowsSelectionDuringEditing = NO;
    _allowsMultipleSelection = NO;
    _allowsMultipleSelectionDuringEditing = NO;
    _inverted = NO;
  }
  return self;
}

@end

#pragma mark - ASTableView

@interface ASTableNode ()
{
  ASDN::RecursiveMutex _environmentStateLock;
}

@property (nonatomic, strong) _ASTablePendingState *pendingState;
@end

@implementation ASTableNode

#pragma mark Lifecycle

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  if (self = [super init]) {
    __weak __typeof__(self) weakSelf = self;
    [self setViewBlock:^{
      // Variable will be unused if event logging is off.
      __unused __typeof__(self) strongSelf = weakSelf;
      return [[ASTableView alloc] _initWithFrame:CGRectZero style:style dataControllerClass:nil eventLog:ASDisplayNodeGetEventLog(strongSelf)];
    }];
  }
  return self;
}

- (instancetype)init
{
  return [self initWithStyle:UITableViewStylePlain];
}

#pragma mark ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  ASTableView *view = self.view;
  view.tableNode    = self;

  if (_pendingState) {
    _ASTablePendingState *pendingState = _pendingState;
    self.pendingState    = nil;
    view.asyncDelegate   = pendingState.delegate;
    view.asyncDataSource = pendingState.dataSource;
    view.inverted        = pendingState.inverted;
    view.allowsSelection = pendingState.allowsSelection;
    view.allowsSelectionDuringEditing = pendingState.allowsSelectionDuringEditing;
    view.allowsMultipleSelection = pendingState.allowsMultipleSelection;
    view.allowsMultipleSelectionDuringEditing = pendingState.allowsMultipleSelectionDuringEditing;
    if (pendingState.rangeMode != ASLayoutRangeModeUnspecified) {
      [view.rangeController updateCurrentRangeWithMode:pendingState.rangeMode];
    }
  }
}

- (ASTableView *)view
{
  return (ASTableView *)[super view];
}

- (void)clearContents
{
  [super clearContents];
  [self.rangeController clearContents];
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  [super interfaceStateDidChange:newState fromState:oldState];
  [ASRangeController layoutDebugOverlayIfNeeded];
}

- (void)didEnterPreloadState
{
  // Intentionally allocate the view here so that super will trigger a layout pass on it which in turn will trigger the intial data load.
  // We can get rid of this call later when ASDataController, ASRangeController and ASCollectionLayout can operate without the view.
  [self view];
  [super didEnterPreloadState];
}

#if ASRangeControllerLoggingEnabled
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  NSLog(@"%@ - visible: YES", self);
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];
  NSLog(@"%@ - visible: NO", self);
}
#endif

- (void)didExitPreloadState
{
  [super didExitPreloadState];
  [self.rangeController clearPreloadedData];
}

#pragma mark Setter / Getter

// TODO: Implement this without the view. Then revisit ASLayoutElementCollectionTableSetTraitCollection
- (ASDataController *)dataController
{
  return self.view.dataController;
}

// TODO: Implement this without the view.
- (ASRangeController *)rangeController
{
  return self.view.rangeController;
}

- (_ASTablePendingState *)pendingState
{
  if (!_pendingState && ![self isNodeLoaded]) {
    _pendingState = [[_ASTablePendingState alloc] init];
  }
  ASDisplayNodeAssert(![self isNodeLoaded] || !_pendingState, @"ASTableNode should not have a pendingState once it is loaded");
  return _pendingState;
}

- (void)setInverted:(BOOL)inverted
{
  self.transform = inverted ? CATransform3DMakeScale(1, -1, 1)  : CATransform3DIdentity;
  if ([self pendingState]) {
    _pendingState.inverted = inverted;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.inverted = inverted;
  }
}

- (BOOL)inverted
{
  if ([self pendingState]) {
    return _pendingState.inverted;
  } else {
    return self.view.inverted;
  }
}

- (void)setDelegate:(id <ASTableDelegate>)delegate
{
  if ([self pendingState]) {
    _pendingState.delegate = delegate;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASTableView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDelegate = delegate;
    });
  }
}

- (id <ASTableDelegate>)delegate
{
  if ([self pendingState]) {
    return _pendingState.delegate;
  } else {
    return self.view.asyncDelegate;
  }
}

- (void)setDataSource:(id <ASTableDataSource>)dataSource
{
  if ([self pendingState]) {
    _pendingState.dataSource = dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASTableView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDataSource = dataSource;
    });
  }
}

- (id <ASTableDataSource>)dataSource
{
  if ([self pendingState]) {
    return _pendingState.dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    return self.view.asyncDataSource;
  }
}

- (void)setAllowsSelection:(BOOL)allowsSelection
{
  if ([self pendingState]) {
    _pendingState.allowsSelection = allowsSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsSelection = allowsSelection;
  }
}

- (BOOL)allowsSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsSelection;
  } else {
    return self.view.allowsSelection;
  }
}

- (void)setAllowsSelectionDuringEditing:(BOOL)allowsSelectionDuringEditing
{
  if ([self pendingState]) {
    _pendingState.allowsSelectionDuringEditing = allowsSelectionDuringEditing;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsSelectionDuringEditing = allowsSelectionDuringEditing;
  }
}

- (BOOL)allowsSelectionDuringEditing
{
  if ([self pendingState]) {
    return _pendingState.allowsSelectionDuringEditing;
  } else {
    return self.view.allowsSelectionDuringEditing;
  }
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelection = allowsMultipleSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsMultipleSelection = allowsMultipleSelection;
  }
}

- (BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsMultipleSelection;
  } else {
    return self.view.allowsMultipleSelection;
  }
}

- (void)setAllowsMultipleSelectionDuringEditing:(BOOL)allowsMultipleSelectionDuringEditing
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.allowsMultipleSelectionDuringEditing = allowsMultipleSelectionDuringEditing;
  }
}

- (BOOL)allowsMultipleSelectionDuringEditing
{
  if ([self pendingState]) {
    return _pendingState.allowsMultipleSelectionDuringEditing;
  } else {
    return self.view.allowsMultipleSelectionDuringEditing;
  }
}

#pragma mark ASRangeControllerUpdateRangeProtocol

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode
{
  if ([self pendingState]) {
    _pendingState.rangeMode = rangeMode;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    [self.rangeController updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark ASEnvironment

ASLayoutElementCollectionTableSetTraitCollection(_environmentStateLock)

#pragma mark - Range Tuning

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [self.rangeController setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

#pragma mark - Selection

- (void)selectRowAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
  } else {
    NSLog(@"Failed to select row at index path %@ because the row never reached the view.", indexPath);
  }

}

- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath != nil) {
    [tableView deselectRowAtIndexPath:indexPath animated:animated];
  } else {
    NSLog(@"Failed to deselect row at index path %@ because the row never reached the view.", indexPath);
  }
}

- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  } else {
    NSLog(@"Failed to scroll to row at index path %@ because the row never reached the view.", indexPath);
  }
}

#pragma mark - Querying Data

- (void)reloadDataInitiallyIfNeeded
{
  ASDisplayNodeAssertMainThread();
  if (!self.dataController.initialReloadDataHasBeenCalled) {
    // Note: Just calling reloadData isn't enough here – we need to
    // ensure that _nodesConstrainedWidth is updated first.
    [self.view layoutIfNeeded];
  }
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap numberOfItemsInSection:section];
}

- (NSInteger)numberOfSections
{
  ASDisplayNodeAssertMainThread();
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap numberOfSections];
}

- (NSArray<__kindof ASCellNode *> *)visibleNodes
{
  ASDisplayNodeAssertMainThread();
  return self.isNodeLoaded ? [self.view visibleNodes] : @[];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self.dataController.pendingMap indexPathForElement:cellNode.collectionElement];
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController.pendingMap elementForItemAtIndexPath:indexPath].node;
}

- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  return [tableView rectForRowAtIndexPath:indexPath];
}

- (nullable __kindof UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  indexPath = [tableView convertIndexPathFromTableNode:indexPath waitingIfNeeded:YES];
  if (indexPath == nil) {
    return nil;
  }
  return [tableView cellForRowAtIndexPath:indexPath];
}

- (nullable NSIndexPath *)indexPathForSelectedRow
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  NSIndexPath *indexPath = tableView.indexPathForSelectedRow;
  if (indexPath != nil) {
    return [tableView convertIndexPathToTableNode:indexPath];
  }
  return indexPath;
}

- (NSArray<NSIndexPath *> *)indexPathsForSelectedRows
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  return [tableView convertIndexPathsToTableNode:tableView.indexPathsForSelectedRows];
}

- (nullable NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;

  NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:point];
  if (indexPath != nil) {
    return [tableView convertIndexPathToTableNode:indexPath];
  }
  return indexPath;
}

- (nullable NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect
{
  ASDisplayNodeAssertMainThread();
  ASTableView *tableView = self.view;
  return [tableView convertIndexPathsToTableNode:[tableView indexPathsForRowsInRect:rect]];
}

- (NSArray<NSIndexPath *> *)indexPathsForVisibleRows
{
  ASDisplayNodeAssertMainThread();
  NSMutableArray *indexPathsArray = [NSMutableArray new];
  for (ASCellNode *cell in [self visibleNodes]) {
    NSIndexPath *indexPath = [self indexPathForNode:cell];
    if (indexPath) {
      [indexPathsArray addObject:indexPath];
    }
  }
  return indexPathsArray;
}

#pragma mark - Editing

- (void)reloadDataWithCompletion:(void (^)())completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadDataWithCompletion:completion];
  } else {
    if (completion) {
      completion();
    }
  }
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)relayoutItems
{
  [self.view relayoutItems];
}

- (void)performBatchAnimated:(BOOL)animated updates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    ASTableView *tableView = self.view;
    [tableView beginUpdates];
    if (updates) {
      updates();
    }
    [tableView endUpdatesAnimated:animated completion:completion];
  } else {
    if (updates) {
      updates();
    }
  }
}

- (void)performBatchUpdates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self performBatchAnimated:YES updates:updates completion:completion];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertSections:sections withRowAnimation:animation];
  }
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteSections:sections withRowAnimation:animation];
  }
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadSections:sections withRowAnimation:animation];
  }
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveSection:section toSection:newSection];
  }
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
  }
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
  }
}

- (void)waitUntilAllUpdatesAreCommitted
{
  ASDisplayNodeAssertMainThread();
  if (self.nodeLoaded) {
    [self.view waitUntilAllUpdatesAreCommitted];
  }
}

#pragma mark - Debugging (Private)

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [super propertiesForDebugDescription];
  [result addObject:@{ @"dataSource" : ASObjectDescriptionMakeTiny(self.dataSource) }];
  [result addObject:@{ @"delegate" : ASObjectDescriptionMakeTiny(self.delegate) }];
  return result;
}

@end

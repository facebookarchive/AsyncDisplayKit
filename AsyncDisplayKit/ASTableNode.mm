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

#import "ASTableNode.h"
#import "ASTableViewInternal.h"
#import "ASEnvironmentInternal.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASInternalHelpers.h"
#import "ASCellNode+Internal.h"
#import "AsyncDisplayKit+Debug.h"
#import "ASTableView+Undeprecated.h"

#pragma mark - _ASTablePendingState

@interface _ASTablePendingState : NSObject
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;
@property (assign, nonatomic) ASLayoutRangeMode rangeMode;
@end

@implementation _ASTablePendingState
- (instancetype)init
{
  self = [super init];
  if (self) {
    _rangeMode = ASLayoutRangeModeCount;
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

@interface ASTableView ()
- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass;
@end

@implementation ASTableNode

#pragma mark Lifecycle

- (instancetype)_initWithTableView:(ASTableView *)tableView
{
  // Avoid a retain cycle.  In this case, the ASTableView is creating us, and strongly retains us.
  ASTableView * __weak weakTableView = tableView;
  if (self = [super initWithViewBlock:^UIView *{ return weakTableView; }]) {
    __unused __weak ASTableView *view = [self view];
    return self;
  }
  return nil;
}

- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass
{
  ASDisplayNodeViewBlock tableViewBlock = ^UIView *{
    return [[ASTableView alloc] _initWithFrame:frame style:style dataControllerClass:dataControllerClass];
  };

  if (self = [super initWithViewBlock:tableViewBlock]) {
    return self;
  }
  return nil;
}

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  return [self _initWithFrame:CGRectZero style:style dataControllerClass:nil];
}

- (instancetype)init
{
  return [self _initWithFrame:CGRectZero style:UITableViewStylePlain dataControllerClass:nil];
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
    if (pendingState.rangeMode != ASLayoutRangeModeCount) {
      [view.rangeController updateCurrentRangeWithMode:pendingState.rangeMode];
    }
  }
}

- (void)dealloc
{
  self.delegate = nil;
  self.dataSource = nil;
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

- (void)clearFetchedData
{
  [super clearFetchedData];
  [self.rangeController clearFetchedData];
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  [super interfaceStateDidChange:newState fromState:oldState];
  [ASRangeController layoutDebugOverlayIfNeeded];
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

#pragma mark Setter / Getter

// TODO: Implement this without the view.
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

- (void)setDelegate:(id <ASTableDelegate>)delegate
{
  if ([self pendingState]) {
    _pendingState.delegate = delegate;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASTableNode should be loaded if pendingState doesn't exist");
    self.view.asyncDelegate = delegate;
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
    self.view.asyncDataSource = dataSource;
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

ASEnvironmentCollectionTableSetEnvironmentState(_environmentStateLock)

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

#pragma mark - Querying Data

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
  return [self.dataController numberOfRowsInSection:section];
}

- (NSInteger)numberOfSections
{
  return [self.dataController numberOfSections];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self.dataController indexPathForNode:cellNode];
}

- (ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [self.dataController nodeAtIndexPath:indexPath];
}

#pragma mark - Editing

- (void)reloadDataWithCompletion:(void (^)())completion
{
  [self.view reloadDataWithCompletion:completion];
}

- (void)reloadData
{
  [self reloadDataWithCompletion:nil];
}

- (void)performBatchAnimated:(BOOL)animated updates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self.view beginUpdates];
  updates();
  [self.view endUpdatesAnimated:animated completion:completion];
}

- (void)performBatchUpdates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self performBatchAnimated:YES updates:updates completion:completion];
}

- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view insertSections:sections withRowAnimation:animation];
}

- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view deleteSections:sections withRowAnimation:animation];
}

- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view reloadSections:sections withRowAnimation:animation];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [self.view moveSection:section toSection:newSection];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
  [self.view reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [self.view moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
}

- (void)waitUntilAllUpdatesAreCommitted
{
  [self.view waitUntilAllUpdatesAreCommitted];
}

@end

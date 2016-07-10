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
    return [[ASTableView alloc] _initWithFrame:frame style:style dataControllerClass:dataControllerClass ownedByNode:YES];
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

- (ASTableView *)view
{
  return (ASTableView *)[super view];
}

- (void)clearContents
{
  [super clearContents];
  [self.view clearContents];
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  [self.view clearFetchedData];
}

#if ASRangeControllerLoggingEnabled
- (void)visibleStateDidChange:(BOOL)isVisible
{
  [super visibleStateDidChange:isVisible];
  NSLog(@"%@ - visible: %d", self, isVisible);
}
#endif

#pragma mark Setter / Getter

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
    [self.view.rangeController updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark ASEnvironment

ASEnvironmentCollectionTableSetEnvironmentState(_environmentStateLock)

@end

//
//  ASTableNode.m
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASTableNode.h"

@interface _ASTablePendingState : NSObject
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;
@end

@implementation _ASTablePendingState
@end

@interface ASTableNode ()
@property (nonatomic) _ASTablePendingState *pendingState;
@end

@interface ASTableView ()
- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
@end

@implementation ASTableNode

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  if (self = [super initWithViewBlock:^UIView *{ return [[ASTableView alloc] _initWithFrame:CGRectZero style:style]; }]) {
    return self;
  }
  return nil;
}

- (void)didLoad
{
  [super didLoad];
  
  if (_pendingState) {
    _ASTablePendingState *pendingState = _pendingState;
    self.pendingState = nil;
    
    ASTableView *view    = self.view;
    view.asyncDelegate   = pendingState.delegate;
    view.asyncDataSource = pendingState.dataSource;
  }
}

- (_ASTablePendingState *)pendingState
{
  if (!_pendingState && ![self isNodeLoaded]) {
    self.pendingState = [[_ASTablePendingState alloc] init];
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

@end

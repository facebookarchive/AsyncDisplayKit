//
//  ASPendingStateController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASPendingStateController.h"
#import "ASThread.h"
#import "ASWeakSet.h"
#import "ASAssert.h"
#import "ASDisplayNodeInternal.h"

@interface ASPendingStateController()
{
  ASDN::Mutex _lock;

  struct ASPendingStateControllerFlags {
    unsigned pendingFlush:1;
  } _flags;
}

@property (nonatomic, strong, readonly) ASWeakSet<ASDisplayNode *> *dirtyNodes;
@end

@implementation ASPendingStateController

#pragma mark Lifecycle & Singleton

- (instancetype)init
{
  self = [super init];
  if (self) {
    _dirtyNodes = [ASWeakSet new];
  }
  return self;
}

+ (ASPendingStateController *)sharedInstance
{
  static dispatch_once_t onceToken;
  static ASPendingStateController *controller;
  dispatch_once(&onceToken, ^{
    controller = [ASPendingStateController new];
  });
  return controller;
}

#pragma mark External API

- (void)flush
{
  ASDisplayNodeAssertMainThread();
  [self flushNow];
}

- (void)registerNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssert(node.nodeLoaded, @"Expected display node to be loaded before it was registered with ASPendingStateController. Node: %@", node);
  ASDN::MutexLocker l(_lock);
  [_dirtyNodes addObject:node];

  [self scheduleFlushIfNeeded];
}

#pragma mark Private Methods

/**
 This method is assumed to be called with the lock held.
 */
- (void)scheduleFlushIfNeeded
{
  if (_flags.pendingFlush) {
    return;
  }

  _flags.pendingFlush = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self flushNow];
  });
}

/**
 * NOTE: There is a small re-entrancy hazard here.
 * If the user gives us a subclass of UIView/CALayer that
 * adds side-effects to property sets, and one side effect
 * waits on a background thread that sets a view/layer property
 * on a loaded node, then we've got a deadlock.
 */
- (void)flushNow
{
  ASDN::MutexLocker l(_lock);
  for (ASDisplayNode *node in _dirtyNodes) {
    [node applyPendingViewState];
  }
  [_dirtyNodes removeAllObjects];
  _flags.pendingFlush = NO;
}

@end

@implementation ASPendingStateController (Testing)

- (BOOL)test_isFlushScheduled
{
  return _flags.pendingFlush;
}

@end

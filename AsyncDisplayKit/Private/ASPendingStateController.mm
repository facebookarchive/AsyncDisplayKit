//
//  ASPendingStateController.mm
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASPendingStateController.h"
#import "ASThread.h"
#import "ASWeakSet.h"
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
    _dirtyNodes = [[ASWeakSet alloc] init];
  }
  return self;
}

+ (ASPendingStateController *)sharedInstance
{
  static dispatch_once_t onceToken;
  static ASPendingStateController *controller = nil;
  dispatch_once(&onceToken, ^{
    controller = [[ASPendingStateController alloc] init];
  });
  return controller;
}

#pragma mark External API

- (void)registerNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssert(node.nodeLoaded, @"Expected display node to be loaded before it was registered with ASPendingStateController. Node: %@", node);
  ASDN::MutexLocker l(_lock);
  [_dirtyNodes addObject:node];

  [self scheduleFlushIfNeeded];
}

- (void)flush
{
  ASDisplayNodeAssertMainThread();
  _lock.lock();
    ASWeakSet *dirtyNodes = _dirtyNodes;
    _dirtyNodes = [[ASWeakSet alloc] init];
    _flags.pendingFlush = NO;
  _lock.unlock();

  for (ASDisplayNode *node in dirtyNodes) {
    [node applyPendingViewState];
  }
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
    [self flush];
  });
}

@end

@implementation ASPendingStateController (Testing)

- (BOOL)test_isFlushScheduled
{
  return _flags.pendingFlush;
}

@end

//
//  ASBridgedPropertiesTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASPendingStateController.h"
#import "ASDisplayNode.h"
#import "ASThread.h"
#import "ASDisplayNodeInternal.h"
#import "_ASPendingState.h"

@interface ASPendingStateController (Testing)
- (BOOL)test_isFlushScheduled;
@end

@interface ASBridgedPropertiesTests : XCTestCase

@end

/// Dispatches the given block synchronously onto a different thread.
/// This is useful for testing non-main-thread behavior because `dispatch_sync`
/// will often use the current thread.
static inline void ASDispatchSyncOnOtherThread(dispatch_block_t block) {
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(q, ^{
    ASDisplayNodeCAssertNotMainThread();
    block();
    dispatch_semaphore_signal(sem);
  });
  dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

@implementation ASBridgedPropertiesTests

- (void)testTheresASharedInstance
{
  XCTAssertNotNil([ASPendingStateController sharedInstance]);
}

- (void)testThatSettingABridgedPropertyInBackgroundGetsFlushedOnNextRunLoop
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  XCTAssertEqual(node.alpha, 1);
  ASDispatchSyncOnOtherThread(^{
    node.alpha = 0;
  });
  [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
  XCTAssertEqual(node.alpha, 0);
}

- (void)testThatReadingABridgedPropertyInBackgroundThrowsAnException
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  ASDispatchSyncOnOtherThread(^{
    XCTAssertThrows(node.alpha);
  });
}

- (void)testThatManuallyFlushingTheSyncControllerImmediatelyAppliesChanges
{
  ASPendingStateController *ctrl = [ASPendingStateController sharedInstance];
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  XCTAssertEqual(node.alpha, 1);
  ASDispatchSyncOnOtherThread(^{
    node.alpha = 0;
  });
  XCTAssertEqual(node.alpha, 1);
  [ctrl flush];
  XCTAssertEqual(node.alpha, 0);
  XCTAssertFalse(ctrl.test_isFlushScheduled);
}

- (void)testThatFlushingTheControllerInBackgroundThrows
{
  ASPendingStateController *ctrl = [ASPendingStateController sharedInstance];
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  XCTAssertEqual(node.alpha, 1);
  ASDispatchSyncOnOtherThread(^{
    node.alpha = 0;
    XCTAssertThrows([ctrl flush]);
  });
}

- (void)testThatSettingABridgedPropertyOnMainThreadPassesDirectlyToView
{
  ASPendingStateController *ctrl = [ASPendingStateController sharedInstance];
  ASDisplayNode *node = [ASDisplayNode new];
  XCTAssertFalse(node.pendingViewState.hasChanges);
  [node view];
  XCTAssertEqual(node.alpha, 1);
  node.alpha = 0;
  XCTAssertEqual(node.view.alpha, 0);
  XCTAssertEqual(node.alpha, 0);
  XCTAssertFalse(node.pendingViewState.hasChanges);
  XCTAssertFalse(ctrl.test_isFlushScheduled);
}

@end

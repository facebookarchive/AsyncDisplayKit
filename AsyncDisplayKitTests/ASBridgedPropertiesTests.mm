//
//  ASBridgedPropertiesTests.mm
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASPendingStateController.h"
#import "ASDisplayNode.h"
#import "ASThread.h"
#import "ASDisplayNodeInternal.h"
#import "_ASPendingState.h"
#import "ASCellNode.h"

@interface ASPendingStateController (Testing)
- (BOOL)test_isFlushScheduled;
@end

@interface ASBridgedPropertiesTestView : UIView
@property (nonatomic, readonly) BOOL receivedSetNeedsLayout;
@end

@implementation ASBridgedPropertiesTestView

- (void)setNeedsLayout
{
  _receivedSetNeedsLayout = YES;
  [super setNeedsLayout];
}

@end

@interface ASBridgedPropertiesTestNode : ASDisplayNode
@property (nullable, nonatomic, copy) dispatch_block_t onDealloc;
@end

@implementation ASBridgedPropertiesTestNode

- (void)dealloc {
  _onDealloc();
}

@end

@interface ASBridgedPropertiesTests : XCTestCase
@end

/// Dispatches the given block synchronously onto a different thread.
/// This is useful for testing non-main-thread behavior because `dispatch_sync`
/// will often use the current thread.
static inline void ASDispatchSyncOnOtherThread(dispatch_block_t block) {
  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_group_enter(group);
  dispatch_async(q, ^{
    ASDisplayNodeCAssertNotMainThread();
    block();
    dispatch_group_leave(group);
  });
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
}

@implementation ASBridgedPropertiesTests

- (void)testTheresASharedInstance
{
  XCTAssertNotNil([ASPendingStateController sharedInstance]);
}

/// FIXME: This test is unreliable for an as-yet unknown reason
/// but that being intermittent, and this test being so strict, it's
/// reasonable to assume for now the failures don't reflect a framework bug.
/// See https://github.com/facebook/AsyncDisplayKit/pull/1048
- (void)DISABLED_testThatDirtyNodesAreNotRetained
{
  ASPendingStateController *ctrl = [ASPendingStateController sharedInstance];
  __block BOOL didDealloc = NO;
  @autoreleasepool {
    __attribute__((objc_precise_lifetime)) ASBridgedPropertiesTestNode *node = [ASBridgedPropertiesTestNode new];
    node.onDealloc = ^{
      didDealloc = YES;
    };
    [node view];
    XCTAssertEqual(node.alpha, 1);
    ASDispatchSyncOnOtherThread(^{
      node.alpha = 0;
    });
    XCTAssertEqual(node.alpha, 1);
    XCTAssert(ctrl.test_isFlushScheduled);
  }
  XCTAssertTrue(didDealloc);
}

- (void)testThatSettingABridgedViewPropertyInBackgroundGetsFlushedOnNextRunLoop
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  XCTAssertEqual(node.alpha, 1);
  ASDispatchSyncOnOtherThread(^{
    node.alpha = 0;
  });
  XCTAssertEqual(node.alpha, 1);
  [self waitForMainDispatchQueueToFlush];
  XCTAssertEqual(node.alpha, 0);
}

- (void)testThatSettingABridgedLayerPropertyInBackgroundGetsFlushedOnNextRunLoop
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  XCTAssertEqual(node.shadowOpacity, 0);
  ASDispatchSyncOnOtherThread(^{
    node.shadowOpacity = 1;
  });
  XCTAssertEqual(node.shadowOpacity, 0);
  [self waitForMainDispatchQueueToFlush];
  XCTAssertEqual(node.shadowOpacity, 1);
}

- (void)testThatReadingABridgedViewPropertyInBackgroundThrowsAnException
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  ASDispatchSyncOnOtherThread(^{
    XCTAssertThrows(node.alpha);
  });
}

- (void)testThatReadingABridgedLayerPropertyInBackgroundThrowsAnException
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node view];
  ASDispatchSyncOnOtherThread(^{
    XCTAssertThrows(node.contentsScale);
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
  XCTAssertFalse(ASDisplayNodeGetPendingState(node).hasChanges);
  [node view];
  XCTAssertEqual(node.alpha, 1);
  node.alpha = 0;
  XCTAssertEqual(node.view.alpha, 0);
  XCTAssertEqual(node.alpha, 0);
  XCTAssertFalse(ASDisplayNodeGetPendingState(node).hasChanges);
  XCTAssertFalse(ctrl.test_isFlushScheduled);
}

- (void)testThatCallingSetNeedsLayoutFromBackgroundCausesItToHappenLater
{
  ASDisplayNode *node = [[ASDisplayNode alloc] initWithViewClass:ASBridgedPropertiesTestView.class];
  ASBridgedPropertiesTestView *view = (ASBridgedPropertiesTestView *)node.view;
  XCTAssertFalse(view.receivedSetNeedsLayout);
  ASDispatchSyncOnOtherThread(^{
    XCTAssertNoThrow([node setNeedsLayout]);
  });
  XCTAssertFalse(view.receivedSetNeedsLayout);
  [self waitForMainDispatchQueueToFlush];
  XCTAssertTrue(view.receivedSetNeedsLayout);
}

- (void)testThatCallingSetNeedsLayoutOnACellNodeFromBackgroundIsSafe
{
  ASCellNode *node = [ASCellNode new];
  [node view];
  ASDispatchSyncOnOtherThread(^{
    XCTAssertNoThrow([node setNeedsLayout]);
  });
}

- (void)testThatCallingSetNeedsDisplayFromBackgroundCausesItToHappenLater
{
  ASDisplayNode *node = [ASDisplayNode new];
  [node.layer displayIfNeeded];
  XCTAssertFalse(node.layer.needsDisplay);
  ASDispatchSyncOnOtherThread(^{
    XCTAssertNoThrow([node setNeedsDisplay]);
  });
  XCTAssertFalse(node.layer.needsDisplay);
  [self waitForMainDispatchQueueToFlush];
  XCTAssertTrue(node.layer.needsDisplay);
}

/// [XCTExpectation expectationWithPredicate:] should handle this
/// but under Xcode 7.2.1 its polling interval is 1 second
/// which makes the tests really slow and I'm impatient.
- (void)waitForMainDispatchQueueToFlush
{
  __block BOOL done = NO;
  dispatch_async(dispatch_get_main_queue(), ^{
    done = YES;
  });
  while (!done) {
    [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
  }
}

@end

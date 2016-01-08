//
//  ASPendingStateControllerTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASPendingStateController.h"
#import "ASDisplayNode.h"

@interface ASPendingStateController (Testing)
- (BOOL)test_isFlushScheduled;
@end

@interface ASPendingStateControllerTests : XCTestCase

@end

@implementation ASPendingStateControllerTests

- (void)testTheresASharedInstance
{
  XCTAssertNotNil([ASPendingStateController sharedInstance]);
}

- (void)testThatRegisteringANodeCausesAtFlushAtRunLoopEnd
{
  ASPendingStateController *ctrl = [ASPendingStateController sharedInstance];
  ASDisplayNode *node = [ASDisplayNode new];
  XCTAssertFalse(ctrl.test_isFlushScheduled);
  [ctrl registerNode:node];
  XCTAssertTrue(ctrl.test_isFlushScheduled);
  NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:1];
  [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
  XCTAssertFalse(ctrl.test_isFlushScheduled);
}

@end

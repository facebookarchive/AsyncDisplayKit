/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASControlNode.h>

#import <XCTest/XCTest.h>

#define ACTION @selector(action)
#define ACTION_SENDER @selector(action:)
#define ACTION_SENDER_EVENT @selector(action:event:)
#define EVENT ASControlNodeEventTouchUpInside

@interface ReceiverController : UIViewController
@property (nonatomic) NSInteger hits;
@end
@implementation ReceiverController
@end

@interface ASActionController : ReceiverController
@end
@implementation ASActionController
- (void)action { self.hits++; }
@end

@interface ASActionSenderController : ReceiverController
@end
@implementation ASActionSenderController
- (void)action:(id)sender { self.hits++; }
@end

@interface ASActionSenderEventController : ReceiverController
@end
@implementation ASActionSenderEventController
- (void)action:(id)sender event:(UIEvent *)event { self.hits++; }
@end

@interface ASGestureController : ReceiverController
@end
@implementation ASGestureController
- (void)onGesture:(UIGestureRecognizer *)recognizer { self.hits++; }
- (void)action:(id)sender { self.hits++; }
@end

@interface ASControlNodeTests : XCTestCase

@end

@implementation ASControlNodeTests

- (void)testActionWithoutParameters {
  ASActionController *controller = [[ASActionController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:controller action:ACTION forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testActionAndSender {
  ASActionSenderController *controller = [[ASActionSenderController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:controller action:ACTION_SENDER forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testActionAndSenderAndEvent {
  ASActionSenderEventController *controller = [[ASActionSenderEventController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:controller action:ACTION_SENDER_EVENT forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testActionWithoutTarget {
  ASActionController *controller = [[ASActionController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:nil action:ACTION forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testActionAndSenderWithoutTarget {
  ASActionSenderController *controller = [[ASActionSenderController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:nil action:ACTION_SENDER forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testActionAndSenderAndEventWithoutTarget {
  ASActionSenderEventController *controller = [[ASActionSenderEventController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:nil action:ACTION_SENDER_EVENT forControlEvents:EVENT];
  [controller.view addSubview:node.view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testDeeperHierarchyWithoutTarget {
  ASActionController *controller = [[ASActionController alloc] init];
  UIView *view = [[UIView alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:nil action:ACTION forControlEvents:EVENT];
  [view addSubview:node.view];
  [controller.view addSubview:view];
  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the action event");
}

- (void)testTouchesWorkWithGestures {
  ASGestureController *controller = [[ASGestureController alloc] init];
  ASControlNode *node = [[ASControlNode alloc] init];
  [node addTarget:controller action:@selector(action:) forControlEvents:ASControlNodeEventTouchUpInside];
  [node.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(onGesture:)]];
  [controller.view addSubnode:node];

  [node sendActionsForControlEvents:EVENT withEvent:nil];
  XCTAssert(controller.hits == 1, @"Controller did not receive the tap event");
}

@end

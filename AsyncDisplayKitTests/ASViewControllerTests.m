//
//  ASViewControllerTests.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 8/23/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ASViewController.h"

@interface ASViewControllerTests : XCTestCase

@end

@implementation ASViewControllerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEdgesForExtendedLayout {
  ASViewController *testController = [[ASViewController alloc] initWithNode:[[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor whiteColor];
    return view;
  }]];
  testController.edgesForExtendedLayout = UIRectEdgeNone;
  UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:testController];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [window setRootViewController:navController];
  [window makeKeyAndVisible];
  
  XCTestExpectation *onscreen = [self expectationWithDescription:@"View controller on screen"];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    CGRect insetBounds = [[UIScreen mainScreen] bounds];
    insetBounds.origin.y = CGRectGetMaxY(navController.navigationBar.frame);
    insetBounds.size.height -= insetBounds.origin.y;
    XCTAssert(CGRectEqualToRect(testController.view.frame, insetBounds));
    [onscreen fulfill];
  });
  
  [self waitForExpectationsWithTimeout:10 handler:nil];
}

@end

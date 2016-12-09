//
//  ASViewControllerTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/NSInvocation+OCMAdditions.h>

@interface ASPagerNodeTestDataSourceTwo : NSObject <ASPagerDataSource>

@end

@implementation ASPagerNodeTestDataSourceTwo

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 5;
}

- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
  return ^{
    ASCellNode *cellNode = [ASCellNode new];
    cellNode.backgroundColor = [UIColor redColor];
    return cellNode;
  };
}

@end

@interface ASViewControllerTests : XCTestCase @end

@implementation ASViewControllerTests

- (void)testThatAutomaticSubnodeManagementScrollViewInsetsAreApplied
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  ASScrollNode *scrollNode = [[ASScrollNode alloc] init];
  node.layoutSpecBlock = ^(ASDisplayNode *node, ASSizeRange constrainedSize){
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:scrollNode];
  };
  ASViewController *vc = [[ASViewController alloc] initWithNode:node];
  window.rootViewController = [[UINavigationController alloc] initWithRootViewController:vc];
  [window makeKeyAndVisible];
  [window layoutIfNeeded];
  XCTAssertEqualObjects(NSStringFromCGRect(window.bounds), NSStringFromCGRect(node.frame));
  XCTAssertNotEqual(scrollNode.view.contentInset.top, 0);
}

- (void)testThatViewControllerFrameIsRightAfterCustomTransitionWithNonextendedEdges
{
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];

  ASViewController *vc = [[ASViewController alloc] initWithNode:node];
  vc.node.backgroundColor = [UIColor greenColor];
  vc.edgesForExtendedLayout = UIRectEdgeNone;

  UIViewController * oldVC = [[UIViewController alloc] init];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:oldVC];
  id navDelegate = [OCMockObject niceMockForProtocol:@protocol(UINavigationControllerDelegate)];
  id animator = [OCMockObject niceMockForProtocol:@protocol(UIViewControllerAnimatedTransitioning)];
  [[[[navDelegate expect] ignoringNonObjectArgs] andReturn:animator] navigationController:[OCMArg any] animationControllerForOperation:UINavigationControllerOperationPush fromViewController:[OCMArg any] toViewController:[OCMArg any]];
  [[[animator expect] andReturnValue:@0.3] transitionDuration:[OCMArg any]];
  XCTestExpectation *e = [self expectationWithDescription:@"Transition completed"];
  [[[animator expect] andDo:^(NSInvocation *invocation) {
    id<UIViewControllerContextTransitioning> ctx = [invocation getArgumentAtIndexAsObject:2];
    UIView *container = [ctx containerView];
    [container addSubview:vc.view];
    vc.view.alpha = 0;
    vc.view.frame = [ctx finalFrameForViewController:vc];
    [UIView animateWithDuration:0.3 animations:^{
      vc.view.alpha = 1;
      oldVC.view.alpha = 0;
    } completion:^(BOOL finished) {
      [oldVC.view removeFromSuperview];
      [ctx completeTransition:finished];
      [e fulfill];
    }];
  }] animateTransition:[OCMArg any]];
  nav.delegate = navDelegate;
  window.rootViewController = nav;
  [window makeKeyAndVisible];
  [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
  [nav pushViewController:vc animated:YES];

  [self waitForExpectationsWithTimeout:2 handler:nil];
 
  CGFloat navHeight = CGRectGetMaxY([nav.navigationBar convertRect:nav.navigationBar.bounds toView:window]);
  CGRect expectedRect, slice;
  CGRectDivide(window.bounds, &slice, &expectedRect, navHeight, CGRectMinYEdge);
  XCTAssertEqualObjects(NSStringFromCGRect(expectedRect), NSStringFromCGRect(node.frame));
  [navDelegate verify];
  [animator verify];
}

- (void)testThatRootPagerNodeDoesGetTheRightInsetWhilePoppingBack
{
  UICollectionViewCell *cell = nil;
  
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  
  ASPagerNodeTestDataSourceTwo *dataSource = [[ASPagerNodeTestDataSourceTwo alloc] init];
  ASPagerNode *pagerNode = [[ASPagerNode alloc] init];
  pagerNode.dataSource = dataSource;
  node.layoutSpecBlock = ^(ASDisplayNode *node, ASSizeRange constrainedSize){
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:pagerNode];
  };
  ASViewController *vc = [[ASViewController alloc] initWithNode:node];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  window.rootViewController = nav;
  [window makeKeyAndVisible];
  [window layoutIfNeeded];
  
  // Wait until view controller is visible
  XCTestExpectation *e = [self expectationWithDescription:@"Transition completed"];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    [e fulfill];
  });
  [self waitForExpectationsWithTimeout:2 handler:nil];
  
  // Test initial values
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  cell = [pagerNode.view cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
#pragma clang diagnostic pop
  XCTAssertEqualObjects(NSStringFromCGRect(window.bounds), NSStringFromCGRect(node.frame));
  XCTAssertEqualObjects(NSStringFromCGRect(window.bounds), NSStringFromCGRect(cell.frame));
  XCTAssertEqual(pagerNode.view.contentOffset.y, 0);
  XCTAssertEqual(pagerNode.view.contentInset.top, 0);
  
  e = [self expectationWithDescription:@"Transition completed"];
  // Push another view controller
  UIViewController *vc2 = [[UIViewController alloc] init];
  vc2.view.frame = nav.view.bounds;
  vc2.view.backgroundColor = [UIColor blueColor];
  [nav pushViewController:vc2 animated:YES];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.505 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    [e fulfill];
  });
  [self waitForExpectationsWithTimeout:2 handler:nil];
  
  // Pop view controller
  e = [self expectationWithDescription:@"Transition completed"];
  [vc2.navigationController popViewControllerAnimated:YES];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.505 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    [e fulfill];
  });
  [self waitForExpectationsWithTimeout:2 handler:nil];
  
  // Test values again after popping the view controller
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  cell = [pagerNode.view cellForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
#pragma clang diagnostic pop
  XCTAssertEqualObjects(NSStringFromCGRect(window.bounds), NSStringFromCGRect(node.frame));
  XCTAssertEqualObjects(NSStringFromCGRect(window.bounds), NSStringFromCGRect(cell.frame));
  XCTAssertEqual(pagerNode.view.contentOffset.y, 0);
  XCTAssertEqual(pagerNode.view.contentInset.top, 0);
}

@end

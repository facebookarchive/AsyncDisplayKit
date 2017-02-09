//
//  ASPagerNodeTests.m
//  AsyncDisplayKit
//
//  Created by Luke Parham on 11/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASPagerNodeTestDataSource : NSObject <ASPagerDataSource>
@end

@implementation ASPagerNodeTestDataSource

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  return self;
}

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 2;
}

- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
  return [[ASCellNode alloc] init];
}

@end

@interface ASPagerNodeTestController: UIViewController
@property (nonatomic, strong) ASPagerNodeTestDataSource *testDataSource;
@property (nonatomic, strong) ASPagerNode *pagerNode;
@end

@implementation ASPagerNodeTestController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Populate these immediately so that they're not unexpectedly nil during tests.
    self.testDataSource = [[ASPagerNodeTestDataSource alloc] init];

    self.pagerNode = [[ASPagerNode alloc] init];
    self.pagerNode.dataSource = self.testDataSource;
    
    [self.view addSubnode:self.pagerNode];
  }
  return self;
}

@end

@interface ASPagerNodeTests : XCTestCase
@property (nonatomic, strong) ASPagerNode *pagerNode;

@property (nonatomic, strong) ASPagerNodeTestDataSource *testDataSource;
@end

@implementation ASPagerNodeTests

- (void)testPagerReturnsIndexOfPages {
  ASPagerNodeTestController *testController = [self testController];
  
  ASCellNode *cellNode = [testController.pagerNode nodeForPageAtIndex:0];
  
  XCTAssertEqual([testController.pagerNode indexOfPageWithNode:cellNode], 0);
}

- (void)testPagerReturnsNotFoundForCellThatDontExistInPager {
  ASPagerNodeTestController *testController = [self testController];

  ASCellNode *badNode = [[ASCellNode alloc] init];
  
  XCTAssertEqual([testController.pagerNode indexOfPageWithNode:badNode], NSNotFound);
}

- (ASPagerNodeTestController *)testController {
  ASPagerNodeTestController *testController = [[ASPagerNodeTestController alloc] initWithNibName:nil bundle:nil];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [window makeKeyAndVisible];
  window.rootViewController = testController;
    
  [testController.pagerNode reloadData];
  [testController.pagerNode setNeedsLayout];
  
  return testController;
}

// Disabled due to flakiness https://github.com/facebook/AsyncDisplayKit/issues/2818
- (void)DISABLED_testThatRootPagerNodeDoesGetTheRightInsetWhilePoppingBack
{
  UICollectionViewCell *cell = nil;
  
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  
  ASPagerNodeTestDataSource *dataSource = [[ASPagerNodeTestDataSource alloc] init];
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

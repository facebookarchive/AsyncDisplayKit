//
//  ASPagerNodeTests.m
//  AsyncDisplayKit
//
//  Created by Luke Parham on 11/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASPagerNode.h"
#import "ASCellNode.h"

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

@end

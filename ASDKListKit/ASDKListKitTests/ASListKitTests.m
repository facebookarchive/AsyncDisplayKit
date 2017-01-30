//
//  ASListKitTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASListKitTestAdapterDataSource.h"
#import "ASXCTExtensions.h"
#import <JGMethodSwizzler/JGMethodSwizzler.h>

@interface ASListKitTests : XCTestCase

@property (nonatomic, strong) ASCollectionNode *collectionNode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) IGListAdapter *adapter;
@property (nonatomic, strong) ASListKitTestAdapterDataSource *dataSource;
@property (nonatomic, strong) UICollectionViewFlowLayout *layout;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic) NSInteger reloadDataCount;

@end

@implementation ASListKitTests

- (void)setUp
{
  [super setUp];

  [ASCollectionView swizzleInstanceMethod:@selector(reloadData) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, ASCollectionView *) {
      JGOriginalImplementation(void);
      _reloadDataCount++;
    };
  }];

  self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];

  self.layout = [[UICollectionViewFlowLayout alloc] init];
  self.collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:self.layout];
  self.collectionNode.frame = self.window.bounds;
  self.collectionView = self.collectionNode.view;

  [self.window addSubnode:self.collectionNode];

  IGListAdapterUpdater *updater = [[IGListAdapterUpdater alloc] init];

  self.dataSource = [[ASListKitTestAdapterDataSource alloc] init];
  self.adapter = [[IGListAdapter alloc] initWithUpdater:updater
                                         viewController:nil
                                       workingRangeSize:0];
  self.adapter.dataSource = self.dataSource;
  [self.adapter setASDKCollectionNode:self.collectionNode];
  XCTAssertNotNil(self.adapter.collectionView, @"Adapter was not bound to collection view. You may have a stale copy of AsyncDisplayKit that was built without IG_LIST_KIT. Clean Builder Folder IMO.");
}

- (void)tearDown
{
  [super tearDown];
  XCTAssert([ASCollectionView deswizzleAllMethods]);
  self.reloadDataCount = 0;
  self.window = nil;
  self.collectionNode = nil;
  self.collectionView = nil;
  self.adapter = nil;
  self.dataSource = nil;
  self.layout = nil;
}

- (void)test_whenAdapterUpdated_withObjectsOverflow_thatVisibleObjectsIsSubsetOfAllObjects
{
  // each section controller returns n items sized 100x10
  self.dataSource.objects = @[@1, @2, @3, @4, @5, @6];
  XCTestExpectation *e = [self expectationWithDescription:@"Data update completed"];

  [self.adapter performUpdatesAnimated:NO completion:^(BOOL finished) {
    [e fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1 handler:nil];
  self.collectionNode.view.contentOffset = CGPointMake(0, 30);
  [self.collectionNode.view layoutIfNeeded];


  NSArray *visibleObjects = [[self.adapter visibleObjects] sortedArrayUsingSelector:@selector(compare:)];
  NSArray *expectedObjects = @[@3, @4, @5];
  XCTAssertEqualObjects(visibleObjects, expectedObjects);
}

- (void)test_whenCollectionViewIsNotInAWindow_updaterDoesNotJustCallReloadData
{
  [self.collectionView removeFromSuperview];

  [self.collectionView layoutIfNeeded];
  self.dataSource.objects = @[@1, @2, @3, @4, @5, @6];
  XCTestExpectation *e = [self expectationWithDescription:@"Data update completed"];

  [self.adapter performUpdatesAnimated:NO completion:^(BOOL finished) {
    [e fulfill];
  }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
  [self.collectionView layoutIfNeeded];

  XCTAssertEqual(self.reloadDataCount, 2);
}

@end

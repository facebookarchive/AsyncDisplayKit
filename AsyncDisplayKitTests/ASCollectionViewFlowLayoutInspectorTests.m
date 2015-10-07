/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>

#import "ASCollectionView.h"
#import "ASCollectionViewFlowLayoutInspector.h"

@interface TestDataSource : NSObject <ASCollectionViewDataSource>
@end

@implementation TestDataSource

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [[ASCellNode alloc] init];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 2;
}

@end

@interface ASCollectionViewFlowLayoutInspectorTests : XCTestCase

@end

@implementation ASCollectionViewFlowLayoutInspectorTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - #collectionView:constrainedSizeForSupplementaryNodeOfKind:atIndexPath:



#pragma mark - #collectionView:numberOfSectionsForSupplementaryKind:

- (void)testThatItRespondsWithTheDefaultNumberOfSections
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout asyncDataFetching:NO];
  ASCollectionViewFlowLayoutInspector *inspector = [[ASCollectionViewFlowLayoutInspector alloc] initWithCollectionView:collectionView flowLayout:layout];
  NSUInteger sections = [inspector collectionView:collectionView numberOfSectionsForSupplementaryKind:UICollectionElementKindSectionHeader];
  XCTAssert(sections == 1, @"should return 1 by default");
}

- (void)testThatItProvidesTheNumberOfSectionsInTheDataSource
{
  TestDataSource *dataSource = [[TestDataSource alloc] init];
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout asyncDataFetching:NO];
  collectionView.asyncDataSource = dataSource;
  ASCollectionViewFlowLayoutInspector *inspector = [[ASCollectionViewFlowLayoutInspector alloc] initWithCollectionView:collectionView flowLayout:layout];
  NSUInteger sections = [inspector collectionView:collectionView numberOfSectionsForSupplementaryKind:UICollectionElementKindSectionHeader];
  XCTAssert(sections == 2, @"should return 2");
}

#pragma mark - #collectionView:supplementaryViewsOfKind:inSection:

@end

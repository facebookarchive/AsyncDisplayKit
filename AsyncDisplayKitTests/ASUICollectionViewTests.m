//
//  ASUICollectionViewTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/18/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface ASUICollectionViewTests : XCTestCase

@end

@implementation ASUICollectionViewTests

/// Test normal item-affiliated supplementary node
- (void)testNormalTwoIndexSupplementaryElement
{
  [self _testSupplementaryNodeAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:1] sectionCount:2 expectException:NO];
}

/// If your supp is indexPathForItem:inSection:, the section index must be in bounds
- (void)testThatSupplementariesWithItemIndexesMustBeWithinNormalSections
{
  [self _testSupplementaryNodeAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:3] sectionCount:2 expectException:YES];
}

/// If your supp is indexPathWithIndex:, that's OK even if that section is out of bounds!
- (void)testThatSupplementariesWithOneIndexAreOKOutOfSectionBounds
{
  [self _testSupplementaryNodeAtIndexPath:[NSIndexPath indexPathWithIndex:3] sectionCount:2 expectException:NO];
}

- (void)_testSupplementaryNodeAtIndexPath:(NSIndexPath *)indexPath sectionCount:(NSInteger)sectionCount expectException:(BOOL)shouldFail
{
  UICollectionViewLayoutAttributes *attr = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:@"SuppKind" withIndexPath:indexPath];
  attr.frame = CGRectMake(0, 0, 20, 20);
  UICollectionViewLayout *layout = [[UICollectionViewLayout alloc] init];
  id layoutMock = [OCMockObject partialMockForObject:layout];

  [[[[layoutMock expect] ignoringNonObjectArgs] andReturn:@[ attr ]] layoutAttributesForElementsInRect:CGRectZero];
  UICollectionView *cv = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) collectionViewLayout:layoutMock];
  [cv registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:@"SuppKind" withReuseIdentifier:@"ReuseID"];

  id dataSource = [OCMockObject niceMockForProtocol:@protocol(UICollectionViewDataSource)];
  __block id view = nil;
  [[[dataSource expect] andDo:^(NSInvocation *invocation) {
    NSIndexPath *indexPath = nil;
    [invocation getArgument:&indexPath atIndex:4];
    view = [cv dequeueReusableSupplementaryViewOfKind:@"SuppKind" withReuseIdentifier:@"ReuseID" forIndexPath:indexPath];
    [invocation setReturnValue:&view];
  }] collectionView:cv viewForSupplementaryElementOfKind:@"SuppKind" atIndexPath:indexPath];
  [[[dataSource expect] andReturnValue:[NSNumber numberWithInteger:sectionCount]] numberOfSectionsInCollectionView:cv];

  cv.dataSource = dataSource;
  if (shouldFail) {
    XCTAssertThrowsSpecificNamed([cv layoutIfNeeded], NSException, NSInternalInconsistencyException);
  } else {
    [cv layoutIfNeeded];
    XCTAssertEqualObjects(attr, [cv layoutAttributesForSupplementaryElementOfKind:@"SuppKind" atIndexPath:indexPath]);
    XCTAssertEqual(view, [cv supplementaryViewForElementKind:@"SuppKind" atIndexPath:indexPath]);
  }

  [dataSource verify];
  [layoutMock verify];
}

@end

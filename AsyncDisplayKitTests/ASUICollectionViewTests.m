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

/// Test that collection view throws an exception if your layout specifies
/// supplementaries in sections that are out of bounds (e.g. in section 5
/// when there's only 3 sections).
- (void)testThatSupplementariesMustBeWithinNormalSections
{
  NSInteger sectionCount = 2;
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:sectionCount];
  UICollectionViewLayoutAttributes *attr = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:@"SuppKind" withIndexPath:indexPath];
  UICollectionViewLayout *layout = [[UICollectionViewLayout alloc] init];
  id layoutMock = [OCMockObject partialMockForObject:layout];

  [[[[layoutMock expect] ignoringNonObjectArgs] andReturn:@[ attr ]]  layoutAttributesForElementsInRect:CGRectZero];
  UICollectionView *cv = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) collectionViewLayout:layoutMock];
  [cv registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:@"SuppKind" withReuseIdentifier:@"ReuseID"];

  id dataSource = [OCMockObject niceMockForProtocol:@protocol(UICollectionViewDataSource)];
  [[[dataSource expect] andDo:^(NSInvocation *invocation) {
    NSIndexPath *indexPath = nil;
    [invocation getArgument:&indexPath atIndex:4];
    id view = [cv dequeueReusableSupplementaryViewOfKind:@"SuppKind" withReuseIdentifier:@"ReuseID" forIndexPath:indexPath];
    [invocation setReturnValue:(__bridge void * _Nonnull)(view)];
  }] collectionView:cv viewForSupplementaryElementOfKind:@"SuppKind" atIndexPath:indexPath];
  [[[dataSource expect] andReturnValue:[NSNumber numberWithInteger:sectionCount]] numberOfSectionsInCollectionView:cv];

  cv.dataSource = dataSource;
  XCTAssertThrowsSpecificNamed([cv layoutIfNeeded], NSException, NSInternalInconsistencyException);
  [dataSource verify];
  [layoutMock verify];
}

@end

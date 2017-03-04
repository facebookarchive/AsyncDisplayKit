//
//  ASCollectionViewFlowLayoutInspectorTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "ASXCTExtensions.h"

#import <AsyncDisplayKit/ASCollectionView.h>
#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASCollectionViewFlowLayoutInspector.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>

@interface ASCollectionView (Private)

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout;

@end

/**
 * Test Data Source
 */
@interface InspectorTestDataSource : NSObject <ASCollectionDataSource>
@end

@implementation InspectorTestDataSource

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [[ASCellNode alloc] init];
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{ return [[ASCellNode alloc] init]; };
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

@protocol InspectorTestDataSourceDelegateProtocol <ASCollectionDataSource, ASCollectionDelegate>

@end

@interface InspectorTestDataSourceDelegateWithoutNodeConstrainedSize : NSObject <InspectorTestDataSourceDelegateProtocol>
@end

@implementation InspectorTestDataSourceDelegateWithoutNodeConstrainedSize

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{ return [[ASCellNode alloc] init]; };
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 0;
}

@end

@interface ASCollectionViewFlowLayoutInspectorTests : XCTestCase

@end

/**
 * Test Delegate for Header Reference Size Implementation
 */
@interface HeaderReferenceSizeTestDelegate : NSObject <ASCollectionDelegateFlowLayout>

@end

@implementation HeaderReferenceSizeTestDelegate

- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
  return CGSizeMake(125.0, 125.0);
}

@end

/**
 * Test Delegate for Footer Reference Size Implementation
 */
@interface FooterReferenceSizeTestDelegate : NSObject <ASCollectionDelegateFlowLayout>

@end

@implementation FooterReferenceSizeTestDelegate

- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
  return CGSizeMake(125.0, 125.0);
}

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

// Vertical

// Delegate implementation

- (void)testThatItReturnsAVerticalConstrainedSizeFromTheHeaderDelegateImplementation
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;

  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(collectionView.bounds.size.width, 125.0));

  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the values returned in the delegate implementation");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsAVerticalConstrainedSizeFromTheFooterDelegateImplementation
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  FooterReferenceSizeTestDelegate *delegate = [[FooterReferenceSizeTestDelegate alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(collectionView.bounds.size.width, 125.0));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the values returned in the delegate implementation");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

// Size implementation

- (void)testThatItReturnsAVerticalConstrainedSizeFromTheHeaderProperty
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;
  layout.headerReferenceSize = CGSizeMake(125.0, 125.0);
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(collectionView.bounds.size.width, 125.0));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the size set on the layout");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsAVerticalConstrainedSizeFromTheFooterProperty
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;
  layout.footerReferenceSize = CGSizeMake(125.0, 125.0);
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(collectionView.bounds.size.width, 125.0));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the size set on the layout");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

// Horizontal

- (void)testThatItReturnsAHorizontalConstrainedSizeFromTheHeaderDelegateImplementation
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(125.0, collectionView.bounds.size.height));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the values returned in the delegate implementation");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsAHorizontalConstrainedSizeFromTheFooterDelegateImplementation
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  FooterReferenceSizeTestDelegate *delegate = [[FooterReferenceSizeTestDelegate alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(125.0, collectionView.bounds.size.height));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the values returned in the delegate implementation");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

// Size implementation

- (void)testThatItReturnsAHorizontalConstrainedSizeFromTheHeaderProperty
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.headerReferenceSize = CGSizeMake(125.0, 125.0);
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionHeader atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(125.0, collectionView.bounds.size.width));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the size set on the layout");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsAHorizontalConstrainedSizeFromTheFooterProperty
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.footerReferenceSize = CGSizeMake(125.0, 125.0);
  
  CGRect rect = CGRectMake(0, 0, 100.0, 100.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:rect collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeMake(125.0, collectionView.bounds.size.height));
  ASXCTAssertEqualSizeRanges(size, sizeCompare, @"should have a size constrained by the size set on the layout");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsZeroSizeWhenNoReferenceSizeIsImplemented
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  ASSizeRange size = [inspector collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:UICollectionElementKindSectionFooter atIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  ASSizeRange sizeCompare = ASSizeRangeMake(CGSizeZero, CGSizeZero);
  XCTAssert(CGSizeEqualToSize(size.min, sizeCompare.min) && CGSizeEqualToSize(size.max, sizeCompare.max), @"should have a zero size");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

#pragma mark - #collectionView:supplementaryNodesOfKind:inSection:

- (void)testThatItReturnsOneWhenAValidSizeIsImplementedOnTheDelegate
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  NSUInteger count = [inspector collectionView:collectionView supplementaryNodesOfKind:UICollectionElementKindSectionHeader inSection:0];
  XCTAssert(count == 1, @"should have a header supplementary view");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsOneWhenAValidSizeIsImplementedOnTheLayout
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.footerReferenceSize = CGSizeMake(125.0, 125.0);
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  NSUInteger count = [inspector collectionView:collectionView supplementaryNodesOfKind:UICollectionElementKindSectionFooter inSection:0];
  XCTAssert(count == 1, @"should have a footer supplementary view");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItReturnsNoneWhenNoReferenceSizeIsImplemented
{
  InspectorTestDataSource *dataSource = [[InspectorTestDataSource alloc] init];
  HeaderReferenceSizeTestDelegate *delegate = [[HeaderReferenceSizeTestDelegate alloc] init];
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  collectionView.asyncDataSource = dataSource;
  collectionView.asyncDelegate = delegate;
  ASCollectionViewFlowLayoutInspector *inspector = ASDynamicCast(collectionView.layoutInspector, ASCollectionViewFlowLayoutInspector);
  NSUInteger count = [inspector collectionView:collectionView supplementaryNodesOfKind:UICollectionElementKindSectionFooter inSection:0];
  XCTAssert(count == 0, @"should not have a footer supplementary view");
  
  collectionView.asyncDataSource = nil;
  collectionView.asyncDelegate = nil;
}

- (void)testThatItThrowsIfNodeConstrainedSizeIsImplementedOnDataSourceButNotOnDelegateLayoutInspector
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionNode *node = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
  ASCollectionView *collectionView = node.view;
  
  id dataSourceAndDelegate = [OCMockObject mockForProtocol:@protocol(InspectorTestDataSourceDelegateProtocol)];
  ASSizeRange constrainedSize = ASSizeRangeMake(CGSizeZero, CGSizeZero);
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  NSValue *value = [NSValue value:&constrainedSize withObjCType:@encode(ASSizeRange)];
  [[[dataSourceAndDelegate stub] andReturnValue:value] collectionNode:node constrainedSizeForItemAtIndexPath:indexPath];
  node.dataSource = dataSourceAndDelegate;
  
  id delegate = [InspectorTestDataSourceDelegateWithoutNodeConstrainedSize new];
  node.delegate = delegate;
  
  ASCollectionViewLayoutInspector *inspector = [[ASCollectionViewLayoutInspector alloc] init];
  
  collectionView.layoutInspector = inspector;
  XCTAssertThrows([inspector collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath]);
  
  node.delegate = dataSourceAndDelegate;
  XCTAssertNoThrow([inspector collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath]);
}

- (void)testThatItThrowsIfNodeConstrainedSizeIsImplementedOnDataSourceButNotOnDelegateFlowLayoutInspector
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  
  ASCollectionNode *node = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
  ASCollectionView *collectionView = node.view;
  id dataSourceAndDelegate = [OCMockObject mockForProtocol:@protocol(InspectorTestDataSourceDelegateProtocol)];
  ASSizeRange constrainedSize = ASSizeRangeMake(CGSizeZero, CGSizeZero);
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  NSValue *value = [NSValue value:&constrainedSize withObjCType:@encode(ASSizeRange)];
  
  [[[dataSourceAndDelegate stub] andReturnValue:value] collectionNode:node constrainedSizeForItemAtIndexPath:indexPath];
  node.dataSource = dataSourceAndDelegate;
  id delegate = [InspectorTestDataSourceDelegateWithoutNodeConstrainedSize new];
  
  node.delegate = delegate;
  ASCollectionViewFlowLayoutInspector *inspector = collectionView.layoutInspector;

  XCTAssertThrows([inspector collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath]);
  
  node.delegate = dataSourceAndDelegate;
  XCTAssertNoThrow([inspector collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath]);
}

@end

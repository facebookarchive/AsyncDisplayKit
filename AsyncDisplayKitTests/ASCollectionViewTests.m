//
//  ASCollectionViewTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASCollectionView.h"
#import "ASCollectionDataController.h"
#import "ASCollectionViewFlowLayoutInspector.h"

@interface ASTextCellNodeWithSetSelectedCounter : ASTextCellNode

@property (nonatomic, assign) NSUInteger setSelectedCounter;

@end

@implementation ASTextCellNodeWithSetSelectedCounter

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  _setSelectedCounter++;
}

@end

@interface ASCollectionViewTestDelegate : NSObject <ASCollectionViewDataSource, ASCollectionViewDelegate>

@property (nonatomic, assign) NSInteger numberOfSections;
@property (nonatomic, assign) NSInteger numberOfItemsInSection;

@end

@implementation ASCollectionViewTestDelegate

- (id)initWithNumberOfSections:(NSInteger)numberOfSections numberOfItemsInSection:(NSInteger)numberOfItemsInSection {
  if (self = [super init]) {
    _numberOfSections = numberOfSections;
    _numberOfItemsInSection = numberOfItemsInSection;
  }

  return self;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath {
  ASTextCellNodeWithSetSelectedCounter *textCellNode = [ASTextCellNodeWithSetSelectedCounter new];
  textCellNode.text = indexPath.description;

  return textCellNode;
}


- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath {
  return ^{
    ASTextCellNodeWithSetSelectedCounter *textCellNode = [ASTextCellNodeWithSetSelectedCounter new];
    textCellNode.text = indexPath.description;
    return textCellNode;
  };
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
  return self.numberOfSections;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return self.numberOfItemsInSection;
}

@end

@interface ASCollectionViewTestController: UIViewController

@property (nonatomic, strong) ASCollectionViewTestDelegate *asyncDelegate;
@property (nonatomic, strong) ASCollectionView *collectionView;

@end

@implementation ASCollectionViewTestController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.asyncDelegate = [[ASCollectionViewTestDelegate alloc] initWithNumberOfSections:10 numberOfItemsInSection:10];

  self.collectionView = [[ASCollectionView alloc] initWithFrame:self.view.bounds
                                           collectionViewLayout:[UICollectionViewFlowLayout new]];
  self.collectionView.asyncDataSource = self.asyncDelegate;
  self.collectionView.asyncDelegate = self.asyncDelegate;

  [self.view addSubview:self.collectionView];
}

- (void)viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];

  self.collectionView.frame = self.view.bounds;
}

@end

@interface ASCollectionView (InternalTesting)

- (NSArray *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController;

@end

@interface ASCollectionViewTests : XCTestCase

@end

@implementation ASCollectionViewTests

- (void)testThatItSetsALayoutInspectorForFlowLayouts
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  XCTAssert(collectionView.layoutInspector != nil, @"should automatically set a layout delegate for flow layouts");
  XCTAssert([collectionView.layoutInspector isKindOfClass:[ASCollectionViewFlowLayoutInspector class]], @"should have a flow layout inspector by default");
}

- (void)testThatItDoesNotSetALayoutInspectorForCustomLayouts
{
  UICollectionViewLayout *layout = [[UICollectionViewLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  XCTAssert(collectionView.layoutInspector == nil, @"should not set a layout delegate for custom layouts");
}

- (void)testThatRegisteringASupplementaryNodeStoresItForIntrospection
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionView *collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  [collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  XCTAssertEqualObjects([collectionView supplementaryNodeKindsInDataController:nil], @[UICollectionElementKindSectionHeader]);
}

- (void)testCollectionViewController
{
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];

  UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
  [containerView addSubview:testController.view];

  [testController.collectionView reloadData];

  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
}

- (void)testSelection
{
  ASCollectionViewTestController *testController = [[ASCollectionViewTestController alloc] initWithNibName:nil bundle:nil];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [window setRootViewController:testController];
  [window makeKeyAndVisible];
  
  [testController.collectionView reloadDataImmediately];
  [testController.collectionView layoutIfNeeded];
  
  NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  ASCellNode *node = [testController.collectionView nodeForItemAtIndexPath:indexPath];
  
  // selecting node should select cell
  node.selected = YES;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] containsObject:indexPath], @"Selecting node should update cell selection.");
  
  // deselecting node should deselect cell
  node.selected = NO;
  XCTAssertTrue([[testController.collectionView indexPathsForSelectedItems] isEqualToArray:@[]], @"Deselecting node should update cell selection.");

  // selecting cell via collectionView should select node
  [testController.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");
  
  // deselecting cell via collectionView should deselect node
  [testController.collectionView deselectItemAtIndexPath:indexPath animated:NO];
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // selecting cell should select node
  UICollectionViewCell *cell = [testController.collectionView cellForItemAtIndexPath:indexPath];
  cell.selected = YES;
  XCTAssertTrue(node.isSelected == YES, @"Selecting cell should update node selection.");
  
  // reload cell (-prepareForReuse is called) & check that selected state is preserved
  [testController.collectionView setContentOffset:CGPointMake(0,testController.collectionView.bounds.size.height)];
  [testController.collectionView layoutIfNeeded];
  [testController.collectionView setContentOffset:CGPointMake(0,0)];
  [testController.collectionView layoutIfNeeded];
  XCTAssertTrue(node.isSelected == YES, @"Reloaded cell should preserve state.");
  
  // deselecting cell should deselect node
  cell = [testController.collectionView cellForItemAtIndexPath:indexPath];
  cell.selected = NO;
  XCTAssertTrue(node.isSelected == NO, @"Deselecting cell should update node selection.");
  
  // check setSelected not called extra times
  XCTAssertTrue([(ASTextCellNodeWithSetSelectedCounter *)node setSelectedCounter] == 6, @"setSelected: should not be called on node multiple times.");
}

@end

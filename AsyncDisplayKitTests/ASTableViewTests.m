//
//  ASTableViewTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>

#import "ASTableView.h"
#import "ASTableViewInternal.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASChangeSetDataController.h"
#import "ASCellNode.h"
#import "ASTableNode.h"
#import "ASTableView+Undeprecated.h"

#define NumberOfSections 10
#define NumberOfRowsPerSection 20
#define NumberOfReloadIterations 50

@interface ASTestDataController : ASChangeSetDataController
@property (nonatomic) int numberOfAllNodesRelayouts;
@end

@implementation ASTestDataController

- (void)relayoutAllNodes
{
  _numberOfAllNodesRelayouts++;
  [super relayoutAllNodes];
}

@end

@interface ASTestTableView : ASTableView
@property (nonatomic, copy) void (^willDeallocBlock)(ASTableView *tableView);
@end

@implementation ASTestTableView

- (instancetype)__initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  return [super _initWithFrame:frame style:style dataControllerClass:[ASTestDataController class] ownedByNode:NO];
}

- (ASTestDataController *)testDataController
{
  return (ASTestDataController *)self.dataController;
}

- (void)dealloc
{
  if (_willDeallocBlock) {
    _willDeallocBlock(self);
  }
}

@end

@interface ASTableViewTestDelegate : NSObject <ASTableDataSource, ASTableDelegate>
@property (nonatomic, copy) void (^willDeallocBlock)(ASTableViewTestDelegate *delegate);
@end

@implementation ASTableViewTestDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 0;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return nil;
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return nil;
}

- (void)dealloc
{
  if (_willDeallocBlock) {
    _willDeallocBlock(self);
  }
}

@end

@interface ASTestTextCellNode : ASTextCellNode
/** Calculated by counting how many times -layoutSpecThatFits: is called on the main thread. */
@property (nonatomic) int numberOfLayoutsOnMainThread;
@end

@implementation ASTestTextCellNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  if ([NSThread isMainThread]) {
    _numberOfLayoutsOnMainThread++;
  }
  return [super layoutSpecThatFits:constrainedSize];
}

@end

@interface ASTableViewFilledDataSource : NSObject <ASTableDataSource, ASTableDelegate>
@end

@implementation ASTableViewFilledDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return NumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return NumberOfRowsPerSection;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASTestTextCellNode *textCellNode = [ASTestTextCellNode new];
  textCellNode.text = indexPath.description;
  
  return textCellNode;
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    ASTestTextCellNode *textCellNode = [ASTestTextCellNode new];
    textCellNode.text = indexPath.description;
    return textCellNode;
  };
}

@end

@interface ASTableViewFilledDelegate : NSObject <ASTableDelegate>
@end

@implementation ASTableViewFilledDelegate

- (ASSizeRange)tableView:(ASTableView *)tableView constrainedSizeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ASSizeRangeMake(CGSizeMake(10, 42));
}

@end

@interface ASTableViewTests : XCTestCase
@property (nonatomic, retain) ASTableView *testTableView;
@end

@implementation ASTableViewTests

- (void)testDataSourceImplementsNecessaryMethods
{
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, 100, 400)
                                                                  style:UITableViewStylePlain];
  
  
  
  ASTableViewFilledDataSource *dataSource = (ASTableViewFilledDataSource *)[NSObject new];
  XCTAssertThrows((tableView.asyncDataSource = dataSource));
  
  dataSource = [ASTableViewFilledDataSource new];
  XCTAssertNoThrow((tableView.asyncDataSource = dataSource));
}

- (void)testConstrainedSizeForRowAtIndexPath
{
  // Initial width of the table view is non-zero and all nodes are measured with this size.
  // Any subsequence size change must trigger a relayout.
  // Width and height are swapped so that a later size change will simulate a rotation
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, 100, 400)
                                                                  style:UITableViewStylePlain];
  
  ASTableViewFilledDelegate *delegate = [ASTableViewFilledDelegate new];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];

  tableView.asyncDelegate = delegate;
  tableView.asyncDataSource = dataSource;
  
  [tableView reloadDataImmediately];
  [tableView setNeedsLayout];
  [tableView layoutIfNeeded];
  
  for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < NumberOfRowsPerSection; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
        XCTAssertEqual(rect.size.width, 100);  // specified width should be ignored for table
        XCTAssertEqual(rect.size.height, 42);
      }
  }
}

// TODO: Convert this to ARC.
- (void)DISABLED_testTableViewDoesNotRetainItselfAndDelegate
{
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectZero style:UITableViewStylePlain];
  
  __block BOOL tableViewDidDealloc = NO;
  tableView.willDeallocBlock = ^(ASTableView *v){
    tableViewDidDealloc = YES;
  };
  
  ASTableViewTestDelegate *delegate = [[ASTableViewTestDelegate alloc] init];
  
  __block BOOL delegateDidDealloc = NO;
  delegate.willDeallocBlock = ^(ASTableViewTestDelegate *d){
    delegateDidDealloc = YES;
  };
  
  tableView.asyncDataSource = delegate;
  tableView.asyncDelegate = delegate;

//  [delegate release];
  XCTAssertTrue(delegateDidDealloc, @"unexpected delegate lifetime:%@", delegate);
  
//  XCTAssertNoThrow([tableView release], @"unexpected exception when deallocating table view:%@", tableView);
  XCTAssertTrue(tableViewDidDealloc, @"unexpected table view lifetime:%@", tableView);
}

- (NSIndexSet *)randomIndexSet
{
  NSInteger randA = arc4random_uniform(NumberOfSections - 1);
  NSInteger randB = arc4random_uniform(NumberOfSections - 1);
  
  return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(MIN(randA, randB), MAX(randA, randB) - MIN(randA, randB))];
}

- (NSArray *)randomIndexPathsExisting:(BOOL)existing
{
  NSMutableArray *indexPaths = [NSMutableArray array];
  [[self randomIndexSet] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = NumberOfRowsPerSection;
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = (existing ? 0 : rowNum); i < (existing ? rowNum : rowNum * 2); i++) {
      // Maximize evility by sporadically skipping indicies 1/3rd of the time, but only if reloading existing rows
      if (existing && arc4random_uniform(2) == 0) {
        continue;
      }
      
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
      [indexPaths addObject:indexPath];
    }
  }];
  return indexPaths;
}

- (void)testReloadData
{
  // Keep the viewport moderately sized so that new cells are loaded on scrolling
  ASTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, 100, 500)
                                                              style:UITableViewStylePlain];
  
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  
  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;

  XCTestExpectation *reloadDataExpectation = [self expectationWithDescription:@"reloadData"];
  
  [tableView reloadDataWithCompletion:^{
    NSLog(@"*** Reload Complete ***");
    [reloadDataExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
  
  for (int i = 0; i < NumberOfReloadIterations; ++i) {
    UITableViewRowAnimation rowAnimation = (arc4random_uniform(2) == 0 ? UITableViewRowAnimationMiddle : UITableViewRowAnimationNone);
    BOOL animatedScroll               = (arc4random_uniform(2) == 0 ? YES : NO);
    BOOL reloadRowsInsteadOfSections  = (arc4random_uniform(2) == 0 ? YES : NO);
    NSTimeInterval runLoopDelay       = ((arc4random_uniform(2) == 0) ? (1.0 / (1 + arc4random_uniform(500))) : 0);
    BOOL useBeginEndUpdates           = (arc4random_uniform(3) == 0 ? YES : NO);

    // instrument our instrumentation ;)
    //NSLog(@"Iteration %03d: %@|%@|%@|%@|%g", i, (rowAnimation == UITableViewRowAnimationNone) ? @"NONE  " : @"MIDDLE", animatedScroll ? @"ASCR" : @"    ", reloadRowsInsteadOfSections ? @"ROWS" : @"SECS", useBeginEndUpdates ? @"BEGEND" : @"      ", runLoopDelay);

    if (useBeginEndUpdates) {
      [tableView beginUpdates];
    }
    
    if (reloadRowsInsteadOfSections) {
      NSArray *indexPaths = [self randomIndexPathsExisting:YES];
      //NSLog(@"reloading rows: %@", indexPaths);
      [tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:rowAnimation];
    } else {
      NSIndexSet *sections = [self randomIndexSet];
      //NSLog(@"reloading sections: %@", sections);
      [tableView reloadSections:sections withRowAnimation:rowAnimation];
    }
    
    [tableView setContentOffset:CGPointMake(0, arc4random_uniform(tableView.contentSize.height - tableView.bounds.size.height)) animated:animatedScroll];
    
    if (runLoopDelay > 0) {
      // Run other stuff on the main queue for between 2ms and 1000ms.
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:runLoopDelay]];
    }
    
    if (useBeginEndUpdates) {
      [tableView endUpdates];
    }
  }
}

- (void)testRelayoutAllNodesWithNonZeroSizeInitially
{
  // Initial width of the table view is non-zero and all nodes are measured with this size.
  // Any subsequence size change must trigger a relayout.
  CGSize tableViewFinalSize = CGSizeMake(100, 500);
  // Width and height are swapped so that a later size change will simulate a rotation
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, tableViewFinalSize.height, tableViewFinalSize.width)
                                                                style:UITableViewStylePlain];
  
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];

  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;

  [tableView layoutIfNeeded];
  
  XCTAssertEqual(tableView.testDataController.numberOfAllNodesRelayouts, 0);
  [self triggerSizeChangeAndAssertRelayoutAllNodesForTableView:tableView newSize:tableViewFinalSize];
}

- (void)testRelayoutAllNodesWithZeroSizeInitially
{
  // Initial width of the table view is 0. The first size change is part of the initial config.
  // Any subsequence size change after that must trigger a relayout.
  CGSize tableViewFinalSize = CGSizeMake(100, 500);
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectZero
                                                                style:UITableViewStylePlain];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];

  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;
  
  // Initial configuration
  UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)];
  [superview addSubview:tableView];
  // Width and height are swapped so that a later size change will simulate a rotation
  tableView.frame = CGRectMake(0, 0, tableViewFinalSize.height, tableViewFinalSize.width);
  [tableView layoutIfNeeded];
  
  XCTAssertEqual(tableView.testDataController.numberOfAllNodesRelayouts, 0);
  [self triggerSizeChangeAndAssertRelayoutAllNodesForTableView:tableView newSize:tableViewFinalSize];
}

- (void)testRelayoutVisibleRowsWhenEditingModeIsChanged
{
  CGSize tableViewSize = CGSizeMake(100, 500);
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, tableViewSize.width, tableViewSize.height)
                                                                style:UITableViewStylePlain];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  
  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;

  [self triggerFirstLayoutMeasurementForTableView:tableView];
  
  NSArray *visibleNodes = [tableView visibleNodes];
  XCTAssertGreaterThan(visibleNodes.count, 0);
  
  // Cause table view to enter editing mode.
  // Visibile nodes should be re-measured on main thread with the new (smaller) content view width.
  // Other nodes are untouched.
  XCTestExpectation *relayoutAfterEnablingEditingExpectation = [self expectationWithDescription:@"relayoutAfterEnablingEditing"];
  [tableView beginUpdates];
  [tableView setEditing:YES];
  [tableView endUpdatesAnimated:YES completion:^(BOOL completed) {
    for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < NumberOfRowsPerSection; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        ASTestTextCellNode *node = (ASTestTextCellNode *)[tableView nodeForRowAtIndexPath:indexPath];
        if ([visibleNodes containsObject:node]) {
          XCTAssertEqual(node.numberOfLayoutsOnMainThread, 1);
          XCTAssertLessThan(node.constrainedSizeForCalculatedLayout.max.width, tableViewSize.width);
        } else {
          XCTAssertEqual(node.numberOfLayoutsOnMainThread, 0);
          XCTAssertEqual(node.constrainedSizeForCalculatedLayout.max.width, tableViewSize.width);
        }
      }
    }
    [relayoutAfterEnablingEditingExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];

  // Cause table view to leave editing mode.
  // Visibile nodes should be re-measured again.
  // All nodes should have max constrained width equals to the table view width.
  XCTestExpectation *relayoutAfterDisablingEditingExpectation = [self expectationWithDescription:@"relayoutAfterDisablingEditing"];
  [tableView beginUpdates];
  [tableView setEditing:NO];
  [tableView endUpdatesAnimated:YES completion:^(BOOL completed) {
    for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < NumberOfRowsPerSection; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        ASTestTextCellNode *node = (ASTestTextCellNode *)[tableView nodeForRowAtIndexPath:indexPath];
        BOOL visible = [visibleNodes containsObject:node];
        XCTAssertEqual(node.numberOfLayoutsOnMainThread, visible ? 2: 0);
        XCTAssertEqual(node.constrainedSizeForCalculatedLayout.max.width, tableViewSize.width);
      }
    }
    [relayoutAfterDisablingEditingExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

- (void)DISABLED_testRelayoutRowsAfterEditingModeIsChangedAndTheyBecomeVisible
{
  CGSize tableViewSize = CGSizeMake(100, 500);
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, tableViewSize.width, tableViewSize.height)
                                                                style:UITableViewStylePlain];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  
  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;
  
  [self triggerFirstLayoutMeasurementForTableView:tableView];
  
  // Cause table view to enter editing mode and then scroll to the bottom.
  // The last node should be re-measured on main thread with the new (smaller) content view width.
  NSIndexPath *lastRowIndexPath = [NSIndexPath indexPathForRow:(NumberOfRowsPerSection - 1) inSection:(NumberOfSections - 1)];
  XCTestExpectation *relayoutExpectation = [self expectationWithDescription:@"relayout"];
  [tableView beginUpdates];
  [tableView setEditing:YES];
  [tableView setContentOffset:CGPointMake(0, CGFLOAT_MAX) animated:YES];
  [tableView endUpdatesAnimated:YES completion:^(BOOL completed) {
    ASTestTextCellNode *node = (ASTestTextCellNode *)[tableView nodeForRowAtIndexPath:lastRowIndexPath];
    XCTAssertEqual(node.numberOfLayoutsOnMainThread, 1);
    XCTAssertLessThan(node.constrainedSizeForCalculatedLayout.max.width, tableViewSize.width);
    [relayoutExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

- (void)testIndexPathForNode
{
  CGSize tableViewSize = CGSizeMake(100, 500);
  ASTestTableView *tableView = [[ASTestTableView alloc] initWithFrame:CGRectMake(0, 0, tableViewSize.width, tableViewSize.height)
                                                                style:UITableViewStylePlain];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];

  tableView.asyncDelegate = dataSource;
  tableView.asyncDataSource = dataSource;
  
  [tableView reloadDataWithCompletion:^{
    for (NSUInteger i = 0; i < NumberOfSections; i++) {
      for (NSUInteger j = 0; j < NumberOfRowsPerSection; j++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j inSection:i];
        ASCellNode *cellNode = [tableView nodeForRowAtIndexPath:indexPath];
        NSIndexPath *reportedIndexPath = [tableView indexPathForNode:cellNode];
        XCTAssertEqual(indexPath.row, reportedIndexPath.row);
      }
    }
    self.testTableView = nil;
  }];
}

- (void)triggerFirstLayoutMeasurementForTableView:(ASTableView *)tableView{
  XCTestExpectation *reloadDataExpectation = [self expectationWithDescription:@"reloadData"];
  [tableView reloadDataWithCompletion:^{
    for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < NumberOfRowsPerSection; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        ASTestTextCellNode *node = (ASTestTextCellNode *)[tableView nodeForRowAtIndexPath:indexPath];
        XCTAssertEqual(node.numberOfLayoutsOnMainThread, 0);
        XCTAssertEqual(node.constrainedSizeForCalculatedLayout.max.width, tableView.frame.size.width);
      }
    }
    [reloadDataExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

- (void)triggerSizeChangeAndAssertRelayoutAllNodesForTableView:(ASTestTableView *)tableView newSize:(CGSize)newSize
{
  XCTestExpectation *nodesMeasuredUsingNewConstrainedSizeExpectation = [self expectationWithDescription:@"nodesMeasuredUsingNewConstrainedSize"];
  
  [tableView beginUpdates];
  
  CGRect frame = tableView.frame;
  frame.size = newSize;
  tableView.frame = frame;
  [tableView layoutIfNeeded];
  
  [tableView endUpdatesAnimated:NO completion:^(BOOL completed) {
    XCTAssertEqual(tableView.testDataController.numberOfAllNodesRelayouts, 1);

    for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < NumberOfRowsPerSection; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        ASTestTextCellNode *node = (ASTestTextCellNode *)[tableView nodeForRowAtIndexPath:indexPath];
        XCTAssertLessThanOrEqual(node.numberOfLayoutsOnMainThread, 1);
        XCTAssertEqual(node.constrainedSizeForCalculatedLayout.max.width, newSize.width);
      }
    }
    [nodesMeasuredUsingNewConstrainedSizeExpectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:5 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

/**
 * This may seem silly, but we had issues where the runtime sometimes wouldn't correctly report
 * conformances declared on categories.
 */
- (void)testThatTableNodeConformsToExpectedProtocols
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  XCTAssert([node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)]);
}

@end

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

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASTableView.h>
#import <AsyncDisplayKit/ASTableViewInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASTableNode.h>
#import <AsyncDisplayKit/ASTableView+Undeprecated.h>
#import <JGMethodSwizzler/JGMethodSwizzler.h>
#import "ASXCTExtensions.h"
#import <AsyncDisplayKit/ASInternalHelpers.h>

#define NumberOfSections 10
#define NumberOfReloadIterations 50

@interface ASTestDataController : ASDataController
@property (nonatomic) int numberOfAllNodesRelayouts;
@end

@implementation ASTestDataController

- (void)relayoutAllNodes
{
  _numberOfAllNodesRelayouts++;
  [super relayoutAllNodes];
}

@end

@interface UITableView (Testing)
// This will start recording all editing calls to UITableView
// into the provided array.
// Make sure to call [UITableView deswizzleInstanceMethods] to reset this.
+ (void)as_recordEditingCallsIntoArray:(NSMutableArray<NSString *> *)selectors;
@end

@interface ASTestTableView : ASTableView
@property (nonatomic, copy) void (^willDeallocBlock)(ASTableView *tableView);
@end

@implementation ASTestTableView

- (instancetype)__initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
  
  return [super _initWithFrame:frame style:style dataControllerClass:[ASTestDataController class] eventLog:nil];
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
@property (nonatomic) CGFloat headerHeight;
@property (nonatomic) CGFloat footerHeight;
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

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
  return _footerHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
  return _headerHeight;
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
@property (nonatomic) BOOL usesSectionIndex;
@property (nonatomic) NSInteger rowsPerSection;
@property (nonatomic, nullable, copy) ASCellNodeBlock(^nodeBlockForItem)(NSIndexPath *);
@end

@implementation ASTableViewFilledDataSource

- (instancetype)init
{
  self = [super init];
  if (self != nil) {
    _rowsPerSection = 20;
  }
  return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
  if (aSelector == @selector(sectionIndexTitlesForTableView:) || aSelector == @selector(tableView:sectionForSectionIndexTitle:atIndex:)) {
    return _usesSectionIndex;
  } else {
    return [super respondsToSelector:aSelector];
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return NumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return _rowsPerSection;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASTestTextCellNode *textCellNode = [ASTestTextCellNode new];
  textCellNode.text = indexPath.description;
  
  return textCellNode;
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (_nodeBlockForItem) {
    return _nodeBlockForItem(indexPath);
  }

  return ^{
    ASTestTextCellNode *textCellNode = [ASTestTextCellNode new];
    textCellNode.text = [NSString stringWithFormat:@"{%d, %d}", (int)indexPath.section, (int)indexPath.row];
    textCellNode.backgroundColor = [UIColor whiteColor];
    return textCellNode;
  };
}

- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
  return @[ @"A", @"B", @"C" ];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
  return 0;
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
  // Any subsequent size change must trigger a relayout.
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
  
  CGFloat separatorHeight = 1.0 / ASScreenScale();
  for (int section = 0; section < NumberOfSections; section++) {
      for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        CGRect rect = [tableView rectForRowAtIndexPath:indexPath];
        XCTAssertEqual(rect.size.width, 100);  // specified width should be ignored for table
        XCTAssertEqual(rect.size.height, 42 + separatorHeight);
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

- (NSArray *)randomIndexPathsExisting:(BOOL)existing rowCount:(NSInteger)rowCount
{
  NSMutableArray *indexPaths = [NSMutableArray array];
  [[self randomIndexSet] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = (existing ? 0 : rowCount); i < (existing ? rowCount : rowCount * 2); i++) {
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

- (void)DISABLED_testReloadData
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
      NSArray *indexPaths = [self randomIndexPathsExisting:YES rowCount:dataSource.rowsPerSection];
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

- (void)testRelayoutVisibleRowsWhenEditingModeIsChanged
{
  CGSize tableViewSize = CGSizeMake(100, 500);
  ASTestTableView *tableView = [[ASTestTableView alloc] __initWithFrame:CGRectMake(0, 0, tableViewSize.width, tableViewSize.height)
                                                                style:UITableViewStylePlain];
  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  // Currently this test requires that the text in the cell node fills the
  // visible width, so we use the long description for the index path.
  dataSource.nodeBlockForItem = ^(NSIndexPath *indexPath) {
    return (ASCellNodeBlock)^{
      ASTestTextCellNode *textCellNode = [[ASTestTextCellNode alloc] init];
      textCellNode.text = indexPath.description;
      return textCellNode;
    };
  };
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
      for (int row = 0; row < dataSource.rowsPerSection; row++) {
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
      for (int row = 0; row < dataSource.rowsPerSection; row++) {
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
  NSIndexPath *lastRowIndexPath = [NSIndexPath indexPathForRow:(dataSource.rowsPerSection - 1) inSection:(NumberOfSections - 1)];
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
      for (NSUInteger j = 0; j < dataSource.rowsPerSection; j++) {
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
      for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
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
  [tableView setNeedsLayout];
  [tableView layoutIfNeeded];
  [tableView waitUntilAllUpdatesAreCommitted];
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
      for (int row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
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

- (void)testThatInitialDataLoadHappensInOneShot
{
  NSMutableArray *selectors = [NSMutableArray array];
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  node.frame = CGRectMake(0, 0, 100, 100);

  node.dataSource = dataSource;
  node.delegate = dataSource;

  [UITableView as_recordEditingCallsIntoArray:selectors];
  XCTAssertGreaterThan(node.numberOfSections, 0);
  [node waitUntilAllUpdatesAreCommitted];
  XCTAssertGreaterThan(node.view.numberOfSections, 0);

  // The first reloadData call helps prevent UITableView from calling it multiple times while ASDataController is working.
  // The second reloadData call is the real one.
  NSArray *expectedSelectors = @[ NSStringFromSelector(@selector(reloadData)),
                                  NSStringFromSelector(@selector(reloadData)) ];
  XCTAssertEqualObjects(selectors, expectedSelectors);

  [UITableView deswizzleAllInstanceMethods];
}

- (void)testThatReloadDataHappensInOneShot
{
  NSMutableArray *selectors = [NSMutableArray array];
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  node.frame = CGRectMake(0, 0, 100, 100);

  node.dataSource = dataSource;
  node.delegate = dataSource;

  // Load initial data.
  XCTAssertGreaterThan(node.numberOfSections, 0);
  [node waitUntilAllUpdatesAreCommitted];
  XCTAssertGreaterThan(node.view.numberOfSections, 0);

  // Reload data.
  [UITableView as_recordEditingCallsIntoArray:selectors];
  [node reloadData];
  [node waitUntilAllUpdatesAreCommitted];

  // Assert that the beginning of the call pattern is correct.
  // There is currently noise that comes after that we will allow for this test.
  NSArray *expectedSelectors = @[ NSStringFromSelector(@selector(reloadData)) ];
  XCTAssertEqualObjects(selectors, expectedSelectors);

  [UITableView deswizzleAllInstanceMethods];
}

/**
 * This tests an issue where, if the table is loaded before the first layout pass,
 * the nodes are first measured with a constrained width of 0 which isn't ideal.
 */
- (void)testThatNodeConstrainedSizesAreCorrectIfReloadIsPreempted
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  CGFloat cellWidth = 320;
  node.frame = CGRectMake(0, 0, cellWidth, 480);

  node.dataSource = dataSource;
  node.delegate = dataSource;

  // Trigger data load BEFORE first layout pass, to ensure constrained size is correct.
  XCTAssertGreaterThan(node.numberOfSections, 0);
  [node waitUntilAllUpdatesAreCommitted];

  ASSizeRange expectedSizeRange = ASSizeRangeMake(CGSizeMake(cellWidth, 0));
  expectedSizeRange.max.height = CGFLOAT_MAX;

  for (NSInteger i = 0; i < node.numberOfSections; i++) {
    for (NSInteger j = 0; j < [node numberOfRowsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASTestTextCellNode *cellNode = (id)[node nodeForRowAtIndexPath:indexPath];
      ASXCTAssertEqualSizeRanges(cellNode.constrainedSizeForCalculatedLayout, expectedSizeRange);
      XCTAssertEqual(cellNode.numberOfLayoutsOnMainThread, 0);
    }
  }
}

- (void)testSectionIndexHandling
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];

  ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
  dataSource.usesSectionIndex = YES;
  node.frame = CGRectMake(0, 0, 320, 480);

  node.dataSource = dataSource;
  node.delegate = dataSource;

  // Trigger data load
  XCTAssertGreaterThan(node.numberOfSections, 0);
  XCTAssertGreaterThan([node numberOfRowsInSection:0], 0);
  
  // UITableView's section index view is added only after some rows were inserted to the table.
  // All nodes loaded and measured during the initial reloadData used an outdated constrained width (i.e full width: 320).
  // So we need to force a new layout pass so that the table will pick up a new constrained size and apply to its node.
  [node setNeedsLayout];
  [node.view layoutIfNeeded];
  [node waitUntilAllUpdatesAreCommitted];

  UITableViewCell *cell = [node.view cellForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
  XCTAssertNotNil(cell);

  CGFloat cellWidth = cell.contentView.frame.size.width;
  XCTAssert(cellWidth > 0 && cellWidth < 320, @"Expected cell width to be about 305. Width: %@", @(cellWidth));

  ASSizeRange expectedSizeRange = ASSizeRangeMake(CGSizeMake(cellWidth, 0));
  expectedSizeRange.max.height = CGFLOAT_MAX;
  
  for (NSInteger i = 0; i < node.numberOfSections; i++) {
    for (NSInteger j = 0; j < [node numberOfRowsInSection:i]; j++) {
      NSIndexPath *indexPath = [NSIndexPath indexPathForItem:j inSection:i];
      ASTestTextCellNode *cellNode = (id)[node nodeForRowAtIndexPath:indexPath];
      ASXCTAssertEqualSizeRanges(cellNode.constrainedSizeForCalculatedLayout, expectedSizeRange);
      // We will have to accept a relayout on main thread, since the index bar won't show
      // up until some of the cells are inserted.
      XCTAssertLessThanOrEqual(cellNode.numberOfLayoutsOnMainThread, 1);
    }
  }
}

- (void)testThatNilBatchUpdatesCanBeSubmitted
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  
  // Passing nil blocks should not crash
  [node performBatchUpdates:nil completion:nil];
  [node performBatchAnimated:NO updates:nil completion:nil];
}

// https://github.com/facebook/AsyncDisplayKit/issues/2252#issuecomment-263689979
- (void)testIssue2252
{
  // Hard-code an iPhone 7 screen. There's something particular about this geometry that causes the issue to repro.
  UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];

  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
  node.frame = window.bounds;
  ASTableViewTestDelegate *del = [[ASTableViewTestDelegate alloc] init];
  del.headerHeight = 32;
  del.footerHeight = 0.01;
  node.delegate = del;
  ASTableViewFilledDataSource *ds = [[ASTableViewFilledDataSource alloc] init];
  ds.rowsPerSection = 1;
  node.dataSource = ds;
  ASViewController *vc = [[ASViewController alloc] initWithNode:node];
  UITabBarController *tabCtrl = [[UITabBarController alloc] init];
  tabCtrl.viewControllers = @[ vc ];
  tabCtrl.tabBar.translucent = NO;
  window.rootViewController = tabCtrl;
  [window makeKeyAndVisible];

  [window layoutIfNeeded];
  [node waitUntilAllUpdatesAreCommitted];
  XCTAssertEqual(node.view.numberOfSections, NumberOfSections);
  ASXCTAssertEqualRects(CGRectMake(0, 32, 375, 44), [node rectForRowAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]], @"This text requires very specific geometry. The rect for the first row should match up.");

  __unused XCTestExpectation *e = [self expectationWithDescription:@"Did a bunch of rounds of updates."];
  NSInteger totalCount = 20;
  __block NSInteger count = 0;
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
  dispatch_source_set_event_handler(timer, ^{
    [node performBatchUpdates:^{
      [node reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, NumberOfSections)] withRowAnimation:UITableViewRowAnimationNone];
    } completion:^(BOOL finished) {
      if (++count == totalCount) {
        dispatch_cancel(timer);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          [e fulfill];
        });
      }
    }];
  });
  dispatch_resume(timer);
  [self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testThatInvalidUpdateExceptionReasonContainsDataSourceClassName
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
  node.bounds = CGRectMake(0, 0, 100, 100);
  ASTableViewFilledDataSource *ds = [[ASTableViewFilledDataSource alloc] init];
  node.dataSource = ds;

  // Force node to load initial data.
  [node.view layoutIfNeeded];

  // Submit an invalid update, ensure exception name matches and that data source is included in the reason.
  @try {
    [node deleteSections:[NSIndexSet indexSetWithIndex:1000] withRowAnimation:UITableViewRowAnimationNone];
    XCTFail(@"Expected validation to fail.");
  } @catch (NSException *e) {
    XCTAssertEqual(e.name, ASCollectionInvalidUpdateException);
    XCTAssert([e.reason containsString:NSStringFromClass([ds class])], @"Expected validation reason to contain the data source class name. Got:\n%@", e.reason);
  }
}

- (void)testAutomaticallyAdjustingContentOffset
{
  ASTableNode *node = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  node.view.automaticallyAdjustsContentOffset = YES;
  node.bounds = CGRectMake(0, 0, 100, 100);
  ASTableViewFilledDataSource *ds = [[ASTableViewFilledDataSource alloc] init];
  node.dataSource = ds;
  
  [node.view layoutIfNeeded];
  [node waitUntilAllUpdatesAreCommitted];
  CGFloat rowHeight = [node.view rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].size.height;
  // Scroll to row (0,1) + 10pt
  node.view.contentOffset = CGPointMake(0, rowHeight + 10);
  
  [node performBatchAnimated:NO updates:^{
    // Delete row 0 from all sections.
    // This is silly but it's a consequence of how ASTableViewFilledDataSource is built.
    ds.rowsPerSection -= 1;
    for (NSInteger i = 0; i < NumberOfSections; i++) {
      [node deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForItem:0 inSection:i]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
  } completion:nil];
  [node waitUntilAllUpdatesAreCommitted];
  
  // Now that row (0,0) is deleted, we should have slid up to be at just 10
  // i.e. we should have subtracted the deleted row height from our content offset.
  XCTAssertEqual(node.view.contentOffset.y, 10);
}

@end

@implementation UITableView (Testing)

+ (void)as_recordEditingCallsIntoArray:(NSMutableArray<NSString *> *)selectors
{
  [UITableView swizzleInstanceMethod:@selector(reloadData) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *) {
      JGOriginalImplementation(void);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(beginUpdates) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *) {
      JGOriginalImplementation(void);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(endUpdates) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *) {
      JGOriginalImplementation(void);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(insertRowsAtIndexPaths:withRowAnimation:) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *, NSArray *indexPaths, UITableViewRowAnimation anim) {
      JGOriginalImplementation(void, indexPaths, anim);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(deleteRowsAtIndexPaths:withRowAnimation:) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *, NSArray *indexPaths, UITableViewRowAnimation anim) {
      JGOriginalImplementation(void, indexPaths, anim);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(insertSections:withRowAnimation:) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *, NSIndexSet *indexes, UITableViewRowAnimation anim) {
      JGOriginalImplementation(void, indexes, anim);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
  [UITableView swizzleInstanceMethod:@selector(deleteSections:withRowAnimation:) withReplacement:JGMethodReplacementProviderBlock {
    return JGMethodReplacement(void, UITableView *, NSIndexSet *indexes, UITableViewRowAnimation anim) {
      JGOriginalImplementation(void, indexes, anim);
      [selectors addObject:NSStringFromSelector(_cmd)];
    };
  }];
}

@end

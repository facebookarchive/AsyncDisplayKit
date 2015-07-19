/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASTableView.h"

#define NumberOfSections 10
#define NumberOfRowsPerSection 20
#define NumberOfReloadIterations 50

@interface ASTestTableView : ASTableView
@property (atomic, copy) void (^willDeallocBlock)(ASTableView *tableView);
@end

@implementation ASTestTableView

- (void)dealloc
{
  if (_willDeallocBlock) {
    _willDeallocBlock(self);
  }
  [super dealloc];
}

@end

@interface ASTableViewTestDelegate : NSObject <ASTableViewDataSource, ASTableViewDelegate>
@property (atomic, copy) void (^willDeallocBlock)(ASTableViewTestDelegate *delegate);
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

- (void)dealloc
{
  if (_willDeallocBlock) {
    _willDeallocBlock(self);
  }
  [super dealloc];
}

@end

@interface ASTableViewFilledDataSource : NSObject <ASTableViewDataSource, ASTableViewDelegate>

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
  ASTextCellNode *textCellNode = [ASTextCellNode new];
  textCellNode.text = indexPath.description;
  
  return textCellNode;
}

@end

@interface ASTableViewTests : XCTestCase
@end

@implementation ASTableViewTests

- (void)DISABLED_testTableViewDoesNotRetainItselfAndDelegate
{
  ASTestTableView *tableView = [[ASTestTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  
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
  
  [delegate release];
  XCTAssertTrue(delegateDidDealloc, @"unexpected delegate lifetime:%@", delegate);
  
  XCTAssertNoThrow([tableView release], @"unexpected exception when deallocating table view:%@", tableView);
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
  ASTableView *tableView = [[ASTableView alloc] initWithFrame:CGRectMake(0, 0, 100, 500)
                                                        style:UITableViewStylePlain
                                            asyncDataFetching:YES];
  
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

@end

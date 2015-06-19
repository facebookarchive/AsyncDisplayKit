/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASTableView.h"

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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 100;
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

- (void)testReloadData
{
    ASTableView *tableView = [[ASTableView alloc] initWithFrame:CGRectMake(0, 0, 1000, 1000)
                                                          style:UITableViewStylePlain
                                              asyncDataFetching:YES];
    
    ASTableViewFilledDataSource *dataSource = [ASTableViewFilledDataSource new];
    
    tableView.asyncDelegate = dataSource;
    tableView.asyncDataSource = dataSource;
    
    for (int i = 0; i < 100; ++i)
    {
        [tableView reloadData];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

@end

//
//  ASDebugOverlayRootViewController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDebugOverlayRootViewController.h"
#import "ASDebugOverlayElementDetailViewController.h"

@interface ASDebugOverlayRootViewController () <ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong) ASTableNode *tableNode;
@end

@implementation ASDebugOverlayRootViewController

- (instancetype)init
{
  ASTableNode *table = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  if (self = [super initWithNode:table]) {
    _tableNode = table;
    table.delegate = self;
    table.dataSource = self;
    self.title = @"Debug Menu";
  }
  return self;
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return self.tree.totalCount;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.tableNode deselectRowAtIndexPath:self.tableNode.indexPathForSelectedRow animated:animated];
}

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSIndexPath *treeIndexPath = [self.tree indexPathForIndex:indexPath.item];
  ASLayoutSpecTree *tree = [self.tree subtreeAtIndexPath:treeIndexPath];
  NSMutableString *d = [NSMutableString string];
  for (NSInteger i = 0; i < treeIndexPath.length; i++) {
    [d appendString:@"\t"];
  }
  [d appendString:tree.context.element.description];
  return ^{
    ASTextCellNode *node = [[ASTextCellNode alloc] init];
    node.text = d;
    return node;
  };
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSIndexPath *treeIndexPath = [self.tree indexPathForIndex:indexPath.item];
  ASLayoutSpecTree *tree = [self.tree subtreeAtIndexPath:treeIndexPath];
  ASDebugOverlayElementDetailViewController *vc = [[ASDebugOverlayElementDetailViewController alloc] initWithTree:tree];
  [self showViewController:vc sender:nil];
}

@end

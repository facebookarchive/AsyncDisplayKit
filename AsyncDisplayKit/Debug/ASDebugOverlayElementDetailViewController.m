//
//  ASDebugOverlayElementDetailViewController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDebugOverlayElementDetailViewController.h"
#import "ASLayoutSpecDebuggingContext.h"

@interface ASDebugOverlayElementDetailViewController () <ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong, readonly) ASLayoutSpecTree *tree;
@end

@implementation ASDebugOverlayElementDetailViewController

- (instancetype)initWithTree:(ASLayoutSpecTree *)tree
{
  ASTableNode *tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
  if (self = [super initWithNode:tableNode]) {
    tableNode.delegate = self;
    tableNode.dataSource = self;
    self.title = NSStringFromClass(tree.context.element.class);
    _tree = tree;
  }
  return self;
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return 0;
}

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    return [[ASCellNode alloc] init];
  };
}

@end

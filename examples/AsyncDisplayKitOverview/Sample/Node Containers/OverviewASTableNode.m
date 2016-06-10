//
//  OverviewASTableNode.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 4/17/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "OverviewASTableNode.h"

@interface OverviewASTableNode () <ASTableDataSource, ASTableDelegate>
@property (nonatomic, strong) ASTableNode *node;
@end

@implementation OverviewASTableNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _node = [ASTableNode new];
    _node.dataSource = self;
    _node.delegate = self;
    [self addSubnode:_node];

    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    _node.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[_node]];
}


#pragma mark - <ASCollectionDataSource, ASCollectionDelegate>

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 100;
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return ^{
        ASTextCellNode *cellNode = [ASTextCellNode new];
        cellNode.text = [NSString stringWithFormat:@"Row: %ld", indexPath.row];
        return cellNode;
    };
}

@end

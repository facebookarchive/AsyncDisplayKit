//
//  OverviewASCollectionNode.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 4/17/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "OverviewASCollectionNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface OverviewASCollectionNode () <ASCollectionDataSource, ASCollectionDelegate>
@property (nonatomic, strong) ASCollectionNode *node;
@end

@implementation OverviewASCollectionNode

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
    _node = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
    _node.dataSource = self;
    _node.delegate = self;
    [self addSubnode:_node];;
    
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    self.node.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[self.node]];
}

#pragma mark - <ASCollectionDataSource, ASCollectionDelegate>

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 100;
}

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return ^{
        ASTextCellNode *cellNode = [ASTextCellNode new];
        cellNode.backgroundColor = [UIColor lightGrayColor];
        cellNode.text = [NSString stringWithFormat:@"Row: %ld", indexPath.row];
        return cellNode;
    };
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(100, 100);
}

@end

//
//  OverviewASCollectionViewNode.m
//  AsyncDisplayKitOverview
//
//  Created by Michael Schneider on 4/17/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

//
//  ASFakeContentDataSource.m
//  ASVerticalCollecttionNode
//
//  Created by Kieran Lafferty on 12/21/15.
//  Copyright © 2015 Kieran Lafferty. All rights reserved.
//

#import "ASFakeContentDataSource.h"

@implementation ASFakeContentDataSource

#pragma mark - ASCollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 10;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ASTextCellNode *textCellNode = [[ASTextCellNode alloc] init];
    textCellNode.text = @"Some text...";
    return textCellNode;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
    CGSize cellSize = CGSizeMake(CGRectGetWidth(collectionView.bounds), 44.0);
    return ASSizeRangeMake(cellSize, cellSize);
}

@end

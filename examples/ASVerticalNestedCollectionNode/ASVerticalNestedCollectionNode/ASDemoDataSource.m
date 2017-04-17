//
//  ASDemoDataSource.m
//  
//
//  Created by Kieran Lafferty on 12/21/15.
//
//

#import "ASDemoDataSource.h"

#import "ASEmbeddedCollectionCellNode.h"

@implementation ASDemoDataSource
{
    NSArray<ASCollectionNode *> *_collectionNodes;
}

- (nonnull instancetype)initWithCollectionNodes:(nonnull NSArray<ASCollectionNode *> *)collectionNodes
{
    if (self = [super init]) {
        _collectionNodes = collectionNodes;
    }
    return self;
}

#pragma mark - ASCollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return _collectionNodes.count;
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ASCollectionNode *embeddedCollectionNode = [self _collectionNodeAtIndexPath:indexPath];
    ASEmbeddedCollectionCellNode *cell = [[ASEmbeddedCollectionCellNode alloc] initWithCollectionNode:embeddedCollectionNode];
    return cell;
}

#pragma mark - ASCollectionViewDelegateFlowLayout


#pragma mark - Helpers

- (nonnull ASCollectionNode *)_collectionNodeAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    return [_collectionNodes objectAtIndex:indexPath.row];
}

@end

//
//  ASDemoViewController.m
//  ASVerticalCollecttionNode
//
//  Created by Kieran Lafferty on 12/21/15.
//  Copyright © 2015 Kieran Lafferty. All rights reserved.
//

#import "ASDemoViewController.h"

#import "ASDemoDataSource.h"
#import "ASFakeContentDataSource.h"

@implementation ASDemoViewController
{
    ASCollectionNode *_collectionNode;
    ASDemoDataSource *_dataSource;
    
    NSArray<ASFakeContentDataSource *> *_embeddedDataSources;
    NSArray<ASCollectionNode *> *_embeddedCollectionNodes;
}

- (instancetype) init
{
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
    if (self = [super initWithNode:_collectionNode]) {
        
        // Add some demo data to the embedded collection nodes
        NSMutableArray<ASFakeContentDataSource *> *dataSources = [[NSMutableArray alloc] initWithCapacity:10];
        for (int i = 0; i < 10; i ++) {
            ASFakeContentDataSource *dataSource = [[ASFakeContentDataSource alloc] init];
            [dataSources addObject:dataSource];
        }
        _embeddedCollectionNodes = [dataSources copy];
        
        NSMutableArray<ASCollectionNode *> *collectionNodes = [[NSMutableArray alloc] initWithCapacity:10];
        for (id<ASCollectionViewDataSource, ASCollectionViewDelegate> dataSource in _embeddedCollectionNodes) {
            UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
            ASCollectionNode *collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:flowLayout];
            
            // Note: Heres the issue since we can't calculate size without first setting the data source, and can't layout if we access the view of the node (causes thread affinity assert)
            collectionNode.view.asyncDataSource = dataSource;
            collectionNode.view.asyncDelegate = dataSource;
            [collectionNodes addObject:collectionNode];
        }
        _embeddedCollectionNodes = [collectionNodes copy];
        
        _dataSource = [[ASDemoDataSource alloc] initWithCollectionNodes:_embeddedCollectionNodes];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _collectionNode.view.asyncDataSource = _dataSource;
    _collectionNode.view.asyncDelegate = _dataSource;
}
@end

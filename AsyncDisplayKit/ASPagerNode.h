//
//  ASPagerNode.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionNode.h>

@class ASPagerNode;
@protocol ASPagerNodeDataSource <NSObject>
// This method replaces -collectionView:numberOfItemsInSection:
- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode;

// This method replaces -collectionView:nodeForItemAtIndexPath:
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index;
@end

@interface ASPagerNode : ASCollectionNode

// Configures a default horizontal, paging flow layout with 0 inter-item spacing.
- (instancetype)init;

// Initializer with custom-configured flow layout properties.
- (instancetype)initWithFlowLayout:(UICollectionViewFlowLayout *)flowLayout;

// The underlying ASCollectionView object.
- (ASCollectionView *)collectionView;

// Delegate is optional, and uses the same protocol as ASCollectionNode.
// This includes UIScrollViewDelegate as well as most methods from UICollectionViewDelegate, like willDisplay...
@property (weak, nonatomic) id <ASCollectionDelegate>  delegate;

// Data Source is required, and uses a different protocol from ASCollectionNode.
- (void)setDataSource:(id <ASPagerNodeDataSource>)dataSource;
- (id <ASPagerNodeDataSource>)dataSource;

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated;

@end


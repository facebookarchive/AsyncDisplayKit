//
//  ASPagerNode.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionNode.h>

@class ASPagerNode;
@class ASPagerFlowLayout;

@protocol ASPagerNodeDataSource <NSObject>

/**
 * This method replaces -collectionView:numberOfItemsInSection:
 *
 * @param pagerNode The sender.
 *
 *
 * @returns The total number of pages that can display in the pagerNode.
 */
- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode;

@optional

/**
 * This method replaces -collectionView:nodeForItemAtIndexPath:
 *
 * @param pagerNode The sender.
 *
 * @param index The index of the requested node.
 *
 * @returns a node for display at this index. This will be called on the main thread and should
 *   not implement reuse (it will be called once per row).  Unlike UICollectionView's version,
 *   this method is not called when the row is about to display.
 */
- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index;

/**
 * This method replaces -collectionView:nodeBlockForItemAtIndexPath:
 * This method takes precedence over pagerNode:nodeAtIndex: if implemented.
 *
 * @param pagerNode The sender.
 *
 * @param index The index of the requested node.
 *
 * @returns a block that creates the node for display at this index.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index;

/**
 * Provides the constrained size range for measuring the node at the index path.
 *
 * @param pagerNode The sender.
 *
 * @param indexPath The index path of the node.
 *
 * @returns A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)pagerNode:(ASPagerNode *)pagerNode constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface ASPagerNode : ASCollectionNode

// Configures a default horizontal, paging flow layout with 0 inter-item spacing.
- (instancetype)init;

// Initializer with custom-configured flow layout properties.
- (instancetype)initWithCollectionViewLayout:(ASPagerFlowLayout *)flowLayout;

// Data Source is required, and uses a different protocol from ASCollectionNode.
- (void)setDataSource:(id <ASPagerNodeDataSource>)dataSource;
- (id <ASPagerNodeDataSource>)dataSource;

// Delegate is optional, and uses the same protocol as ASCollectionNode.
// This includes UIScrollViewDelegate as well as most methods from UICollectionViewDelegate, like willDisplay...
@property (nonatomic, weak) id <ASCollectionDelegate> delegate;

// The underlying ASCollectionView object.
@property (nonatomic, readonly) ASCollectionView *view;

- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated;

@end


//
//  ASPagerNode.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASDataController.h>

@class ASPagerNode;
@class ASPagerFlowLayout;

#define ASPagerNodeDataSource ASPagerDataSource
@protocol ASPagerDataSource <NSObject>

/**
 * This method replaces -collectionView:numberOfItemsInSection:
 *
 * @param pagerNode The sender.
 * @returns The total number of pages that can display in the pagerNode.
 */
- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode;

@optional

/**
 * This method replaces -collectionView:nodeForItemAtIndexPath:
 *
 * @param pagerNode The sender.
 * @param index     The index of the requested node.
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
 * @param index     The index of the requested node.
 * @returns a block that creates the node for display at this index.
 *   Must be thread-safe (can be called on the main thread or a background
 *   queue) and should not implement reuse (it will be called once per row).
 */
- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index;

/**
 * Provides the constrained size range for measuring the node at the index path.
 *
 * @param pagerNode The sender.
 * @param indexPath The index path of the node.
 * @returns A constrained size range for layout the node at this index path.
 */
- (ASSizeRange)pagerNode:(ASPagerNode *)pagerNode constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath;

@end

@protocol ASPagerDelegate <ASCollectionDelegate>

@end

@interface ASPagerNode : ASCollectionNode

/**
 * Configures a default horizontal, paging flow layout with 0 inter-item spacing.
 */
- (instancetype)init;

/**
 * Initializer with custom-configured flow layout properties.
 */
- (instancetype)initWithCollectionViewLayout:(ASPagerFlowLayout *)flowLayout;

/**
 * Data Source is required, and uses a different protocol from ASCollectionNode.
 */
- (void)setDataSource:(id <ASPagerDataSource>)dataSource;
- (id <ASPagerDataSource>)dataSource;

/**
 * Delegate is optional, and uses the same protocol as ASCollectionNode.
 * This includes UIScrollViewDelegate as well as most methods from UICollectionViewDelegate, like willDisplay...
 */
@property (nonatomic, weak) id <ASPagerDelegate> delegate;

/**
 * The underlying ASCollectionView object.
 */
@property (nonatomic, readonly) ASCollectionView *view;

/**
 * Returns the current page index
 */
@property (nonatomic, assign, readonly) NSInteger currentPageIndex;

/**
 * Scroll the contents of the receiver to ensure that the page is visible
 */
- (void)scrollToPageAtIndex:(NSInteger)index animated:(BOOL)animated;

/**
 * Returns the node for the passed page index
 */
- (ASCellNode *)nodeForPageAtIndex:(NSInteger)index;

@end

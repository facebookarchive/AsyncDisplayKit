//
//  ASTableNode.h
//  AsyncDisplayKit
//
//  Created by Steven Ramkumar on 11/4/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableView.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASTableDataSource;
@protocol ASTableDelegate;
@class ASTableView;

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode <ASRangeControllerUpdateRangeProtocol>

- (instancetype)init; // UITableViewStylePlain
- (instancetype)initWithStyle:(UITableViewStyle)style;

@property (strong, nonatomic, readonly) ASTableView *view;

// These properties can be set without triggering the view to be created, so it's fine to set them in -init.
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;

/**
 * TODO: Docs
 */
- (NSInteger)numberOfRowsInSection:(NSInteger)section AS_WARN_UNUSED_RESULT;

/**
 * TODO: Docs
 */
@property (nonatomic, readonly) NSInteger numberOfSections;

/**
 * Retrieves the node for the row at the given index path.
 */
- (nullable ASCellNode *)nodeForRowAtIndexPath:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

/**
 * Similar to -indexPathForCell:.
 *
 * @param cellNode a cellNode part of the table view
 *
 * @return an indexPath for this cellNode
 *
 * @discussion This method will return @c nil for a node that is still being
 *   displayed in the table view, if the data source has deleted the row.
 *   That is, the node is visible but it no longer corresponds
 *   to any item in the data source and will be removed soon.
 */
- (nullable NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode AS_WARN_UNUSED_RESULT;

/**
 * TODO: Docs
 */
- (nullable NSIndexPath *)convertIndexPathToTableNode:(NSIndexPath *)indexPath AS_WARN_UNUSED_RESULT;

@end

NS_ASSUME_NONNULL_END

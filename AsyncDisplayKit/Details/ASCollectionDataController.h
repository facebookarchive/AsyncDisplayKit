//
//  ASCollectionDataController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASDisplayNode;
@class ASCollectionDataController;
@protocol ASSectionContext;

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionDataControllerSource <ASDataControllerSource>

/**
 The constrained size range for layout.
 */
- (ASSizeRange)dataController:(ASCollectionDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSArray<NSString *> *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController sections:(NSIndexSet *)sections;

- (NSUInteger)dataController:(ASCollectionDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section;

- (nullable id<ASSectionContext>)dataController:(ASCollectionDataController *)dataController contextForSection:(NSInteger)section;

@optional

- (ASCellNode *)dataController:(ASCollectionDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (ASCellNodeBlock)dataController:(ASCollectionDataController *)dataController supplementaryNodeBlockOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end

@interface ASCollectionDataController : ASDataController

- (instancetype)initWithDataSource:(id<ASCollectionDataControllerSource>)dataSource eventLog:(nullable ASEventLog *)eventLog NS_DESIGNATED_INITIALIZER;

- (nullable ASCellNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (nullable id<ASSectionContext>)contextForSection:(NSInteger)section;

@end

NS_ASSUME_NONNULL_END

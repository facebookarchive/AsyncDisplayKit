/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASChangeSetDataController.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASDisplayNode;
@class ASCollectionDataController;
@protocol ASDataControllerSource;

@protocol ASCollectionDataControllerSource <ASDataControllerSource>

- (ASCellNode *)dataController:(ASCollectionDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 The constrained size range for layout.
 */
- (ASSizeRange)dataController:(ASCollectionDataController *)dataController constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSArray *)supplementaryNodeKindsInDataController:(ASCollectionDataController *)dataController;

- (NSUInteger)dataController:(ASCollectionDataController *)dataController numberOfSectionsForSupplementaryNodeOfKind:(NSString *)kind;

- (NSUInteger)dataController:(ASCollectionDataController *)dataController supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section;

@end

@interface ASCollectionDataController : ASChangeSetDataController

- (ASCellNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end
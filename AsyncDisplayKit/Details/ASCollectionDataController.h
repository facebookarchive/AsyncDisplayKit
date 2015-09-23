/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASDimension.h>

@class ASDisplayNode;
@class ASCollectionDataController;
@protocol ASDataControllerSource;

@protocol ASCollectionDataControllerSource <ASDataControllerSource>

- (ASDisplayNode *)dataController:(ASDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSArray *)supplementaryKindsInDataController:(ASCollectionDataController *)dataController;

- (NSUInteger)dataController:(ASCollectionDataController *)dataController numberOfSectionsForSupplementaryKind:(NSString *)kind;

- (NSUInteger)dataController:(ASCollectionDataController *)dataController rowsInSection:(NSUInteger)section supplementaryKind:(NSString *)kind;

@end

@interface ASCollectionDataController : ASDataController

- (ASDisplayNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end
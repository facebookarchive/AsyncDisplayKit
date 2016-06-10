//
//  ASChangeSetDataController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 19/10/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDataController.h>

/**
 * @abstract Subclass of ASDataController that simulates ordering of operations in batch updates defined in UITableView and UICollectionView.
 * 
 * @discussion The ordering is achieved by using _ASHierarchyChangeSet to enqueue and sort operations.
 * More information about the ordering and the index paths used for operations can be found here:
 * https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/TableView_iPhone/ManageInsertDeleteRow/ManageInsertDeleteRow.html#//apple_ref/doc/uid/TP40007451-CH10-SW17
 *
 * @see ASDataController
 * @see _ASHierarchyChangeSet
 */
@interface ASChangeSetDataController : ASDataController

@end

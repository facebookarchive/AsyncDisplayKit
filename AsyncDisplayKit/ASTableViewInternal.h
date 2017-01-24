//
//  ASTableViewInternal.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 26/10/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableView.h>

@class ASDataController;
@class ASTableNode;
@class ASRangeController;
@class ASEventLog;

@interface ASTableView (Internal)

@property (nonatomic, strong, readonly) ASDataController *dataController;
@property (nonatomic, weak, readwrite) ASTableNode *tableNode;
@property (nonatomic, strong, readonly) ASRangeController *rangeController;

/**
 * Initializer.
 *
 * @param frame A rectangle specifying the initial location and size of the table view in its superview’s coordinates.
 * The frame of the table view changes as table cells are added and deleted.
 *
 * @param style A constant that specifies the style of the table view. See UITableViewStyle for descriptions of valid constants.
 *
 * @param dataControllerClass A controller class injected to and used to create a data controller for the table view.
 *
 * @param eventLog An event log passed through to the data controller.
 */
- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass eventLog:(ASEventLog *)eventLog;

/// Set YES and we'll log every time we call [super insertRows…] etc
@property (nonatomic) BOOL test_enableSuperUpdateCallLogging;

/**
 * Attempt to get the view-layer index path for the row with the given index path.
 *
 * @param indexPath The index path of the row.
 * @param wait If the item hasn't reached the view yet, this attempts to wait for updates to commit.
 */
- (NSIndexPath *)convertIndexPathFromTableNode:(NSIndexPath *)indexPath waitingIfNeeded:(BOOL)wait;

/**
 * Attempt to get the node index path given the view-layer index path.
 *
 * @param indexPath The index path of the row.
 */
- (NSIndexPath *)convertIndexPathToTableNode:(NSIndexPath *)indexPath;

/**
 * Attempt to get the node index paths given the view-layer index paths.
 *
 * @param indexPaths An array of index paths in the view space
 */
- (NSArray<NSIndexPath *> *)convertIndexPathsToTableNode:(NSArray<NSIndexPath *> *)indexPaths;

/// Returns the width of the section index view on the right-hand side of the table, if one is present.
- (CGFloat)sectionIndexWidth;

@end

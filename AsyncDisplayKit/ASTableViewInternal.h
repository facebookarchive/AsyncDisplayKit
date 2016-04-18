//
//  ASTableViewInternal.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 26/10/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASTableNode.h"

@class ASDataController;

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
 * @param ownedByNode Indicates whether the tableView is owned by an ASTableNode.
 */
- (instancetype)_initWithFrame:(CGRect)frame style:(UITableViewStyle)style dataControllerClass:(Class)dataControllerClass ownedByNode:(BOOL)ownedByNode;

@end

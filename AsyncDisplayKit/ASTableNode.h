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

@protocol ASTableDataSource;
@protocol ASTableDelegate;
@class ASTableView;

/**
 * ASTableNode is a node based class that wraps an ASTableView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASTableNode : ASDisplayNode

- (instancetype)init; // UITableViewStylePlain
- (instancetype)initWithStyle:(UITableViewStyle)style;

@property (strong, nonatomic, readonly) ASTableView *view;

// These properties can be set without triggering the view to be created, so it's fine to set them in -init.
@property (weak, nonatomic) id <ASTableDelegate>   delegate;
@property (weak, nonatomic) id <ASTableDataSource> dataSource;

@end

@interface ASTableNode (ASRangeControllerUpdateRangeProtocol) <ASRangeControllerUpdateRangeProtocol>

@end

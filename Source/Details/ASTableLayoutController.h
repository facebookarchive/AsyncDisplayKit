//
//  ASTableLayoutController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASAbstractLayoutController.h>

NS_ASSUME_NONNULL_BEGIN

@class UITableView;

/**
 *  A layout controller designed for use with UITableView.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASTableLayoutController : ASAbstractLayoutController

@property (nonatomic, weak, readonly) UITableView *tableView;

- (instancetype)initWithTableView:(UITableView *)tableView;

@end

NS_ASSUME_NONNULL_END

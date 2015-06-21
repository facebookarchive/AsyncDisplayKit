/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASAbstractLayoutController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>


typedef NS_ENUM(NSUInteger, ASFlowLayoutDirection) {
  ASFlowLayoutDirectionVertical,
  ASFlowLayoutDirectionHorizontal,
};

/**
 * The controller for flow layout.
 */
@interface ASFlowLayoutController : ASAbstractLayoutController

@property (nonatomic, readonly, assign) ASFlowLayoutDirection layoutDirection;

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection;

@end

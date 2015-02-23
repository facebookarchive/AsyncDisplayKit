/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASDisplayNode.h>


/**
 * Simple node that wraps UIScrollView.
 */
@interface ASScrollNode : ASDisplayNode

/**
 * @abstract The node's UIScrollView.
 */
@property (nonatomic, readonly, strong) UIScrollView *view;

@end

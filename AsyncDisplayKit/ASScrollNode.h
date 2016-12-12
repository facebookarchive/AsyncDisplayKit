//
//  ASScrollNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIScrollView.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Simple node that wraps UIScrollView.
 */
@interface ASScrollNode : ASDisplayNode

/**
 * @abstract The node's UIScrollView.
 */
@property (nonatomic, readonly, strong) UIScrollView *view;

/**
 * @abstract When enabled, the size calculated by the node's layout spec is used as
 * the .contentSize of the scroll view, instead of the bounds size.  The bounds is instead
 * allowed to match the parent's size (whenever it is finite - otherwise, the bounds size
 * also grows to the full contentSize).  It also works with .layoutSpecBlock().
 * NOTE: Most users of ASScrollView will want to use this, and may be enabled by default later.
 */
@property (nonatomic, assign) BOOL automaticallyManagesContentSize;

@end

NS_ASSUME_NONNULL_END

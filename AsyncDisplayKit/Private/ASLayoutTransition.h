//
//  ASLayoutTransition.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/8/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDimension.h"
#import "_ASTransitionContext.h"

@class ASDisplayNode;
@class ASLayout;

@interface ASLayoutTransition : NSObject <_ASTransitionContextLayoutDelegate>

/**
 * Node to apply layout transition on
 */
@property (nonatomic, readonly, weak) ASDisplayNode *node;

/**
 * Previous layout to transition from
 */
@property (nonatomic, readonly, strong) ASLayout *previousLayout;

/**
 * Pending layout to transition to
 */
@property (nonatomic, readonly, strong) ASLayout *pendingLayout;

/**
 * Returns if the layout transition can happen asynchronously
 */
@property (nonatomic, readonly, assign) BOOL isSynchronous;

/**
 * Returns a newly initialized layout transition
 */
- (instancetype)initWithNode:(ASDisplayNode *)node pendingLayout:(ASLayout *)pendingLayout previousLayout:(ASLayout *)previousLayout NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/**
 * Insert and remove subnodes that where added or removed between the previousLayout and the pendingLayout
 */
- (void)startTransition;

/**
 * Insert all new subnodes that where added between the previous layout and the pending layout
 */
- (void)applySubnodeInsertions;

/**
 * Remove all subnodes that are removed between the previous layout and the pending layout
 */
- (void)applySubnodeRemovals;

@end

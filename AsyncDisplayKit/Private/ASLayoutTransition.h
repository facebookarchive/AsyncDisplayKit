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
#import "ASDisplayNodeLayout.h"

#import <memory>

NS_ASSUME_NONNULL_BEGIN

@class ASDisplayNode;

@interface ASLayoutTransition : NSObject <_ASTransitionContextLayoutDelegate>

/**
 * Node to apply layout transition on
 */
@property (nonatomic, readonly, weak) ASDisplayNode *node;

/**
 * Previous layout to transition from
 */
@property (nonatomic, readonly, assign) std::shared_ptr<ASDisplayNodeLayout> previousLayout;

/**
 * Pending layout to transition to
 */
@property (nonatomic, readonly, assign) std::shared_ptr<ASDisplayNodeLayout> pendingLayout;

/**
 * Returns if the layout transition needs to happen synchronously
 */
@property (nonatomic, readonly, assign) BOOL isSynchronous;

/**
 * Returns a newly initialized layout transition
 */
- (instancetype)initWithNode:(ASDisplayNode *)node
               pendingLayout:(std::shared_ptr<ASDisplayNodeLayout>)pendingLayout
              previousLayout:(std::shared_ptr<ASDisplayNodeLayout>)previousLayout NS_DESIGNATED_INITIALIZER;

/**
 * Insert and remove subnodes that were added or removed between the previousLayout and the pendingLayout
 */
- (void)commitTransition;

/**
 * Insert all new subnodes that were added between the previous layout and the pending layout
 */
- (void)applySubnodeInsertions;

/**
 * Remove all subnodes that are removed between the previous layout and the pending layout
 */
- (void)applySubnodeRemovals;

@end

@interface ASLayoutTransition (Unavailable)

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END

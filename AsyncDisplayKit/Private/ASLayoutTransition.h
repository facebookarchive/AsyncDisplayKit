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

@property (nonatomic, readonly, weak) ASDisplayNode *node;
@property (nonatomic, readonly, strong) ASLayout *pendingLayout;
@property (nonatomic, readonly, strong) ASLayout *previousLayout;

- (instancetype)initWithNode:(ASDisplayNode *)node
               pendingLayout:(ASLayout *)pendingLayout
              previousLayout:(ASLayout *)previousLayout;

- (void)applySubnodeInsertions;

- (void)applySubnodeRemovals;

@end

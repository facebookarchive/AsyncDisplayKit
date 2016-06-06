//
//  ASLayoutTransition.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/8/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

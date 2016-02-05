//
//  _ASTransitionContext.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ASContextTransitioning.h"

@class ASLayout;
@class _ASTransitionContext;

@protocol _ASTransitionContextDelegate <NSObject>

- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete;
- (CGRect)transitionContext:(_ASTransitionContext *)context initialFrameForNode:(ASDisplayNode *)node;
- (CGRect)transitionContext:(_ASTransitionContext *)context finalFrameForNode:(ASDisplayNode *)node;

- (NSArray<ASLayout *> *)sublayoutsForTransitioningContext:(_ASTransitionContext *)context;

@end

@interface _ASTransitionContext : NSObject <ASContextTransitioning>

@property (assign, readonly, nonatomic, getter=isAnimated) BOOL animated;

- (instancetype)initWithAnimation:(BOOL)animated delegate:(id<_ASTransitionContextDelegate>)delegate;

@end

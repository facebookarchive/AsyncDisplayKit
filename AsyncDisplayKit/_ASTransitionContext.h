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

- (NSArray<ASDisplayNode *> *)currentSubnodesWithTransitionContext:(_ASTransitionContext *)context;
- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete;

@end

@interface _ASTransitionContext : NSObject <ASContextTransitioning>

@property (assign, readonly, nonatomic, getter=isAnimated) BOOL animated;

@property (strong, readonly) ASLayout *layout;

@property (assign, readonly) ASSizeRange constrainedSize;

- (instancetype)initWithLayout:(ASLayout *)layout constrainedSize:(ASSizeRange)constrainedSize animated:(BOOL)animated delegate:(id<_ASTransitionContextDelegate>)delegate;

@end

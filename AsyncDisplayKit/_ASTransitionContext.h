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

- (NSArray<ASDisplayNode *> *)insertedSubnodesWithTransitionContext:(_ASTransitionContext *)context;
- (NSArray<ASDisplayNode *> *)removedSubnodesWithTransitionContext:(_ASTransitionContext *)context;

- (ASLayout *)transitionContext:(_ASTransitionContext *)context layoutForKey:(NSString *)key;
- (ASSizeRange)transitionContext:(_ASTransitionContext *)context constrainedSizeForKey:(NSString *)key;

- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete;

@end

@interface _ASTransitionContext : NSObject <ASContextTransitioning>

@property (assign, readonly, nonatomic, getter=isAnimated) BOOL animated;

- (instancetype)initWithAnimation:(BOOL)animated delegate:(id<_ASTransitionContextDelegate>)delegate;

@end

//
//  _ASTransitionContext.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASContextTransitioning.h>

@class ASLayout;
@class _ASTransitionContext;

@protocol _ASTransitionContextLayoutDelegate <NSObject>

- (NSArray<ASDisplayNode *> *)currentSubnodesWithTransitionContext:(_ASTransitionContext *)context;

- (NSArray<ASDisplayNode *> *)insertedSubnodesWithTransitionContext:(_ASTransitionContext *)context;
- (NSArray<ASDisplayNode *> *)removedSubnodesWithTransitionContext:(_ASTransitionContext *)context;

- (ASLayout *)transitionContext:(_ASTransitionContext *)context layoutForKey:(NSString *)key;
- (ASSizeRange)transitionContext:(_ASTransitionContext *)context constrainedSizeForKey:(NSString *)key;

@end

@protocol _ASTransitionContextCompletionDelegate <NSObject>

- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete;

@end

@interface _ASTransitionContext : NSObject <ASContextTransitioning>

@property (assign, readonly, nonatomic, getter=isAnimated) BOOL animated;

- (instancetype)initWithAnimation:(BOOL)animated
                   layoutDelegate:(id<_ASTransitionContextLayoutDelegate>)layoutDelegate
               completionDelegate:(id<_ASTransitionContextCompletionDelegate>)completionDelegate;

@end

@interface _ASAnimatedTransitionContext : NSObject
@property (nonatomic, strong, readonly) ASDisplayNode *node;
@property (nonatomic, assign, readonly) CGFloat alpha;
+ (instancetype)contextForNode:(ASDisplayNode *)node alpha:(CGFloat)alphaValue;
@end

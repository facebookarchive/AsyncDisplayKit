//
//  _ASTransitionContext.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASTransitionContext.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayout.h>


NSString * const ASTransitionContextFromLayoutKey = @"org.asyncdisplaykit.ASTransitionContextFromLayoutKey";
NSString * const ASTransitionContextToLayoutKey = @"org.asyncdisplaykit.ASTransitionContextToLayoutKey";

@interface _ASTransitionContext ()

@property (weak, nonatomic) id<_ASTransitionContextLayoutDelegate> layoutDelegate;
@property (weak, nonatomic) id<_ASTransitionContextCompletionDelegate> completionDelegate;

@end

@implementation _ASTransitionContext

- (instancetype)initWithAnimation:(BOOL)animated
                     layoutDelegate:(id<_ASTransitionContextLayoutDelegate>)layoutDelegate
                 completionDelegate:(id<_ASTransitionContextCompletionDelegate>)completionDelegate
{
  self = [super init];
  if (self) {
    _animated = animated;
    _layoutDelegate = layoutDelegate;
    _completionDelegate = completionDelegate;
  }
  return self;
}

#pragma mark - ASContextTransitioning Protocol Implementation

- (ASLayout *)layoutForKey:(NSString *)key
{
  return [_layoutDelegate transitionContext:self layoutForKey:key];
}

- (ASSizeRange)constrainedSizeForKey:(NSString *)key
{
  return [_layoutDelegate transitionContext:self constrainedSizeForKey:key];
}

- (CGRect)initialFrameForNode:(ASDisplayNode *)node
{
  return [[self layoutForKey:ASTransitionContextFromLayoutKey] frameForElement:node];
}

- (CGRect)finalFrameForNode:(ASDisplayNode *)node
{
  return [[self layoutForKey:ASTransitionContextToLayoutKey] frameForElement:node];
}

- (NSArray<ASDisplayNode *> *)subnodesForKey:(NSString *)key
{
  NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
  for (ASLayout *sublayout in [self layoutForKey:key].sublayouts) {
    [subnodes addObject:(ASDisplayNode *)sublayout.layoutElement];
  }
  return subnodes;
}

- (NSArray<ASDisplayNode *> *)insertedSubnodes
{
  return [_layoutDelegate insertedSubnodesWithTransitionContext:self];
}

- (NSArray<ASDisplayNode *> *)removedSubnodes
{
  return [_layoutDelegate removedSubnodesWithTransitionContext:self];
}

- (void)completeTransition:(BOOL)didComplete
{
  [_completionDelegate transitionContext:self didComplete:didComplete];
}

@end


@interface _ASAnimatedTransitionContext ()
@property (nonatomic, strong, readwrite) ASDisplayNode *node;
@property (nonatomic, assign, readwrite) CGFloat alpha;
@end

@implementation _ASAnimatedTransitionContext

+ (instancetype)contextForNode:(ASDisplayNode *)node alpha:(CGFloat)alpha
{
  _ASAnimatedTransitionContext *context = [[_ASAnimatedTransitionContext alloc] init];
  context.node = node;
  context.alpha = alpha;
  return context;
}

@end

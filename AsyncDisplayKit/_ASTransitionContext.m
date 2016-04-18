//
//  _ASTransitionContext.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "_ASTransitionContext.h"

#import "ASLayout.h"


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
  for (ASDisplayNode *subnode in [_layoutDelegate currentSubnodesWithTransitionContext:self]) {
    if (node == subnode) {
      return node.frame;
    }
  }
  return CGRectZero;
}

- (CGRect)finalFrameForNode:(ASDisplayNode *)node
{
  for (ASLayout *layout in [self layoutForKey:ASTransitionContextToLayoutKey].sublayouts) {
    if (layout.layoutableObject == node) {
      return [layout frame];
    }
  }
  return CGRectZero;
}

- (NSArray<ASDisplayNode *> *)subnodesForKey:(NSString *)key
{
  NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
  for (ASLayout *sublayout in [self layoutForKey:key].immediateSublayouts) {
    [subnodes addObject:(ASDisplayNode *)sublayout.layoutableObject];
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

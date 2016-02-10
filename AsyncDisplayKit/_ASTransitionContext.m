//
//  _ASTransitionContext.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "_ASTransitionContext.h"

#import "ASLayout.h"

@interface _ASTransitionContext ()

@property (weak, nonatomic) id<_ASTransitionContextDelegate> delegate;

@end

@implementation _ASTransitionContext

- (instancetype)initWithLayout:(ASLayout *)layout constrainedSize:(ASSizeRange)constrainedSize animated:(BOOL)animated delegate:(id<_ASTransitionContextDelegate>)delegate
{
  self = [super init];
  if (self) {
    _layout = layout;
    _constrainedSize = constrainedSize;
    _animated = animated;
    _delegate = delegate;
  }
  return self;
}

#pragma mark - ASContextTransitioning Protocol Implementation

- (CGRect)initialFrameForNode:(ASDisplayNode *)node
{
  for (ASDisplayNode *subnode in [_delegate currentSubnodesWithTransitionContext:self]) {
    if (node == subnode) {
      return node.frame;
    }
  }
  return CGRectZero;
}

- (CGRect)finalFrameForNode:(ASDisplayNode *)node
{
  for (ASLayout *layout in _layout.sublayouts) {
    if (layout.layoutableObject == node) {
      return [layout frame];
    }
  }
  return CGRectZero;
}

- (NSArray<ASDisplayNode *> *)subnodes
{
  NSMutableArray<ASDisplayNode *> *subnodes = [NSMutableArray array];
  for (ASLayout *sublayout in _layout.immediateSublayouts) {
    [subnodes addObject:(ASDisplayNode *)sublayout.layoutableObject];
  }
  return subnodes;
}

- (NSArray<ASDisplayNode *> *)insertedSubnodes
{
  return [_delegate insertedSubnodesWithTransitionContext:self];
}

- (NSArray<ASDisplayNode *> *)removedSubnodes
{
  return [_delegate removedSubnodesWithTransitionContext:self];
}

- (void)completeTransition:(BOOL)didComplete
{
  [_delegate transitionContext:self didComplete:didComplete];
}

@end

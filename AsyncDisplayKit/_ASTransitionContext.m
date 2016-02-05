//
//  _ASTransitionContext.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "_ASTransitionContext.h"

@interface _ASTransitionContext ()

@property (weak, nonatomic) id<_ASTransitionContextDelegate> delegate;

@end

@implementation _ASTransitionContext

- (instancetype)initWithAnimation:(BOOL)animated delegate:(id<_ASTransitionContextDelegate>)delegate
{
  self = [super init];
  if (self) {
    _animated = animated;
    _delegate = delegate;
  }
  return self;
}

- (CGRect)initialFrameForNode:(ASDisplayNode *)node
{
  return [_delegate transitionContext:self initialFrameForNode:node];
}

- (CGRect)finalFrameForNode:(ASDisplayNode *)node
{
  return [_delegate transitionContext:self finalFrameForNode:node];
}

- (NSArray<ASLayout *> *)sublayouts
{
  return [_delegate sublayoutsForTransitioningContext:self];
}

- (void)completeTransition:(BOOL)didComplete
{
  [_delegate transitionContext:self didComplete:didComplete];
}

@end

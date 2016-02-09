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

- (CGRect)initialFrameForNode:(ASDisplayNode *)node
{
  return [_delegate transitionContext:self initialFrameForNode:node];
}

- (CGRect)finalFrameForNode:(ASDisplayNode *)node
{
  return [_delegate transitionContext:self finalFrameForNode:node];
}

- (void)completeTransition:(BOOL)didComplete
{
  [_delegate transitionContext:self didComplete:didComplete];
}

@end

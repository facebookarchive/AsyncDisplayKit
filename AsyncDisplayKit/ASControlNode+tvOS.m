//
//  ASControlNode+tvOS.m
//  AsyncDisplayKit
//
//  Created by Aaron Schubert on 21/04/2016.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
#if TARGET_OS_TV
#import "ASControlNode+tvOS.h"

@implementation ASControlNode (tvOS)

#pragma mark - tvOS
- (void)pressDown
{
  [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationCurveLinear animations:^{
    [self setPressedState];
  } completion:^(BOOL finished) {
    if (finished) {
      [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationCurveLinear animations:^{
        [self setFocusedState];
      } completion:nil];
    }
  }];
}

- (BOOL)canBecomeFocused
{
  return YES;
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
  return YES;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  //FIXME: This is never valid inside an ASCellNode
  if (context.nextFocusedView && context.nextFocusedView == self.view) {
    //Focused
    [coordinator addCoordinatedAnimations:^{
      [self setFocusedState];
    } completion:nil];
  } else{
    //Not focused
    [coordinator addCoordinatedAnimations:^{
      [self setDefaultFocusAppearance];
    } completion:nil];
  }
}

- (void)setFocusedState
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeMake(2, 10);
  [self applyDefaultShadowProperties: layer];
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.1, 1.1);
}

- (void)setPressedState
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeMake(2, 2);
  [self applyDefaultShadowProperties: layer];
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
}

- (void)applyDefaultShadowProperties:(CALayer *)layer
{
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 12.0;
  layer.shadowOpacity = 0.45;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
}

- (void)setDefaultFocusAppearance
{
  CALayer *layer = self.layer;
  layer.shadowOffset = CGSizeZero;
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 0;
  layer.shadowOpacity = 0;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
  self.view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
}
@end
#endif

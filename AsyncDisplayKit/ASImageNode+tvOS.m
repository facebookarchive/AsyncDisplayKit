//
//  ASImageNode+tvOS.m
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
#import "ASImageNode+tvOS.h"
#import <GLKit/GLKit.h>
#import "ASDisplayNodeExtras.h"

@implementation ASImageNode (tvOS)

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];
  self.isDefaultFocusAppearance = NO;
  UIView *view = [self getView];
  CALayer *layer = view.layer;
  
  CGSize targetShadowOffset = CGSizeMake(0.0, self.bounds.size.height/8);
  [layer removeAllAnimations];
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    layer.shadowOffset = targetShadowOffset;
  }];
  
  CABasicAnimation *shadowOffsetAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOffset"];
  shadowOffsetAnimation.toValue = [NSValue valueWithCGSize:targetShadowOffset];
  shadowOffsetAnimation.duration = 0.4;
  shadowOffsetAnimation.removedOnCompletion = NO;
  shadowOffsetAnimation.fillMode = kCAFillModeForwards;
  shadowOffsetAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeOut"];
  [layer addAnimation:shadowOffsetAnimation forKey:@"shadowOffset"];
  [CATransaction commit];
  
  CABasicAnimation *shadowOpacityAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
  shadowOpacityAnimation.toValue = [NSNumber numberWithFloat:0.45];
  shadowOpacityAnimation.duration = 0.4;
  shadowOpacityAnimation.removedOnCompletion = false;
  shadowOpacityAnimation.fillMode = kCAFillModeForwards;
  shadowOpacityAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeOut"];
  [layer addAnimation:shadowOpacityAnimation forKey:@"shadowOpacityAnimation"];
  
  view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25);
  
  [CATransaction commit];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesMoved:touches withEvent:event];
  
  // TODO: Clean up, and improve visuals.
  
  if (!self.isDefaultFocusAppearance) {
    // This view may correspond to either self.view
    // or our superview if we are in a ASCellNode
    UIView *view = [self getView];
    
    UITouch *touch = [touches anyObject];
    // Get the specific point that was touched
    
    // This is quite messy in it's current state so is not ready for production.
    // The reason it is here is for others to contribute and to make it clear what is occuring.
    
    // We get the touch location in self.view because
    // we are operating in that coordinate system.
    // BUT we apply our transforms to *view since we want to apply
    // the transforms to the root view (L: 107)
    CGPoint point = [touch locationInView:self.view];
    float pitch = 0;
    float yaw = 0;
    BOOL topHalf = NO;
    if (point.y > CGRectGetHeight(self.view.frame)) {
      pitch = 15;
    } else if (point.y < -CGRectGetHeight(self.view.frame)) {
      pitch = -15;
    } else {
      pitch = (point.y/CGRectGetHeight(self.view.frame))*15;
    }
    if (pitch < 0) {
      topHalf = YES;
    }
    
    if (point.x > CGRectGetWidth(self.view.frame)) {
      yaw = 10;
    } else if (point.x < -CGRectGetWidth(self.view.frame)) {
      yaw = -10;
    } else {
      yaw = (point.x/CGRectGetWidth(self.view.frame))*10;
    }
    if (!topHalf) {
      if (yaw > 0) {
        yaw = -yaw;
      } else {
        yaw = fabsf(yaw);
      }
    }
    
    CATransform3D pitchTransform = CATransform3DMakeRotation(GLKMathDegreesToRadians(pitch),1.0,0.0,0.0);
    CATransform3D yawTransform = CATransform3DMakeRotation(GLKMathDegreesToRadians(yaw),0.0,1.0,0.0);
    CATransform3D transform = CATransform3DConcat(pitchTransform, yawTransform);
    CATransform3D scaleAndTransform = CATransform3DConcat(transform, CATransform3DMakeAffineTransform(CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25)));
    
    [UIView animateWithDuration:0.5 animations:^{
      view.layer.transform = scaleAndTransform;
    }];
  } else {
    [self setDefaultFocusAppearance];
  }
}


- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];
  [self finishTouches];
}

- (void)finishTouches
{
  if (!self.isDefaultFocusAppearance) {
    UIView *view = [self getView];
    CALayer *layer = view.layer;
    
    CGSize targetShadowOffset = CGSizeMake(0.0, self.bounds.size.height/8);
    CATransform3D targetScaleTransform = CATransform3DMakeScale(1.2, 1.2, 1.2);
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
      layer.shadowOffset = targetShadowOffset;
    }];
    [CATransaction commit];
    
    [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
      view.layer.transform = targetScaleTransform;
    } completion:^(BOOL finished) {
      if (finished) {
        [layer removeAnimationForKey:@"shadowOffset"];
        [layer removeAnimationForKey:@"shadowOpacity"];
      }
    }];
  } else {
    [self setDefaultFocusAppearance];
  }
}

- (void)setFocusedState
{
  UIView *view = [self getView];
  CALayer *layer = view.layer;
  layer.shadowOffset = CGSizeMake(2, 10);
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 12.0;
  layer.shadowOpacity = 0.45;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
  view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25);
}

- (void)setDefaultFocusAppearance
{
  UIView *view = [self getView];
  CALayer *layer = view.layer;
  view.transform = CGAffineTransformIdentity;
  layer.shadowOpacity = 0;
  layer.shadowOffset = CGSizeZero;
  layer.shadowRadius = 0;
  layer.shadowPath = nil;
  [layer removeAnimationForKey:@"shadowOffset"];
  [layer removeAnimationForKey:@"shadowOpacity"];
  self.isDefaultFocusAppearance = YES;
}

- (UIView *)getView
{
  // TODO: This needs to be re-visited to handle all possibilities.
  // If we are inside a ASCellNode, then we need to apply our focus effects to the ASCellNode view/layer rather than the ASImageNode view/layer.
  return ASDisplayNodeUltimateParentOfNode(self).view;
}

@end
#endif

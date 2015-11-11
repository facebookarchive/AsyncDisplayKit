//
//  ASVisualEffectNode.m
//  AsyncDisplayKit
//
//  Created by Samuel Hsiung on 11/11/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "ASVisualEffectNode.h"

@implementation ASVisualEffectNode

- (instancetype)initWithEffect:(UIVisualEffect*)visualEffect
{
  if (self = [super initWithViewBlock:^UIView *{
    _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:visualEffect];
    _visualEffectView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    return _visualEffectView;
  }]) {
    self.userInteractionEnabled = NO;
  }
  return self;
}

+ (instancetype)blurNodeWithEffect:(UIBlurEffectStyle)effectStyle
{
  UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:effectStyle];
  return [[self alloc] initWithEffect:blurEffect];
}

@end

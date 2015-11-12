/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASVisualEffectNode.h"

@implementation ASVisualEffectNode

- (instancetype)initWithEffect:(UIVisualEffect*)visualEffect
{
  return [self initWithViewBlock:^UIView *{
    _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:visualEffect];
    _visualEffectView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    return _visualEffectView;
  }];
}

+ (instancetype)blurNodeWithEffect:(UIBlurEffectStyle)effectStyle
{
  UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:effectStyle];
  return [[self alloc] initWithEffect:blurEffect];
}

@end

//
//  WindowWithStatusBarUnderlay.m
//  AsyncDisplayKit
//
//  Created by Erekle on 5/15/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "WindowWithStatusBarUnderlay.h"
#import "Utilities.h"

@implementation WindowWithStatusBarUnderlay
{
  UIView *_statusBarOpaqueUnderlayView;
}

-(instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    _statusBarOpaqueUnderlayView                 = [[UIView alloc] init];
    _statusBarOpaqueUnderlayView.backgroundColor = [UIColor lighOrangeColor];
    [self addSubview:_statusBarOpaqueUnderlayView];
  }
  return self;
}

-(void)layoutSubviews
{
  [super layoutSubviews];

  [self bringSubviewToFront:_statusBarOpaqueUnderlayView];

  CGRect statusBarFrame              = CGRectZero;
  statusBarFrame.size.width          = [[UIScreen mainScreen] bounds].size.width;
  statusBarFrame.size.height         = [[UIApplication sharedApplication] statusBarFrame].size.height;
  _statusBarOpaqueUnderlayView.frame = statusBarFrame;
}
@end

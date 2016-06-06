//
//  WindowWithStatusBarUnderlay.m
//  Sample
//
//  Created by Erekle on 5/15/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

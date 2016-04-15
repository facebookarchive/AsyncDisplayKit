//
//  WindowWithStatusBarUnderlay.m
//  Sample
//
//  Created by Hannah Troisi on 4/10/16.
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
    _statusBarOpaqueUnderlayView.backgroundColor = [UIColor darkBlueColor];
    [self addSubview:_statusBarOpaqueUnderlayView];
  }
  return self;
}

-(void)layoutSubviews
{
  [super layoutSubviews];
  
  [self bringSubviewToFront:_statusBarOpaqueUnderlayView];
  
  _statusBarOpaqueUnderlayView.frame = CGRectMake(0,
                                                  0,
                                                  [[UIScreen mainScreen] bounds].size.width,
                                                  [[UIApplication sharedApplication] statusBarFrame].size.height);
}

@end

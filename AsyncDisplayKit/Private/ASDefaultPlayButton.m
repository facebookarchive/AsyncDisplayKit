//
//  ASDefaultPlayButton.m
//  AsyncDisplayKit
//
//  Created by Luke Parham on 1/27/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDefaultPlayButton.h"
#import "_ASDisplayLayer.h"

@implementation ASDefaultPlayButton

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  self.opaque = NO;
  
  return self;
}

+ (void)drawRect:(CGRect)bounds withParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing
{
  CGFloat originX = bounds.size.width/4;
  CGRect buttonBounds = CGRectMake(originX, bounds.size.height/4, bounds.size.width/2, bounds.size.height/2);
  CGFloat widthHeight = buttonBounds.size.width;

  //When the video isn't a square, the lower bound should be used to figure out the circle size
  if (bounds.size.width < bounds.size.height) {
    widthHeight = bounds.size.width/2;
    originX = (bounds.size.width - widthHeight)/2;
    buttonBounds = CGRectMake(originX, (bounds.size.height - widthHeight)/2, widthHeight, widthHeight);
  }
  if (bounds.size.width > bounds.size.height) {
    widthHeight = bounds.size.height/2;
    originX = (bounds.size.width - widthHeight)/2;
    buttonBounds = CGRectMake(originX, (bounds.size.height - widthHeight)/2, widthHeight, widthHeight);
  }

  CGContextRef context = UIGraphicsGetCurrentContext();

  // Circle Drawing
  UIBezierPath *ovalPath = [UIBezierPath bezierPathWithOvalInRect: buttonBounds];
  [[UIColor colorWithWhite:0.0 alpha:0.5] setFill];
  [ovalPath fill];
  
  // Triangle Drawing
  CGContextSaveGState(context);
  
  UIBezierPath *trianglePath = [UIBezierPath bezierPath];
  [trianglePath moveToPoint:CGPointMake(originX + widthHeight/3, bounds.size.height/4 + (bounds.size.height/2)/4)];
  [trianglePath addLineToPoint:CGPointMake(originX + widthHeight/3, bounds.size.height - bounds.size.height/4 - (bounds.size.height/2)/4)];
  [trianglePath addLineToPoint:CGPointMake(bounds.size.width - originX - widthHeight/4, bounds.size.height/2)];

  [trianglePath closePath];
  [[UIColor colorWithWhite:0.9 alpha:0.9] setFill];
  [trianglePath fill];
  
  CGContextRestoreGState(context);
}

@end

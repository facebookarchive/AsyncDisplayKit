//
//  ASDefaultPlayButton.m
//  AsyncDisplayKit
//
//  Created by Luke Parham on 1/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASDefaultPlayButton.h"

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
  CGRect buttonBounds;
  buttonBounds = CGRectMake(bounds.size.width/4, bounds.size.height/4, bounds.size.width/2, bounds.size.height/2);

  if (bounds.size.width < bounds.size.height) {
    //then use the width to determine the rect size then calculate the origin x y
    buttonBounds = CGRectMake(bounds.size.width/4, bounds.size.width/4, bounds.size.width/2, bounds.size.width/2);
  }
  if (bounds.size.width > bounds.size.height) {
    //use the height
    buttonBounds = CGRectMake(bounds.size.height/4, bounds.size.height/4, bounds.size.height/2, bounds.size.height/2);
  }
  if (bounds.size.width == bounds.size.height) {
    //square so easy
    buttonBounds = CGRectMake(bounds.size.width/4, bounds.size.height/4, bounds.size.width/2, bounds.size.height/2);
  }
  
  if (!isRasterizing) {
    [[UIColor clearColor] set];
    UIRectFill(bounds);
  }
  
  CGContextRef context = UIGraphicsGetCurrentContext();

  // Circle Drawing
  UIBezierPath *ovalPath = [UIBezierPath bezierPathWithOvalInRect: buttonBounds];
  [[UIColor colorWithWhite:0.0 alpha:0.5] setFill];
  [ovalPath stroke];
  [ovalPath fill];
  
  // Triangle Drawing
  CGContextSaveGState(context);
  
  CGFloat buttonWidth = buttonBounds.size.width;
  
  UIBezierPath *trianglePath = [UIBezierPath bezierPath];
  [trianglePath moveToPoint:CGPointMake(bounds.size.width/4 + buttonWidth/3, bounds.size.height/4 + (bounds.size.height/2)/4)];
  [trianglePath addLineToPoint:CGPointMake(bounds.size.width/4 + buttonWidth/3, bounds.size.height - bounds.size.height/4 - (bounds.size.height/2)/4)];
  [trianglePath addLineToPoint:CGPointMake(bounds.size.width - bounds.size.width/4 - buttonWidth/4, bounds.size.height/2)];

  [trianglePath closePath];
  [[UIColor colorWithWhite:0.9 alpha:0.9] setFill];
  [trianglePath fill];
  
  CGContextRestoreGState(context);
}

@end

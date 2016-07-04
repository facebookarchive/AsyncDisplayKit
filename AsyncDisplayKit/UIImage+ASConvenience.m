//
//  UIImage+ASConvenience.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 6/24/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "UIImage+ASConvenience.h"
#import <UIKit/UIKit.h>

@implementation UIImage (ASDKAdditions)




+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor
{
  return [self as_resizableRoundedImageWithCornerRadius:cornerRadius
                                            cornerColor:cornerColor
                                              fillColor:fillColor
                                            borderColor:nil
                                            borderWidth:1.0
                                         roundedCorners:UIRectCornerAllCorners
                                                  scale:0.0];
}

+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor
                                          borderColor:(UIColor *)borderColor
                                          borderWidth:(CGFloat)borderWidth
{
  return [self as_resizableRoundedImageWithCornerRadius:cornerRadius
                                            cornerColor:cornerColor
                                              fillColor:fillColor
                                            borderColor:borderColor
                                            borderWidth:borderWidth
                                         roundedCorners:UIRectCornerAllCorners
                                                  scale:0.0];
}

+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor
                                          borderColor:(UIColor *)borderColor
                                          borderWidth:(CGFloat)borderWidth
                                       roundedCorners:(UIRectCorner)roundedCorners
                                                scale:(CGFloat)scale
{
  static NSCache *__pathCache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __pathCache = [[NSCache alloc] init];
    // UIBezierPath objects are fairly small and these are equally sized. 20 should be plenty for many different parameters.
    __pathCache.countLimit = 20;
  });
  
  // Treat clear background color as no background color
  if ([cornerColor isEqual:[UIColor clearColor]]) {
    cornerColor = nil;
  }
  
  CGFloat dimension = (cornerRadius * 2) + 1;
  CGRect bounds = CGRectMake(0, 0, dimension, dimension);
  
  // This is a hack to make one NSNumber key out of the corners and cornerRadius
  if (roundedCorners == UIRectCornerAllCorners) {
    // UIRectCornerAllCorners is ~0, but below is equivalent and we can pack it into half an NSUInteger
    roundedCorners = UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomLeft | UIRectCornerBottomRight;
  }
  // Left half of NSUInteger is roundedCorners, right half is cornerRadius
  UInt64 pathKeyNSUInteger = (UInt64)roundedCorners << sizeof(Float32) * 8;
  Float32 floatCornerRadius = cornerRadius;
  pathKeyNSUInteger |= (NSUInteger)floatCornerRadius;
  
  NSNumber *pathKey = [NSNumber numberWithUnsignedLongLong:pathKeyNSUInteger];
  
  UIBezierPath *path = nil;
  CGSize cornerRadii = CGSizeMake(cornerRadius, cornerRadius);
  
  @synchronized(__pathCache) {
    path = [__pathCache objectForKey:pathKey];
    if (!path) {
      path = [UIBezierPath bezierPathWithRoundedRect:bounds byRoundingCorners:roundedCorners cornerRadii:cornerRadii];
      [__pathCache setObject:path forKey:pathKey];
    }
  }
  
  // We should probably check if the background color has any alpha component but that
  // might be expensive due to needing to check mulitple color spaces.
  UIGraphicsBeginImageContextWithOptions(bounds.size, cornerColor != nil, scale);
  
  if (cornerColor) {
    [cornerColor setFill];
    // Copy "blend" mode is extra fast because it disregards any value currently in the buffer and overwrites directly.
    UIRectFillUsingBlendMode(bounds, kCGBlendModeCopy);
  }
  
  [fillColor setFill];
  [path fill];
  
  if (borderColor) {
    [borderColor setStroke];
    
    // Inset border fully inside filled path (not halfway on each side of path)
    CGRect strokeRect = CGRectInset(bounds, borderWidth / 2.0, borderWidth / 2.0);
    
    // It is rarer to have a stroke path, and our cache key only handles rounded rects for the exact-stretchable
    // size calculated by cornerRadius, so we won't bother caching this path.  Profiling validates this decision.
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:cornerRadius];
    [strokePath setLineWidth:borderWidth];
    [strokePath stroke];
  }
  
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIEdgeInsets capInsets = UIEdgeInsetsMake(cornerRadius, cornerRadius, cornerRadius, cornerRadius);
  result = [result resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
  
  return result;
}

@end
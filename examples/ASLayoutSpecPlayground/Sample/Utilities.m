//
//  Utilities.m
//  Flickrgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "Utilities.h"
#import <UIKit/UIKit.h>

#define StrokeRoundedImages 0

@implementation UIColor (Additions)

+ (UIColor *)darkBlueColor
{
  return [UIColor colorWithRed:18.0/255.0 green:86.0/255.0 blue:136.0/255.0 alpha:1.0];
}

+ (UIColor *)lightBlueColor
{
  return [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
}

+ (UIColor *)duskColor
{
  return [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
}

+ (UIColor *)customOrangeColor
{
  return [UIColor colorWithRed:40/255.0 green:43/255.0 blue:53/255.0 alpha:1.0];
}


@end

@implementation UIImage (Additions)

- (UIImage *)makeCircularImageWithSize:(CGSize)size
{
  // make a CGRect with the image's size
  CGRect circleRect = (CGRect) {CGPointZero, size};
  
  // begin the image context since we're not in a drawRect:
  UIGraphicsBeginImageContextWithOptions(circleRect.size, NO, 0);
  
  // create a UIBezierPath circle
  UIBezierPath *circle = [UIBezierPath bezierPathWithRoundedRect:circleRect cornerRadius:circleRect.size.width/2];
  
  // clip to the circle
  [circle addClip];
  
  // draw the image in the circleRect *AFTER* the context is clipped
  [self drawInRect:circleRect];
  
  // create a border (for white background pictures)
#if StrokeRoundedImages
  circle.lineWidth = 1;
  [[UIColor darkGrayColor] set];
  [circle stroke];
#endif
  
  // get an image from the image context
  UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
  
  // end the image context since we're not in a drawRect:
  UIGraphicsEndImageContext();
  
  return roundedImage;
}

@end

@implementation NSAttributedString (Additions)

+ (NSAttributedString *)attributedStringWithString:(NSString *)string fontSize:(CGFloat)size
                                             color:(nullable UIColor *)color firstWordColor:(nullable UIColor *)firstWordColor
{
  NSDictionary *attributes                    = @{NSForegroundColorAttributeName: color ? : [UIColor blackColor],
                                                  NSFontAttributeName: [UIFont systemFontOfSize:size]};
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string];
  [attributedString addAttributes:attributes range:NSMakeRange(0, string.length)];
  
  if (firstWordColor) {
    NSRange firstSpaceRange = [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange firstWordRange  = NSMakeRange(0, firstSpaceRange.location);
    [attributedString addAttribute:NSForegroundColorAttributeName value:firstWordColor range:firstWordRange];
  }
  
  return attributedString;
}

@end

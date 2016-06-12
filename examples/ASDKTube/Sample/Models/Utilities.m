//
//  Utilities.m
//  Sample
//
//  Created by Hannah Troisi on 3/9/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "Utilities.h"

#define StrokeRoundedImages 0

@implementation UIColor (Additions)

+ (UIColor *)lighOrangeColor
{
  return [UIColor colorWithRed:1 green:0.506 blue:0.384 alpha:1];
}

+ (UIColor *)darkBlueColor
{
  return [UIColor colorWithRed:70.0/255.0 green:102.0/255.0 blue:118.0/255.0 alpha:1.0];
}

+ (UIColor *)lightBlueColor
{
  return [UIColor colorWithRed:70.0/255.0 green:165.0/255.0 blue:196.0/255.0 alpha:1.0];
}

@end

@implementation UIImage (Additions)

+ (UIImage *)followingButtonStretchableImageForCornerRadius:(CGFloat)cornerRadius following:(BOOL)followingEnabled
{
  CGSize unstretchedSize  = CGSizeMake(2 * cornerRadius + 1, 2 * cornerRadius + 1);
  CGRect rect             = (CGRect) {CGPointZero, unstretchedSize};
  UIBezierPath *path      = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius];
  
  // create a graphics context for the following status button
  UIGraphicsBeginImageContextWithOptions(unstretchedSize, NO, 0);
  
  [path addClip];
  
  if (followingEnabled) {
    
    [[UIColor whiteColor] setFill];
    [path fill];
    
    path.lineWidth = 3;
    [[UIColor lightBlueColor] setStroke];
    [path stroke];
    
  } else {
    
    [[UIColor lightBlueColor] setFill];
    [path fill];
  }
  
  UIImage *followingBtnImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIImage *followingBtnImageStretchable = [followingBtnImage stretchableImageWithLeftCapWidth:cornerRadius
                                                                                 topCapHeight:cornerRadius];
  return followingBtnImageStretchable;
}

+ (void)downloadImageForURL:(NSURL *)url completion:(void (^)(UIImage *))block
{
  static NSCache *simpleImageCache = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    simpleImageCache = [[NSCache alloc] init];
    simpleImageCache.countLimit = 10;
  });
  
  if (!block) {
    return;
  }
  
  // check if image is cached
  UIImage *image = [simpleImageCache objectForKey:url];
  if (image) {
    dispatch_async(dispatch_get_main_queue(), ^{
      block(image);
    });
  } else {
    // else download image
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
      if (data) {
        UIImage *image = [UIImage imageWithData:data];
        dispatch_async(dispatch_get_main_queue(), ^{
          block(image);
        });
      }
    }];
    [task resume];
  }
}

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

@implementation NSString (Additions)

// Returns a user-visible date time string that corresponds to the
// specified RFC 3339 date time string. Note that this does not handle
// all possible RFC 3339 date time strings, just one of the most common
// styles.
+ (NSDate *)userVisibleDateTimeStringForRFC3339DateTimeString:(NSString *)rfc3339DateTimeString
{
  NSDateFormatter *   rfc3339DateFormatter;
  NSLocale *          enUSPOSIXLocale;
  
  // Convert the RFC 3339 date time string to an NSDate.
  
  rfc3339DateFormatter = [[NSDateFormatter alloc] init];
  
  enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  
  [rfc3339DateFormatter setLocale:enUSPOSIXLocale];
  [rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZ'"];
  [rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  
  return [rfc3339DateFormatter dateFromString:rfc3339DateTimeString];
}

+ (NSString *)elapsedTimeStringSinceDate:(NSString *)uploadDateString
{
  // early return if no post date string
  if (!uploadDateString)
  {
    return @"NO POST DATE";
  }
  
  NSDate *postDate = [self userVisibleDateTimeStringForRFC3339DateTimeString:uploadDateString];
  
  if (!postDate) {
    return @"DATE CONVERSION ERROR";
  }
  
  NSDate *currentDate         = [NSDate date];
  
  NSCalendar *calendar        = [NSCalendar currentCalendar];
  
  NSUInteger seconds = [[calendar components:NSCalendarUnitSecond fromDate:postDate toDate:currentDate options:0] second];
  NSUInteger minutes = [[calendar components:NSCalendarUnitMinute fromDate:postDate toDate:currentDate options:0] minute];
  NSUInteger hours   = [[calendar components:NSCalendarUnitHour   fromDate:postDate toDate:currentDate options:0] hour];
  NSUInteger days    = [[calendar components:NSCalendarUnitDay    fromDate:postDate toDate:currentDate options:0] day];
  
  NSString *elapsedTime;
  
  if (days > 7) {
    elapsedTime = [NSString stringWithFormat:@"%luw", (long)ceil(days/7.0)];
  } else if (days > 0) {
    elapsedTime = [NSString stringWithFormat:@"%lud", (long)days];
  } else if (hours > 0) {
    elapsedTime = [NSString stringWithFormat:@"%luh", (long)hours];
  } else if (minutes > 0) {
    elapsedTime = [NSString stringWithFormat:@"%lum", (long)minutes];
  } else if (seconds > 0) {
    elapsedTime = [NSString stringWithFormat:@"%lus", (long)seconds];
  } else if (seconds == 0) {
    elapsedTime = @"1s";
  } else {
    elapsedTime = @"ERROR";
  }
  
  return elapsedTime;
}

@end

@implementation NSAttributedString (Additions)

+ (NSAttributedString *)attributedStringWithString:(NSString *)string fontSize:(CGFloat)size
                                             color:(nullable UIColor *)color firstWordColor:(nullable UIColor *)firstWordColor
{
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
  
  if (string) {
    NSDictionary *attributes                    = @{NSForegroundColorAttributeName: color ? : [UIColor blackColor],
                                                    NSFontAttributeName: [UIFont systemFontOfSize:size]};
    attributedString = [[NSMutableAttributedString alloc] initWithString:string];
    [attributedString addAttributes:attributes range:NSMakeRange(0, string.length)];
    
    if (firstWordColor) {
      NSRange firstSpaceRange = [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
      NSRange firstWordRange  = NSMakeRange(0, firstSpaceRange.location);
      [attributedString addAttribute:NSForegroundColorAttributeName value:firstWordColor range:firstWordRange];
    }
  }
  
  return attributedString;
}

@end

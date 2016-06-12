//
//  RandomCoreGraphicsNode.m
//  Sample
//
//  Created by Scott Goodson on 9/5/15.
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

#import "RandomCoreGraphicsNode.h"
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@implementation RandomCoreGraphicsNode

+ (UIColor *)randomColor
{
  CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
  CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
  CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
  return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

+ (void)drawRect:(CGRect)bounds withParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing
{
  CGFloat locations[3];
  NSMutableArray *colors = [NSMutableArray arrayWithCapacity:3];
  [colors addObject:(id)[[RandomCoreGraphicsNode randomColor] CGColor]];
  locations[0] = 0.0;
  [colors addObject:(id)[[RandomCoreGraphicsNode randomColor] CGColor]];
  locations[1] = 1.0;
  [colors addObject:(id)[[RandomCoreGraphicsNode randomColor] CGColor]];
  locations[2] = ( arc4random() % 256 / 256.0 );

  
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)colors, locations);
  
  CGGradientDrawingOptions drawingOptions;
  CGContextDrawLinearGradient(ctx, gradient, CGPointZero, CGPointMake(bounds.size.width, bounds.size.height), drawingOptions);
  
  CGColorSpaceRelease(colorSpace);
}

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  return [self description];
}

- (NSDictionary *)textStyle
{
  UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:36.0f];
  
  NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  style.paragraphSpacing = 0.5 * font.lineHeight;
  style.hyphenationFactor = 1.0;
  
  return @{ NSFontAttributeName: font,
            NSParagraphStyleAttributeName: style };
}

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _textNode = [[ASTextNode alloc] init];
  _textNode.placeholderEnabled = NO;
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:@"Hello, ASDK!"
                                                               attributes:[self textStyle]];
  [self addSubnode:_textNode];
  
  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  [_textNode measure:constrainedSize];
  return CGSizeMake(constrainedSize.width, 100);
}

- (void)layout
{
  CGSize boundsSize = self.bounds.size;
  CGSize textSize = _textNode.calculatedSize;
  CGRect textRect = CGRectMake(roundf((boundsSize.width - textSize.width) / 2.0),
                               roundf((boundsSize.height - textSize.height) / 2.0),
                               textSize.width,
                               textSize.height);
  _textNode.frame = textRect;
}

@end

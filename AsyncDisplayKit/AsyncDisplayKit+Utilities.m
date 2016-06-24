//
//  AsyncDisplayKit+Utilties.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 6/24/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "AsyncDisplayKit+Utilities.h"

@implementation UIImage (ASDKAdditions)

+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                             scale:(CGFloat)scale
                                   backgroundColor:(UIColor *)backgroundColor
                                         fillColor:(UIColor *)fillColor
                                       borderColor:(UIColor *)borderColor
{
    return [[self class] as_resizableRoundedImageWithCornerRadius:cornerRadius scale:scale backgroundColor:backgroundColor fillColor:fillColor borderColor:borderColor roundedCorner:UIRectCornerAllCorners];
}

+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                             scale:(CGFloat)scale
                                   backgroundColor:(UIColor *)backgroundColor
                                         fillColor:(UIColor *)fillColor
                                       borderColor:(UIColor *)borderColor
                                     roundedCorner:(UIRectCorner)roundedCorners
{
    static NSCache *__pathCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __pathCache = [[NSCache alloc] init];
    });

    CGFloat dimension = (cornerRadius * 2) + 1;
    CGRect bounds = CGRectMake(0, 0, dimension, dimension);

    // This is a hack to make one NSNumber key out of the corners and cornerRadius
    if (roundedCorners == UIRectCornerAllCorners) {
        // UIRectCornerAllCorners is ~0, but below is equivalent and we can pack it into half an NSUInteger
        roundedCorners = UIRectCornerTopLeft | UIRectCornerTopRight | UIRectCornerBottomLeft | UIRectCornerBottomRight;
    }
    //Left half of NSUInteger is roundedCorners, right half is cornerRadius
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

    UIGraphicsBeginImageContextWithOptions(bounds.size, backgroundColor != nil, scale);

    if (backgroundColor) {
        [backgroundColor setFill];
        // Copy "blend" mode is extra fast because it disregards any value currently in the buffer and overwrites directly.
        UIRectFillUsingBlendMode(bounds, kCGBlendModeCopy);
    }

    [fillColor setFill];
    [path fill];

    if (borderColor) {
        [borderColor setStroke];

        CGFloat lineWidth = 1.0 / scale;
        CGRect strokeRect = CGRectInset(bounds, lineWidth / 2.0, lineWidth / 2.0);

        // It is rarer to have a stroke path, and our cache key only handles rounded rects for the exact-stretchable
        // size calculated by cornerRadius, so we won't bother caching this path.  Profiling validates this decision.
        UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:cornerRadius];
        [strokePath setLineWidth:lineWidth];
        [strokePath stroke];
    }

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIEdgeInsets capInsets = UIEdgeInsetsMake(cornerRadius, cornerRadius, cornerRadius, cornerRadius);
    result = [result resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];

    return result;
}

@end
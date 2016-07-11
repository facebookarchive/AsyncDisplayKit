//
//  UIImage+ASConvenience.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 6/24/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIImage.h>
#import <UIKit/UIBezierPath.h>

// High-performance flat-colored, rounded-corner resizable images
//
// For "Baked-in Opaque" corners, set cornerColor equal to the color behind the rounded image object, e.g. the background color.
// For "Baked-in Alpha" corners, set cornerColor = [UIColor clearColor]
//
// See http://asyncdisplaykit.org/docs/corner-rounding.html for an explanation.

@interface UIImage (ASDKAdditions)

/**
 * This generates a flat-color, rounded-corner resizeable image
 *
 * @param cornerRadius The radius of the rounded-corner
 * @param cornerColor  The fill color of the corners (For Alpha corners use clearColor)
 * @param fillColor    The fill color of the rounded-corner image
 */
+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor;

/**
 * This generates a flat-color, rounded-corner resizeable image with a border
 *
 * @param cornerRadius The radius of the rounded-corner
 * @param cornerColor  The fill color of the corners (For Alpha corners use clearColor)
 * @param fillColor    The fill color of the rounded-corner image
 * @param borderColor  The border color. Set to nil for no border.
 * @param borderWidth  The border width. Dummy value if borderColor = nil.
 */
+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor
                                          borderColor:(UIColor *)borderColor
                                          borderWidth:(CGFloat)borderWidth;

/**
 * This generates a flat-color, rounded-corner resizeable image with a border
 *
 * @param cornerRadius    The radius of the rounded-corner
 * @param cornerColor     The fill color of the corners (For Alpha corners use clearColor)
 * @param fillColor       The fill color of the rounded-corner image
 * @param borderColor     The border color. Set to nil for no border.
 * @param borderWidth     The border width. Dummy value if borderColor = nil.
 * @param roundedCorners  Select individual or multiple corners to round. Set to UIRectCornerAllCorners to round all 4 corners.
 * @param scale           The number of pixels per point. Provide 0.0 to use the screen scale.
 */
+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius
                                          cornerColor:(UIColor *)cornerColor
                                            fillColor:(UIColor *)fillColor
                                          borderColor:(UIColor *)borderColor
                                          borderWidth:(CGFloat)borderWidth
                                       roundedCorners:(UIRectCorner)roundedCorners
                                                scale:(CGFloat)scale;

@end


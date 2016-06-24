//
//  AsyncDisplayKit+Utilties.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 6/24/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

@interface UIImage (ASDKAdditions)

// A performance-focused flat color stretchable-image
+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius scale:(CGFloat)scale backgroundColor:(UIColor *)backgroundColor fillColor:(UIColor *)fillColor borderColor:(UIColor *)borderColor;

// A performance-focused flat color stretchable-image with rounded corners
+ (UIImage *)as_resizableRoundedImageWithCornerRadius:(CGFloat)cornerRadius scale:(CGFloat)scale backgroundColor:(UIColor *)backgroundColor fillColor:(UIColor *)fillColor borderColor:(UIColor *)borderColor roundedCorner:(UIRectCorner)corners;

@end


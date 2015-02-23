/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


/**
 * @abstract Negates/inverts a UIEdgeInsets.
 * @discussion Useful for undoing the application of shadow padding to a frame/bounds CGRect.
 *   For example,
 *   CGRect insetRect = UIEdgeInsetsRect(originalRect, insets);
 *   CGRect equalToOriginalRect = UIEdgeInsetsRect(originalRect, ASDNEdgeInsetsInvert(insets));
 */
static inline UIEdgeInsets ASDNEdgeInsetsInvert(UIEdgeInsets insets)
{
  UIEdgeInsets invertedInsets = UIEdgeInsetsMake(-insets.top, -insets.left, -insets.bottom, -insets.right);
  return invertedInsets;
}

/**
 * @abstract an immutable class for calculating shadow padding drawing a shadowed background for text
 */
@interface ASTextNodeShadower : NSObject

- (instancetype)initWithShadowOffset:(CGSize)shadowOffset
                         shadowColor:(CGColorRef)shadowColor
                       shadowOpacity:(CGFloat)shadowOpacity
                        shadowRadius:(CGFloat)shadowRadius;

/**
  * @abstract The offset from the top-left corner at which the shadow starts.
  * @discussion A positive width will move the shadow to the right.
  *             A positive height will move the shadow downwards.
  */
@property (nonatomic, readonly, assign) CGSize shadowOffset;

//! CGColor in which the shadow is drawn
@property (nonatomic, readonly, assign) CGColorRef shadowColor;

//! Alpha of the shadow
@property (nonatomic, readonly, assign) CGFloat shadowOpacity;

//! Radius, in pixels
@property (nonatomic, readonly, assign) CGFloat shadowRadius;

/**
  * @abstract The edge insets which represent shadow padding
  * @discussion Each edge inset is less than or equal to zero.
  *
  * Example:
  *  CGRect boundsWithoutShadowPadding; // Large enough to fit text, not large enough to fit the shadow as well
  *  UIEdgeInsets shadowPadding = [shadower shadowPadding];
  *  CGRect boundsWithShadowPadding = UIEdgeInsetsRect(boundsWithoutShadowPadding, shadowPadding);
 */
- (UIEdgeInsets)shadowPadding;

/**
  * @abstract draws the shadow for text in the provided CGContext
  * @discussion Call within the text node's +drawRect method
  */
- (void)setShadowInContext:(CGContextRef)context;

@end

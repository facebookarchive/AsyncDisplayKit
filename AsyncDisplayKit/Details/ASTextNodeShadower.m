/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASTextNodeShadower.h"

@implementation ASTextNodeShadower {
  UIEdgeInsets _calculatedShadowPadding;
}

- (instancetype)initWithShadowOffset:(CGSize)shadowOffset
                         shadowColor:(CGColorRef)shadowColor
                       shadowOpacity:(CGFloat)shadowOpacity
                        shadowRadius:(CGFloat)shadowRadius
{
  if (self = [super init]) {
    _shadowOffset = shadowOffset;
    _shadowColor = CGColorRetain(shadowColor);
    _shadowOpacity = shadowOpacity;
    _shadowRadius = shadowRadius;
    _calculatedShadowPadding = UIEdgeInsetsMake(-INFINITY, -INFINITY, INFINITY, INFINITY);
  }
  return self;
}

- (void)dealloc
{
  CGColorRelease(_shadowColor);
}

/*
 * This method is duplicated here because it gets called frequently, and we were
 * wasting valuable time constructing a state object to ask it.
 */
- (BOOL)_shouldDrawShadow
{
  return _shadowOpacity != 0.0 && _shadowColor != NULL && (_shadowRadius != 0 || !CGSizeEqualToSize(_shadowOffset, CGSizeZero));
}

- (void)setShadowInContext:(CGContextRef)context
{
  if ([self _shouldDrawShadow]) {
    CGColorRef textShadowColor = CGColorRetain(_shadowColor);
    CGSize textShadowOffset = _shadowOffset;
    CGFloat textShadowOpacity = _shadowOpacity;
    CGFloat textShadowRadius = _shadowRadius;

    if (textShadowOpacity != 1.0) {
      CGFloat inherentAlpha = CGColorGetAlpha(textShadowColor);

      CGColorRef oldTextShadowColor = textShadowColor;
      textShadowColor = CGColorCreateCopyWithAlpha(textShadowColor, inherentAlpha * textShadowOpacity);
      CGColorRelease(oldTextShadowColor);
    }

    CGContextSetShadowWithColor(context, textShadowOffset, textShadowRadius, textShadowColor);

    CGColorRelease(textShadowColor);
  }
}


- (UIEdgeInsets)shadowPadding
{
  if (_calculatedShadowPadding.top == -INFINITY) {
    if (![self _shouldDrawShadow]) {
      return UIEdgeInsetsZero;
    }

    UIEdgeInsets shadowPadding = UIEdgeInsetsZero;

    // min values are expected to be negative for most typical shadowOffset and
    // blurRadius settings:
    shadowPadding.top = fminf(0.0f, _shadowOffset.height - _shadowRadius);
    shadowPadding.left = fminf(0.0f, _shadowOffset.width - _shadowRadius);

    shadowPadding.bottom = fminf(0.0f, -_shadowOffset.height - _shadowRadius);
    shadowPadding.right = fminf(0.0f, -_shadowOffset.width - _shadowRadius);

    _calculatedShadowPadding = shadowPadding;
  }

  return _calculatedShadowPadding;
}

@end

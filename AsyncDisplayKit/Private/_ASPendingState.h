/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import "UIView+ASConvenience.h"

/**

 Private header for ASDisplayNode.mm

 _ASPendingState is a proxy for a UIView that has yet to be created.
 In response to its setters, it sets an internal property and a flag that indicates that that property has been set.

 When you want to configure a view from this pending state information, just call -applyToView:
 */

@interface _ASPendingState : NSObject <ASDisplayNodeViewProperties, ASDisplayProperties> {
  @package

  UIViewAutoresizing autoresizingMask;
  unsigned int edgeAntialiasingMask;
  CGRect frame;   // Frame is only to be used for synchronous views wrapped by nodes (see setFrame:)
  CGRect bounds;
  CGColorRef backgroundColor;
  id contents;
  CGFloat alpha;
  CGFloat cornerRadius;
  UIViewContentMode contentMode;
  CGPoint anchorPoint;
  CGPoint position;
  CGFloat zPosition;
  CGFloat contentsScale;
  CATransform3D transform;
  CATransform3D sublayerTransform;
  CGColorRef shadowColor;
  CGFloat shadowOpacity;
  CGSize shadowOffset;
  CGFloat shadowRadius;
  CGFloat borderWidth;
  CGColorRef borderColor;
  UIColor *tintColor;
  BOOL opaque;
  BOOL allowsEdgeAntialiasing;
  BOOL autoresizesSubviews;
  BOOL needsDisplayOnBoundsChange;
  BOOL hidden;
  BOOL clipsToBounds;
  BOOL exclusiveTouch;
  BOOL userInteractionEnabled;
  BOOL asyncTransactionContainer;
  BOOL isAccessibilityElement;
  NSString *accessibilityLabel;
  NSString *accessibilityHint;
  NSString *accessibilityValue;
  UIAccessibilityTraits accessibilityTraits;
  CGRect accessibilityFrame;
  NSString *accessibilityLanguage;
  BOOL accessibilityElementsHidden;
  BOOL accessibilityViewIsModal;
  BOOL shouldGroupAccessibilityChildren;
  NSString *accessibilityIdentifier;
}

// Supports all of the properties included in the ASDisplayNodeViewProperties protocol

- (void)applyToView:(UIView *)view;
- (void)applyToLayer:(CALayer *)layer;

+ (_ASPendingState *)pendingViewStateFromLayer:(CALayer *)layer;
+ (_ASPendingState *)pendingViewStateFromView:(UIView *)view;

@end

/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>


/**
 These are the properties we support from CALayer (implemented in the pending state)
 */

@protocol ASDisplayProperties <NSObject>

@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) CGFloat zPosition;
@property (nonatomic, assign) CGPoint anchorPoint;
@property (nonatomic, retain) id contents;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat contentsScale;
@property (nonatomic, assign) CATransform3D transform;
@property (nonatomic, assign) CATransform3D sublayerTransform;
@property (nonatomic, assign) BOOL needsDisplayOnBoundsChange;
@property (nonatomic, retain) __attribute__((NSObject)) CGColorRef shadowColor;
@property (nonatomic, assign) CGFloat shadowOpacity;
@property (nonatomic, assign) CGSize shadowOffset;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign, getter = isOpaque) BOOL opaque;
@property (nonatomic, retain) __attribute__((NSObject)) CGColorRef borderColor;
@property (nonatomic, copy) NSString *asyncdisplaykit_name;
@property (nonatomic, retain) __attribute__((NSObject)) CGColorRef backgroundColor;
@property (nonatomic, assign) BOOL allowsEdgeAntialiasing;
@property (nonatomic, assign) unsigned int edgeAntialiasingMask;

- (void)setNeedsDisplay;
- (void)setNeedsLayout;

@end

/**
 These are all of the "good" properties of the UIView API that we support in pendingViewState or view of an ASDisplayNode.
 */
@protocol ASDisplayNodeViewProperties

@property (nonatomic, assign)                           BOOL clipsToBounds;
@property (nonatomic, getter=isHidden)                  BOOL hidden;
@property (nonatomic, assign)                           BOOL autoresizesSubviews;
@property (nonatomic, assign)                           UIViewAutoresizing autoresizingMask;
@property (nonatomic, retain)                           UIColor *tintColor;
@property (nonatomic, assign)                           CGFloat alpha;
@property (nonatomic, assign)                           CGRect bounds;
@property (nonatomic, assign)                           UIViewContentMode contentMode;
@property (nonatomic, assign, getter=isUserInteractionEnabled) BOOL userInteractionEnabled;
@property (nonatomic, assign, getter=isExclusiveTouch) BOOL exclusiveTouch;
@property (nonatomic, assign, getter=asyncdisplaykit_isAsyncTransactionContainer, setter = asyncdisplaykit_setAsyncTransactionContainer:) BOOL asyncdisplaykit_asyncTransactionContainer;

/**
 Following properties of the UIAccessibility informal protocol are supported as well.
 We don't declare them here, so _ASPendingState does not complain about them being not implemented,
 as they are already on NSObject

 @property (atomic, assign)           BOOL isAccessibilityElement;
 @property (atomic, copy)             NSString *accessibilityLabel;
 @property (atomic, copy)             NSString *accessibilityHint;
 @property (atomic, copy)             NSString *accessibilityValue;
 @property (atomic, assign)           UIAccessibilityTraits accessibilityTraits;
 @property (atomic, assign)           CGRect accessibilityFrame;
 @property (atomic, retain)           NSString *accessibilityLanguage;
 @property (atomic, assign)           BOOL accessibilityElementsHidden;
 @property (atomic, assign)           BOOL accessibilityViewIsModal;
 @property (atomic, assign)           BOOL shouldGroupAccessibilityChildren;
 */

// Accessibility identification support
@property (nonatomic, copy)          NSString *accessibilityIdentifier;

@end

@interface CALayer (ASDisplayNodeLayer)
@property (atomic, copy) NSString *asyncdisplaykit_name;
@end

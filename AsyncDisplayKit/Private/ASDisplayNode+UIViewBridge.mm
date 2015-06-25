/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "_ASCoreAnimationExtras.h"
#import "_ASPendingState.h"
#import "ASAssert.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeInternal.h"
#import "ASEqualityHelpers.h"

/**
 * The following macros are conveniences to help in the common tasks related to the bridging that ASDisplayNode does to UIView and CALayer.
 * In general, a property can either be:
 *   - Always sent to the layer or view's layer
 *       use _getFromLayer / _setToLayer
 *   - Bridged to the view if view-backed or the layer if layer-backed
 *       use _getFromViewOrLayer / _setToViewOrLayer / _messageToViewOrLayer
 *   - Only applicable if view-backed
 *       use _setToViewOnly / _getFromViewOnly
 *   - Has differing types on views and layers, or custom ASDisplayNode-specific behavior is desired
 *       manually implement
 *
 *  _bridge_prologue is defined to either take an appropriate lock or assert thread affinity. Add it at the beginning of any bridged methods.
 */

#define DISPLAYNODE_USE_LOCKS 1

#define __loaded (_layer != nil)

#if DISPLAYNODE_USE_LOCKS
#define _bridge_prologue ASDisplayNodeAssertThreadAffinity(self); ASDN::MutexLocker l(_propertyLock)
#else
#define _bridge_prologue ASDisplayNodeAssertThreadAffinity(self)
#endif


#define _getFromViewOrLayer(layerProperty, viewAndPendingViewStateProperty) __loaded ? \
  (_view ? _view.viewAndPendingViewStateProperty : _layer.layerProperty )\
 : self.pendingViewState.viewAndPendingViewStateProperty

#define _setToViewOrLayer(layerProperty, layerValueExpr, viewAndPendingViewStateProperty, viewAndPendingViewStateExpr) __loaded ? \
   (_view ? _view.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr) : _layer.layerProperty = (layerValueExpr))\
 : self.pendingViewState.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr)

#define _setToViewOnly(viewAndPendingViewStateProperty, viewAndPendingViewStateExpr) __loaded ? _view.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr) : self.pendingViewState.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr)

#define _getFromViewOnly(viewAndPendingViewStateProperty) __loaded ? _view.viewAndPendingViewStateProperty : self.pendingViewState.viewAndPendingViewStateProperty

#define _getFromLayer(layerProperty) __loaded ? _layer.layerProperty : self.pendingViewState.layerProperty

#define _setToLayer(layerProperty, layerValueExpr) __loaded ? _layer.layerProperty = (layerValueExpr) : self.pendingViewState.layerProperty = (layerValueExpr)

#define _messageToViewOrLayer(viewAndLayerSelector) __loaded ? (_view ? [_view viewAndLayerSelector] : [_layer viewAndLayerSelector]) : [self.pendingViewState viewAndLayerSelector]

#define _messageToLayer(layerSelector) __loaded ? [_layer layerSelector] : [self.pendingViewState layerSelector]

/**
 * This category implements certainly frequently-used properties and methods of UIView and CALayer so that ASDisplayNode clients can just call the view/layer methods on the node,
 * with minimal loss in performance.  Unlike UIView and CALayer methods, these can be called from a non-main thread until the view or layer is created.
 * This allows text sizing in -calculateSizeThatFits: (essentially a simplified layout) to happen off the main thread
 * without any CALayer or UIView actually existing while still being able to set and read properties from ASDisplayNode instances.
 */
@implementation ASDisplayNode (UIViewBridge)

- (CGFloat)alpha
{
  _bridge_prologue;
  return _getFromViewOrLayer(opacity, alpha);
}

- (void)setAlpha:(CGFloat)newAlpha
{
  _bridge_prologue;
  _setToViewOrLayer(opacity, newAlpha, alpha, newAlpha);
}

- (CGFloat)cornerRadius
{
  _bridge_prologue;
  return _getFromLayer(cornerRadius);
}

-(void)setCornerRadius:(CGFloat)newCornerRadius
{
  _bridge_prologue;
  _setToLayer(cornerRadius, newCornerRadius);
}

- (CGFloat)contentsScale
{
  _bridge_prologue;
  return _getFromLayer(contentsScale);
}

- (void)setContentsScale:(CGFloat)newContentsScale
{
  _bridge_prologue;
  _setToLayer(contentsScale, newContentsScale);
}

- (CGRect)bounds
{
  _bridge_prologue;
  return _getFromViewOrLayer(bounds, bounds);
}

- (void)setBounds:(CGRect)newBounds
{
  _bridge_prologue;
  _setToViewOrLayer(bounds, newBounds, bounds, newBounds);
}

- (CGRect)frame
{
  _bridge_prologue;

  // Frame is only defined when transform is identity.
#if DEBUG
  // Checking if the transform is identity is expensive, so disable when unnecessary. We have assertions on in Release, so DEBUG is the only way I know of.
  ASDisplayNodeAssert(CATransform3DIsIdentity(self.transform), @"Must be an identity transform");
#endif

  CGPoint position = self.position;
  CGRect bounds = self.bounds;
  CGPoint anchorPoint = self.anchorPoint;
  CGPoint origin = CGPointMake(position.x - bounds.size.width * anchorPoint.x,
                               position.y - bounds.size.height * anchorPoint.y);
  return CGRectMake(origin.x, origin.y, bounds.size.width, bounds.size.height);
}

- (void)setFrame:(CGRect)rect
{
  _bridge_prologue;

  // Frame is only defined when transform is identity because we explicitly diverge from CALayer behavior and define frame without transform
#if DEBUG
  // Checking if the transform is identity is expensive, so disable when unnecessary. We have assertions on in Release, so DEBUG is the only way I know of.
  ASDisplayNodeAssert(CATransform3DIsIdentity(self.transform), @"Must be an identity transform");
#endif

  BOOL useLayer = (_layer && ASDisplayNodeThreadIsMain());
  
  CGPoint origin      = (useLayer ? _layer.bounds.origin : self.bounds.origin);
  CGPoint anchorPoint = (useLayer ? _layer.anchorPoint   : self.anchorPoint);
  
  CGRect bounds       = (CGRect){ origin, rect.size };
  CGPoint position    = CGPointMake(rect.origin.x + rect.size.width * anchorPoint.x,
                                    rect.origin.y + rect.size.height * anchorPoint.y);
  
  if (useLayer) {
    _layer.bounds = bounds;
    _layer.position = position;
  } else {
    self.bounds = bounds;
    self.position = position;
  }
}

- (void)setNeedsDisplay
{
  ASDisplayNode *rasterizedContainerNode = [self __rasterizedContainerNode];
  if (rasterizedContainerNode) {
    [rasterizedContainerNode setNeedsDisplay];
  } else {
    [_layer setNeedsDisplay];
  }
}

- (void)setNeedsLayout
{
  _bridge_prologue;
  _messageToViewOrLayer(setNeedsLayout);
}

- (BOOL)isOpaque
{
  _bridge_prologue;
  return _getFromLayer(opaque);
}

- (void)setOpaque:(BOOL)newOpaque
{
  BOOL prevOpaque = self.opaque;

  _bridge_prologue;
  _setToLayer(opaque, newOpaque);

  if (prevOpaque != newOpaque) {
    [self setNeedsDisplay];
  }
}

- (BOOL)isUserInteractionEnabled
{
  _bridge_prologue;
  if (_flags.layerBacked) return NO;
  return _getFromViewOnly(userInteractionEnabled);
}

- (void)setUserInteractionEnabled:(BOOL)enabled
{
  _bridge_prologue;
  _setToViewOnly(userInteractionEnabled, enabled);
}

- (BOOL)isExclusiveTouch
{
  _bridge_prologue;
  return _getFromViewOnly(exclusiveTouch);
}

- (void)setExclusiveTouch:(BOOL)exclusiveTouch
{
  _bridge_prologue;
  _setToViewOnly(exclusiveTouch, exclusiveTouch);
}

- (BOOL)clipsToBounds
{
  _bridge_prologue;
  return _getFromViewOrLayer(masksToBounds, clipsToBounds);
}

- (void)setClipsToBounds:(BOOL)clips
{
  _bridge_prologue;
  _setToViewOrLayer(masksToBounds, clips, clipsToBounds, clips);
}

- (CGPoint)anchorPoint
{
  _bridge_prologue;
  return _getFromLayer(anchorPoint);
}

- (void)setAnchorPoint:(CGPoint)newAnchorPoint
{
  _bridge_prologue;
  _setToLayer(anchorPoint, newAnchorPoint);
}

- (CGPoint)position
{
  _bridge_prologue;
  return _getFromLayer(position);
}

- (void)setPosition:(CGPoint)newPosition
{
  _bridge_prologue;
  _setToLayer(position, newPosition);
}

- (CGFloat)zPosition
{
  _bridge_prologue;
  return _getFromLayer(zPosition);
}

- (void)setZPosition:(CGFloat)newPosition
{
  _bridge_prologue;
  _setToLayer(zPosition, newPosition);
}

- (CATransform3D)transform
{
  _bridge_prologue;
  return _getFromLayer(transform);
}

- (void)setTransform:(CATransform3D)newTransform
{
  _bridge_prologue;
  _setToLayer(transform, newTransform);
}

- (CATransform3D)subnodeTransform
{
  _bridge_prologue;
  return _getFromLayer(sublayerTransform);
}

- (void)setSubnodeTransform:(CATransform3D)newSubnodeTransform
{
  _bridge_prologue;
  _setToLayer(sublayerTransform, newSubnodeTransform);
}

- (id)contents
{
  _bridge_prologue;
  return _getFromLayer(contents);
}

- (void)setContents:(id)newContents
{
  _bridge_prologue;
  _setToLayer(contents, newContents);
}

- (BOOL)isHidden
{
  _bridge_prologue;
  return _getFromViewOrLayer(hidden, hidden);
}

- (void)setHidden:(BOOL)flag
{
  _bridge_prologue;
  _setToViewOrLayer(hidden, flag, hidden, flag);
}

- (BOOL)needsDisplayOnBoundsChange
{
  _bridge_prologue;
  return _getFromLayer(needsDisplayOnBoundsChange);
}

- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag
{
  _bridge_prologue;
  _setToLayer(needsDisplayOnBoundsChange, flag);
}

- (BOOL)autoresizesSubviews
{
  _bridge_prologue;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  return _getFromViewOnly(autoresizesSubviews);
}

- (void)setAutoresizesSubviews:(BOOL)flag
{
  _bridge_prologue;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  _setToViewOnly(autoresizesSubviews, flag);
}

- (UIViewAutoresizing)autoresizingMask
{
  _bridge_prologue;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  return _getFromViewOnly(autoresizingMask);
}

- (void)setAutoresizingMask:(UIViewAutoresizing)mask
{
  _bridge_prologue;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  _setToViewOnly(autoresizingMask, mask);
}

- (UIViewContentMode)contentMode
{
  _bridge_prologue;
  if (__loaded) {
    return ASDisplayNodeUIContentModeFromCAContentsGravity(_layer.contentsGravity);
  } else {
    return self.pendingViewState.contentMode;
  }
}

- (void)setContentMode:(UIViewContentMode)mode
{
  _bridge_prologue;
  if (__loaded) {
    _layer.contentsGravity = ASDisplayNodeCAContentsGravityFromUIContentMode(mode);
  } else {
    self.pendingViewState.contentMode = mode;
  }
}

- (UIColor *)backgroundColor
{
  _bridge_prologue;
  return [UIColor colorWithCGColor:_getFromLayer(backgroundColor)];
}

- (void)setBackgroundColor:(UIColor *)newBackgroundColor
{
  UIColor *prevBackgroundColor = self.backgroundColor;

  _bridge_prologue;
  _setToLayer(backgroundColor, newBackgroundColor.CGColor);

  // Note: This check assumes that the colors are within the same color space.
  if (!ASObjectIsEqual(prevBackgroundColor, newBackgroundColor)) {
    [self setNeedsDisplay];
  }
}

- (UIColor *)tintColor
{
    _bridge_prologue;
    ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
    return _getFromViewOnly(tintColor);
}

- (void)setTintColor:(UIColor *)color
{
    _bridge_prologue;
    ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
    _setToViewOnly(tintColor, color);
}

- (void)tintColorDidChange
{
    // ignore this, allow subclasses to be notified
}

- (CGColorRef)shadowColor
{
  _bridge_prologue;
  return _getFromLayer(shadowColor);
}

- (void)setShadowColor:(CGColorRef)colorValue
{
  _bridge_prologue;
  _setToLayer(shadowColor, colorValue);
}

- (CGFloat)shadowOpacity
{
  _bridge_prologue;
  return _getFromLayer(shadowOpacity);
}

- (void)setShadowOpacity:(CGFloat)opacity
{
  _bridge_prologue;
  _setToLayer(shadowOpacity, opacity);
}

- (CGSize)shadowOffset
{
  _bridge_prologue;
  return _getFromLayer(shadowOffset);
}

- (void)setShadowOffset:(CGSize)offset
{
  _bridge_prologue;
  _setToLayer(shadowOffset, offset);
}

- (CGFloat)shadowRadius
{
  _bridge_prologue;
  return _getFromLayer(shadowRadius);
}

- (void)setShadowRadius:(CGFloat)radius
{
  _bridge_prologue;
  _setToLayer(shadowRadius, radius);
}

- (CGFloat)borderWidth
{
  _bridge_prologue;
  return _getFromLayer(borderWidth);
}

- (void)setBorderWidth:(CGFloat)width
{
  _bridge_prologue;
  _setToLayer(borderWidth, width);
}

- (CGColorRef)borderColor
{
  _bridge_prologue;
  return _getFromLayer(borderColor);
}

- (void)setBorderColor:(CGColorRef)colorValue
{
  _bridge_prologue;
  _setToLayer(borderColor, colorValue);
}

- (BOOL)allowsEdgeAntialiasing
{
  _bridge_prologue;
  return _getFromLayer(allowsEdgeAntialiasing);
}

- (void)setAllowsEdgeAntialiasing:(BOOL)allowsEdgeAntialiasing
{
  _bridge_prologue;
  _setToLayer(allowsEdgeAntialiasing, allowsEdgeAntialiasing);
}

- (unsigned int)edgeAntialiasingMask
{
  _bridge_prologue;
  return _getFromLayer(edgeAntialiasingMask);
}

- (void)setEdgeAntialiasingMask:(unsigned int)edgeAntialiasingMask
{
  _bridge_prologue;
  _setToLayer(edgeAntialiasingMask, edgeAntialiasingMask);
}

- (NSString *)name
{
  _bridge_prologue;
  return _getFromLayer(asyncdisplaykit_name);
}

- (void)setName:(NSString *)name
{
  _bridge_prologue;
  _setToLayer(asyncdisplaykit_name, name);
}

- (BOOL)isAccessibilityElement
{
  _bridge_prologue;
  return _getFromViewOnly(isAccessibilityElement);
}

- (void)setIsAccessibilityElement:(BOOL)isAccessibilityElement
{
  _bridge_prologue;
  _setToViewOnly(isAccessibilityElement, isAccessibilityElement);
}

- (NSString *)accessibilityLabel
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityLabel);
}

- (void)setAccessibilityLabel:(NSString *)accessibilityLabel
{
  _bridge_prologue;
  _setToViewOnly(accessibilityLabel, accessibilityLabel);
}

- (NSString *)accessibilityHint
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityHint);
}

- (void)setAccessibilityHint:(NSString *)accessibilityHint
{
  _bridge_prologue;
  _setToViewOnly(accessibilityHint, accessibilityHint);
}

- (NSString *)accessibilityValue
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityValue);
}

- (void)setAccessibilityValue:(NSString *)accessibilityValue
{
  _bridge_prologue;
  _setToViewOnly(accessibilityValue, accessibilityValue);
}

- (UIAccessibilityTraits)accessibilityTraits
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityTraits);
}

- (void)setAccessibilityTraits:(UIAccessibilityTraits)accessibilityTraits
{
  _bridge_prologue;
  _setToViewOnly(accessibilityTraits, accessibilityTraits);
}

- (CGRect)accessibilityFrame
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityFrame);
}

- (void)setAccessibilityFrame:(CGRect)accessibilityFrame
{
  _bridge_prologue;
  _setToViewOnly(accessibilityFrame, accessibilityFrame);
}

- (NSString *)accessibilityLanguage
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityLanguage);
}

- (void)setAccessibilityLanguage:(NSString *)accessibilityLanguage
{
  _bridge_prologue;
  _setToViewOnly(accessibilityLanguage, accessibilityLanguage);
}

- (BOOL)accessibilityElementsHidden
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityElementsHidden);
}

- (void)setAccessibilityElementsHidden:(BOOL)accessibilityElementsHidden
{
  _bridge_prologue;
  _setToViewOnly(accessibilityElementsHidden, accessibilityElementsHidden);
}

- (BOOL)accessibilityViewIsModal
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityViewIsModal);
}

- (void)setAccessibilityViewIsModal:(BOOL)accessibilityViewIsModal
{
  _bridge_prologue;
  _setToViewOnly(accessibilityViewIsModal, accessibilityViewIsModal);
}

- (BOOL)shouldGroupAccessibilityChildren
{
  _bridge_prologue;
  return _getFromViewOnly(shouldGroupAccessibilityChildren);
}

- (void)setShouldGroupAccessibilityChildren:(BOOL)shouldGroupAccessibilityChildren
{
  _bridge_prologue;
  _setToViewOnly(shouldGroupAccessibilityChildren, shouldGroupAccessibilityChildren);
}

- (NSString *)accessibilityIdentifier
{
  _bridge_prologue;
  return _getFromViewOnly(accessibilityIdentifier);
}

- (void)setAccessibilityIdentifier:(NSString *)accessibilityIdentifier
{
  _bridge_prologue;
  _setToViewOnly(accessibilityIdentifier, accessibilityIdentifier);
}

@end


@implementation ASDisplayNode (ASAsyncTransactionContainer)

- (BOOL)asyncdisplaykit_isAsyncTransactionContainer
{
  _bridge_prologue;
  return _getFromViewOrLayer(asyncdisplaykit_isAsyncTransactionContainer, asyncdisplaykit_isAsyncTransactionContainer);
}

- (void)asyncdisplaykit_setAsyncTransactionContainer:(BOOL)asyncTransactionContainer
{
  _bridge_prologue;
  _setToViewOrLayer(asyncdisplaykit_asyncTransactionContainer, asyncTransactionContainer, asyncdisplaykit_asyncTransactionContainer, asyncTransactionContainer);
}

- (ASAsyncTransactionContainerState)asyncdisplaykit_asyncTransactionContainerState
{
  ASDisplayNodeAssertMainThread();
  return [_layer asyncdisplaykit_asyncTransactionContainerState];
}

- (void)asyncdisplaykit_cancelAsyncTransactions
{
  ASDisplayNodeAssertMainThread();
  [_layer asyncdisplaykit_cancelAsyncTransactions];
}

- (void)asyncdisplaykit_asyncTransactionContainerStateDidChange
{
}

@end

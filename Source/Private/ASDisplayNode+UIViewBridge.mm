//
//  ASDisplayNode+UIViewBridge.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASPendingState.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASPendingStateController.h>

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
 *  _bridge_prologue_write is defined to take the node's property lock. Add it at the beginning of any bridged property setters.
 *  _bridge_prologue_read is defined to take the node's property lock and enforce thread affinity. Add it at the beginning of any bridged property getters.
 */

#define DISPLAYNODE_USE_LOCKS 1

#define __loaded(node) (node->_view != nil || (node->_layer != nil && node->_flags.layerBacked))

#if DISPLAYNODE_USE_LOCKS
#define _bridge_prologue_read ASDN::MutexLocker l(__instanceLock__); ASDisplayNodeAssertThreadAffinity(self)
#define _bridge_prologue_write ASDN::MutexLocker l(__instanceLock__)
#else
#define _bridge_prologue_read ASDisplayNodeAssertThreadAffinity(self)
#define _bridge_prologue_write
#endif

/// Returns YES if the property set should be applied to view/layer immediately.
/// Side Effect: Registers the node with the shared ASPendingStateController if
/// the property cannot be immediately applied and the node does not already have pending changes.
/// This function must be called with the node's lock already held (after _bridge_prologue_write).
ASDISPLAYNODE_INLINE BOOL ASDisplayNodeShouldApplyBridgedWriteToView(ASDisplayNode *node) {
  BOOL loaded = __loaded(node);
  if (ASDisplayNodeThreadIsMain()) {
    return loaded;
  } else {
    if (loaded && !ASDisplayNodeGetPendingState(node).hasChanges) {
      [[ASPendingStateController sharedInstance] registerNode:node];
    }
    return NO;
  }
};

#define _getFromViewOrLayer(layerProperty, viewAndPendingViewStateProperty) __loaded(self) ? \
  (_view ? _view.viewAndPendingViewStateProperty : _layer.layerProperty )\
 : ASDisplayNodeGetPendingState(self).viewAndPendingViewStateProperty

#define _setToViewOrLayer(layerProperty, layerValueExpr, viewAndPendingViewStateProperty, viewAndPendingViewStateExpr) BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self); \
  if (shouldApply) { (_view ? _view.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr) : _layer.layerProperty = (layerValueExpr)); } else { ASDisplayNodeGetPendingState(self).viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr); }

#define _setToViewOnly(viewAndPendingViewStateProperty, viewAndPendingViewStateExpr) BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self); \
if (shouldApply) { _view.viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr); } else { ASDisplayNodeGetPendingState(self).viewAndPendingViewStateProperty = (viewAndPendingViewStateExpr); }

#define _getFromViewOnly(viewAndPendingViewStateProperty) __loaded(self) ? _view.viewAndPendingViewStateProperty : ASDisplayNodeGetPendingState(self).viewAndPendingViewStateProperty

#define _getFromLayer(layerProperty) __loaded(self) ? _layer.layerProperty : ASDisplayNodeGetPendingState(self).layerProperty

#define _setToLayer(layerProperty, layerValueExpr) BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self); \
if (shouldApply) { _layer.layerProperty = (layerValueExpr); } else { ASDisplayNodeGetPendingState(self).layerProperty = (layerValueExpr); }

/**
 * This category implements certain frequently-used properties and methods of UIView and CALayer so that ASDisplayNode clients can just call the view/layer methods on the node,
 * with minimal loss in performance.  Unlike UIView and CALayer methods, these can be called from a non-main thread until the view or layer is created.
 * This allows text sizing in -calculateSizeThatFits: (essentially a simplified layout) to happen off the main thread
 * without any CALayer or UIView actually existing while still being able to set and read properties from ASDisplayNode instances.
 */
@implementation ASDisplayNode (UIViewBridge)

- (BOOL)canBecomeFirstResponder
{
  return NO;
}

- (BOOL)canResignFirstResponder
{
  return YES;
}

#if TARGET_OS_TV
// Focus Engine
- (BOOL)canBecomeFocused
{
  return NO;
}

- (void)setNeedsFocusUpdate
{
  ASDisplayNodeAssertMainThread();
  [_view setNeedsFocusUpdate];
}

- (void)updateFocusIfNeeded
{
  ASDisplayNodeAssertMainThread();
  [_view updateFocusIfNeeded];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
  return NO;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  
}

- (UIView *)preferredFocusedView
{
  if (self.nodeLoaded) {
    return _view;
  }
  else {
    return nil;
  }
}
#endif

- (BOOL)isFirstResponder
{
  ASDisplayNodeAssertMainThread();
  return _view != nil && [_view isFirstResponder];
}

// Note: this implicitly loads the view if it hasn't been loaded yet.
- (BOOL)becomeFirstResponder
{
  ASDisplayNodeAssertMainThread();
  return !self.layerBacked && [self canBecomeFirstResponder] && [self.view becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
  ASDisplayNodeAssertMainThread();
  return !self.layerBacked && [self canResignFirstResponder] && [_view resignFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  ASDisplayNodeAssertMainThread();
  return !self.layerBacked && [self.view canPerformAction:action withSender:sender];
}

- (CGFloat)alpha
{
  _bridge_prologue_read;
  return _getFromViewOrLayer(opacity, alpha);
}

- (void)setAlpha:(CGFloat)newAlpha
{
  _bridge_prologue_write;
  _setToViewOrLayer(opacity, newAlpha, alpha, newAlpha);
}

- (CGFloat)cornerRadius
{
  _bridge_prologue_read;
  return _getFromLayer(cornerRadius);
}

- (void)setCornerRadius:(CGFloat)newCornerRadius
{
  _bridge_prologue_write;
  _setToLayer(cornerRadius, newCornerRadius);
}

- (CGFloat)contentsScale
{
  _bridge_prologue_read;
  return _getFromLayer(contentsScale);
}

- (void)setContentsScale:(CGFloat)newContentsScale
{
  _bridge_prologue_write;
  _setToLayer(contentsScale, newContentsScale);
}

- (CGRect)bounds
{
  _bridge_prologue_read;
  return _getFromViewOrLayer(bounds, bounds);
}

- (void)setBounds:(CGRect)newBounds
{
  _bridge_prologue_write;
  _setToViewOrLayer(bounds, newBounds, bounds, newBounds);
  self.threadSafeBounds = newBounds;
}

- (CGRect)frame
{
  _bridge_prologue_read;

  // Frame is only defined when transform is identity.
//#if DEBUG
//  // Checking if the transform is identity is expensive, so disable when unnecessary. We have assertions on in Release, so DEBUG is the only way I know of.
//  ASDisplayNodeAssert(CATransform3DIsIdentity(self.transform), @"-[ASDisplayNode frame] - self.transform must be identity in order to use the frame property.  (From Apple's UIView documentation: If the transform property is not the identity transform, the value of this property is undefined and therefore should be ignored.)");
//#endif

  CGPoint position = self.position;
  CGRect bounds = self.bounds;
  CGPoint anchorPoint = self.anchorPoint;
  CGPoint origin = CGPointMake(position.x - bounds.size.width * anchorPoint.x,
                               position.y - bounds.size.height * anchorPoint.y);
  return CGRectMake(origin.x, origin.y, bounds.size.width, bounds.size.height);
}

- (void)setFrame:(CGRect)rect
{
  _bridge_prologue_write;

  // For classes like ASTableNode, ASCollectionNode, ASScrollNode and similar - make sure UIView gets setFrame:
  struct ASDisplayNodeFlags flags = _flags;
  BOOL specialPropertiesHandling = ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(flags);

  BOOL nodeLoaded = __loaded(self);
  BOOL isMainThread = ASDisplayNodeThreadIsMain();
  if (!specialPropertiesHandling) {
    BOOL canReadProperties = isMainThread || !nodeLoaded;
    if (canReadProperties) {
      // We don't have to set frame directly, and we can read current properties.
      // Compute a new bounds and position and set them on self.
      CALayer *layer = _layer;
      BOOL useLayer = (layer != nil);
      CGPoint origin = (useLayer ? layer.bounds.origin : self.bounds.origin);
      CGPoint anchorPoint = (useLayer ? layer.anchorPoint : self.anchorPoint);

      CGRect newBounds = CGRectZero;
      CGPoint newPosition = CGPointZero;
      ASBoundsAndPositionForFrame(rect, origin, anchorPoint, &newBounds, &newPosition);

      if (ASIsCGRectValidForLayout(newBounds) == NO || ASIsCGPositionValidForLayout(newPosition) == NO) {
        ASDisplayNodeAssertNonFatal(NO, @"-[ASDisplayNode setFrame:] - The new frame (%@) is invalid and unsafe to be set.", NSStringFromCGRect(rect));
        return;
      }
      
      if (useLayer) {
        layer.bounds = newBounds;
        layer.position = newPosition;
      } else {
        self.bounds = newBounds;
        self.position = newPosition;
      }
    } else {
      // We don't have to set frame directly, but we can't read properties.
      // Store the frame in our pending state, and it'll get decomposed into
      // bounds and position when the pending state is applied.
      _ASPendingState *pendingState = ASDisplayNodeGetPendingState(self);
      if (nodeLoaded && !pendingState.hasChanges) {
        [[ASPendingStateController sharedInstance] registerNode:self];
      }
      pendingState.frame = rect;
    }
  } else {
    if (nodeLoaded && isMainThread) {
      // We do have to set frame directly, and we're on main thread with a loaded node.
      // Just set the frame on the view.
      // NOTE: Frame is only defined when transform is identity because we explicitly diverge from CALayer behavior and define frame without transform.
//#if DEBUG
//      // Checking if the transform is identity is expensive, so disable when unnecessary. We have assertions on in Release, so DEBUG is the only way I know of.
//      ASDisplayNodeAssert(CATransform3DIsIdentity(self.transform), @"-[ASDisplayNode setFrame:] - self.transform must be identity in order to set the frame property.  (From Apple's UIView documentation: If the transform property is not the identity transform, the value of this property is undefined and therefore should be ignored.)");
//#endif
      _view.frame = rect;
    } else {
      // We do have to set frame directly, but either the node isn't loaded or we're on a non-main thread.
      // Set the frame on the pending state, and it'll call setFrame: when applied.
      _ASPendingState *pendingState = ASDisplayNodeGetPendingState(self);
      if (nodeLoaded && !pendingState.hasChanges) {
        [[ASPendingStateController sharedInstance] registerNode:self];
      }
      pendingState.frame = rect;
    }
  }
}

- (void)setNeedsDisplay
{
  BOOL isRasterized = NO;
  BOOL shouldApply = NO;
  id viewOrLayer = nil;
  {
    _bridge_prologue_write;
    isRasterized = _hierarchyState & ASHierarchyStateRasterized;
    shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
    viewOrLayer = _view ?: _layer;
  }
  
  if (isRasterized) {
    ASPerformBlockOnMainThread(^{
      // The below operation must be performed on the main thread to ensure against an extremely rare deadlock, where a parent node
      // begins materializing the view / layer hierarchy (locking itself or a descendant) while this node walks up
      // the tree and requires locking that node to access .shouldRasterizeDescendants.
      // For this reason, this method should be avoided when possible.  Use _hierarchyState & ASHierarchyStateRasterized.
      ASDisplayNodeAssertMainThread();
      ASDisplayNode *rasterizedContainerNode = self.supernode;
      while (rasterizedContainerNode) {
        if (rasterizedContainerNode.shouldRasterizeDescendants) {
          break;
        }
        rasterizedContainerNode = rasterizedContainerNode.supernode;
      }
      [rasterizedContainerNode setNeedsDisplay];
    });
  } else {
    if (shouldApply) {
      // If not rasterized, and the node is loaded (meaning we certainly have a view or layer), send a
      // message to the view/layer first. This is because __setNeedsDisplay calls as scheduleNodeForDisplay,
      // which may call -displayIfNeeded. We want to ensure the needsDisplay flag is set now, and then cleared.
      [viewOrLayer setNeedsDisplay];
    } else {
      _bridge_prologue_write;
      [ASDisplayNodeGetPendingState(self) setNeedsDisplay];
    }
    [self __setNeedsDisplay];
  }
}

- (void)setNeedsLayout
{
  BOOL shouldApply = NO;
  BOOL loaded = NO;
  id viewOrLayer = nil;
  {
    _bridge_prologue_write;
    shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
    loaded = __loaded(self);
    viewOrLayer = _view ?: _layer;
  }
  
  if (shouldApply) {
    // The node is loaded and we're on main.
    // Quite the opposite of setNeedsDisplay, we must call __setNeedsLayout before messaging
    // the view or layer to ensure that measurement and implicitly added subnodes have been handled.
    [self __setNeedsLayout];
    [viewOrLayer setNeedsLayout];
  } else if (loaded) {
    // The node is loaded but we're not on main.
    // We will call [self __setNeedsLayout] when we apply the pending state.
    // We need to call it on main if the node is loaded to support automatic subnode management.
    _bridge_prologue_write;
    [ASDisplayNodeGetPendingState(self) setNeedsLayout];
  } else {
    // The node is not loaded and we're not on main.
    [self __setNeedsLayout];
  }
}

- (void)layoutIfNeeded
{
  BOOL shouldApply = NO;
  BOOL loaded = NO;
  id viewOrLayer = nil;
  {
    _bridge_prologue_write;
    shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
    loaded = __loaded(self);
    viewOrLayer = _view ?: _layer;
  }
  
  if (shouldApply) {
    // The node is loaded and we're on main.
    // Message the view or layer which in turn will call __layout on us (see -[_ASDisplayLayer layoutSublayers]).
    [viewOrLayer layoutIfNeeded];
  } else if (loaded) {
    // The node is loaded but we're not on main.
    // We will call layoutIfNeeded on the view or layer when we apply the pending state. __layout will in turn be called on us (see -[_ASDisplayLayer layoutSublayers]).
    // We need to call it on main if the node is loaded to support automatic subnode management.
    _bridge_prologue_write;
    [ASDisplayNodeGetPendingState(self) layoutIfNeeded];
  } else {
    // The node is not loaded and we're not on main.
    [self __layout];
  }
}

- (BOOL)isOpaque
{
  _bridge_prologue_read;
  return _getFromLayer(opaque);
}

- (void)setOpaque:(BOOL)newOpaque
{
  _bridge_prologue_write;
  
  BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
  
  if (shouldApply) {
    BOOL oldOpaque = _layer.opaque;
    _layer.opaque = newOpaque;
    if (oldOpaque != newOpaque) {
      [self setNeedsDisplay];
    }
  } else {
    // NOTE: If we're in the background, we cannot read the current value of self.opaque (if loaded).
    // When the pending state is applied to the view on main, we will call `setNeedsDisplay` if
    // the new opaque value doesn't match the one on the layer.
    ASDisplayNodeGetPendingState(self).opaque = newOpaque;
  }
}

- (BOOL)isUserInteractionEnabled
{
  _bridge_prologue_read;
  if (_flags.layerBacked) return NO;
  return _getFromViewOnly(userInteractionEnabled);
}

- (void)setUserInteractionEnabled:(BOOL)enabled
{
  _bridge_prologue_write;
  _setToViewOnly(userInteractionEnabled, enabled);
}
#if TARGET_OS_IOS
- (BOOL)isExclusiveTouch
{
  _bridge_prologue_read;
  return _getFromViewOnly(exclusiveTouch);
}

- (void)setExclusiveTouch:(BOOL)exclusiveTouch
{
  _bridge_prologue_write;
  _setToViewOnly(exclusiveTouch, exclusiveTouch);
}
#endif
- (BOOL)clipsToBounds
{
  _bridge_prologue_read;
  return _getFromViewOrLayer(masksToBounds, clipsToBounds);
}

- (void)setClipsToBounds:(BOOL)clips
{
  _bridge_prologue_write;
  _setToViewOrLayer(masksToBounds, clips, clipsToBounds, clips);
}

- (CGPoint)anchorPoint
{
  _bridge_prologue_read;
  return _getFromLayer(anchorPoint);
}

- (void)setAnchorPoint:(CGPoint)newAnchorPoint
{
  _bridge_prologue_write;
  _setToLayer(anchorPoint, newAnchorPoint);
}

- (CGPoint)position
{
  _bridge_prologue_read;
  return _getFromLayer(position);
}

- (void)setPosition:(CGPoint)newPosition
{
  _bridge_prologue_write;
  _setToLayer(position, newPosition);
}

- (CGFloat)zPosition
{
  _bridge_prologue_read;
  return _getFromLayer(zPosition);
}

- (void)setZPosition:(CGFloat)newPosition
{
  _bridge_prologue_write;
  _setToLayer(zPosition, newPosition);
}

- (CATransform3D)transform
{
  _bridge_prologue_read;
  return _getFromLayer(transform);
}

- (void)setTransform:(CATransform3D)newTransform
{
  _bridge_prologue_write;
  _setToLayer(transform, newTransform);
}

- (CATransform3D)subnodeTransform
{
  _bridge_prologue_read;
  return _getFromLayer(sublayerTransform);
}

- (void)setSubnodeTransform:(CATransform3D)newSubnodeTransform
{
  _bridge_prologue_write;
  _setToLayer(sublayerTransform, newSubnodeTransform);
}

- (id)contents
{
  _bridge_prologue_read;
  return _getFromLayer(contents);
}

- (void)setContents:(id)newContents
{
  _bridge_prologue_write;
  _setToLayer(contents, newContents);
}

- (BOOL)isHidden
{
  _bridge_prologue_read;
  return _getFromViewOrLayer(hidden, hidden);
}

- (void)setHidden:(BOOL)flag
{
  _bridge_prologue_write;
  _setToViewOrLayer(hidden, flag, hidden, flag);
}

- (BOOL)needsDisplayOnBoundsChange
{
  _bridge_prologue_read;
  return _getFromLayer(needsDisplayOnBoundsChange);
}

- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag
{
  _bridge_prologue_write;
  _setToLayer(needsDisplayOnBoundsChange, flag);
}

- (BOOL)autoresizesSubviews
{
  _bridge_prologue_read;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  return _getFromViewOnly(autoresizesSubviews);
}

- (void)setAutoresizesSubviews:(BOOL)flag
{
  _bridge_prologue_write;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  _setToViewOnly(autoresizesSubviews, flag);
}

- (UIViewAutoresizing)autoresizingMask
{
  _bridge_prologue_read;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  return _getFromViewOnly(autoresizingMask);
}

- (void)setAutoresizingMask:(UIViewAutoresizing)mask
{
  _bridge_prologue_write;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  _setToViewOnly(autoresizingMask, mask);
}

- (UIViewContentMode)contentMode
{
  _bridge_prologue_read;
  if (__loaded(self)) {
    if (_flags.layerBacked) {
      return ASDisplayNodeUIContentModeFromCAContentsGravity(_layer.contentsGravity);
    } else {
      return _view.contentMode;
    }
  } else {
    return ASDisplayNodeGetPendingState(self).contentMode;
  }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
  _bridge_prologue_write;
  BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
  if (shouldApply) {
    if (_flags.layerBacked) {
      _layer.contentsGravity = ASDisplayNodeCAContentsGravityFromUIContentMode(contentMode);
    } else {
      _view.contentMode = contentMode;
    }
  } else {
    ASDisplayNodeGetPendingState(self).contentMode = contentMode;
  }
}

- (UIColor *)backgroundColor
{
  _bridge_prologue_read;
  return [UIColor colorWithCGColor:_getFromLayer(backgroundColor)];
}

- (void)setBackgroundColor:(UIColor *)newBackgroundColor
{
  _bridge_prologue_write;
  
  CGColorRef newBackgroundCGColor = [newBackgroundColor CGColor];
  BOOL shouldApply = ASDisplayNodeShouldApplyBridgedWriteToView(self);
  
  if (shouldApply) {
    CGColorRef oldBackgroundCGColor = _layer.backgroundColor;
    
    BOOL specialPropertiesHandling = ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(_flags);
    if (specialPropertiesHandling) {
        _view.backgroundColor = newBackgroundColor;
    } else {
        _layer.backgroundColor = newBackgroundCGColor;
    }
      
    if (!CGColorEqualToColor(oldBackgroundCGColor, newBackgroundCGColor)) {
      [self setNeedsDisplay];
    }
  } else {
    // NOTE: If we're in the background, we cannot read the current value of bgcolor (if loaded).
    // When the pending state is applied to the view on main, we will call `setNeedsDisplay` if
    // the new background color doesn't match the one on the layer.
    ASDisplayNodeGetPendingState(self).backgroundColor = newBackgroundCGColor;
  }
}

- (UIColor *)tintColor
{
  _bridge_prologue_read;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  return _getFromViewOnly(tintColor);
}

- (void)setTintColor:(UIColor *)color
{
  _bridge_prologue_write;
  ASDisplayNodeAssert(!_flags.layerBacked, @"Danger: this property is undefined on layer-backed nodes.");
  _setToViewOnly(tintColor, color);
}

- (void)tintColorDidChange
{
    // ignore this, allow subclasses to be notified
}

- (CGColorRef)shadowColor
{
  _bridge_prologue_read;
  return _getFromLayer(shadowColor);
}

- (void)setShadowColor:(CGColorRef)colorValue
{
  _bridge_prologue_write;
  _setToLayer(shadowColor, colorValue);
}

- (CGFloat)shadowOpacity
{
  _bridge_prologue_read;
  return _getFromLayer(shadowOpacity);
}

- (void)setShadowOpacity:(CGFloat)opacity
{
  _bridge_prologue_write;
  _setToLayer(shadowOpacity, opacity);
}

- (CGSize)shadowOffset
{
  _bridge_prologue_read;
  return _getFromLayer(shadowOffset);
}

- (void)setShadowOffset:(CGSize)offset
{
  _bridge_prologue_write;
  _setToLayer(shadowOffset, offset);
}

- (CGFloat)shadowRadius
{
  _bridge_prologue_read;
  return _getFromLayer(shadowRadius);
}

- (void)setShadowRadius:(CGFloat)radius
{
  _bridge_prologue_write;
  _setToLayer(shadowRadius, radius);
}

- (CGFloat)borderWidth
{
  _bridge_prologue_read;
  return _getFromLayer(borderWidth);
}

- (void)setBorderWidth:(CGFloat)width
{
  _bridge_prologue_write;
  _setToLayer(borderWidth, width);
}

- (CGColorRef)borderColor
{
  _bridge_prologue_read;
  return _getFromLayer(borderColor);
}

- (void)setBorderColor:(CGColorRef)colorValue
{
  _bridge_prologue_write;
  _setToLayer(borderColor, colorValue);
}

- (BOOL)allowsGroupOpacity
{
  _bridge_prologue_read;
  return _getFromLayer(allowsGroupOpacity);
}

- (void)setAllowsGroupOpacity:(BOOL)allowsGroupOpacity
{
  _bridge_prologue_write;
  _setToLayer(allowsGroupOpacity, allowsGroupOpacity);
}

- (BOOL)allowsEdgeAntialiasing
{
  _bridge_prologue_read;
  return _getFromLayer(allowsEdgeAntialiasing);
}

- (void)setAllowsEdgeAntialiasing:(BOOL)allowsEdgeAntialiasing
{
  _bridge_prologue_write;
  _setToLayer(allowsEdgeAntialiasing, allowsEdgeAntialiasing);
}

- (unsigned int)edgeAntialiasingMask
{
  _bridge_prologue_read;
  return _getFromLayer(edgeAntialiasingMask);
}

- (void)setEdgeAntialiasingMask:(unsigned int)edgeAntialiasingMask
{
  _bridge_prologue_write;
  _setToLayer(edgeAntialiasingMask, edgeAntialiasingMask);
}

@end


#pragma mark - UIViewBridgeAccessibility

// ASDK supports accessibility for view or layer backed nodes. To be able to provide support for layer backed
// nodes, properties for all of the UIAccessibility protocol defined properties need to be provided an held in sync
// between node and view

// Helper function with following logic:
// - If the node is not loaded yet use the property from the pending state
// - In case the node is loaded
//  - Check if the node has a view and get the value from the view if loaded or from the pending state
//  - If view is not available, e.g. the node is layer backed return the property value
#define _getAccessibilityFromViewOrProperty(nodeProperty, viewAndPendingViewStateProperty) __loaded(self) ? \
(_view ? _view.viewAndPendingViewStateProperty : nodeProperty )\
: ASDisplayNodeGetPendingState(self).viewAndPendingViewStateProperty

// Helper function to set property values on pending state or view and property if loaded
#define _setAccessibilityToViewAndProperty(nodeProperty, nodeValueExpr, viewAndPendingViewStateProperty, viewAndPendingViewStateExpr) \
nodeProperty = nodeValueExpr; _setToViewOnly(viewAndPendingViewStateProperty, viewAndPendingViewStateExpr)

@implementation ASDisplayNode (UIViewBridgeAccessibility)

- (BOOL)isAccessibilityElement
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_isAccessibilityElement, isAccessibilityElement);
}

- (void)setIsAccessibilityElement:(BOOL)isAccessibilityElement
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_isAccessibilityElement, isAccessibilityElement, isAccessibilityElement, isAccessibilityElement);
}

- (NSString *)accessibilityLabel
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityLabel, accessibilityLabel);
}

- (void)setAccessibilityLabel:(NSString *)accessibilityLabel
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityLabel, accessibilityLabel, accessibilityLabel, accessibilityLabel);
}

- (NSString *)accessibilityHint
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityHint, accessibilityHint);
}

- (void)setAccessibilityHint:(NSString *)accessibilityHint
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityHint, accessibilityHint, accessibilityHint, accessibilityHint);
}

- (NSString *)accessibilityValue
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityValue, accessibilityValue);
}

- (void)setAccessibilityValue:(NSString *)accessibilityValue
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityValue, accessibilityValue, accessibilityValue, accessibilityValue);
}

- (UIAccessibilityTraits)accessibilityTraits
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityTraits, accessibilityTraits);
}

- (void)setAccessibilityTraits:(UIAccessibilityTraits)accessibilityTraits
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityTraits, accessibilityTraits, accessibilityTraits, accessibilityTraits);
}

- (CGRect)accessibilityFrame
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityFrame, accessibilityFrame);
}

- (void)setAccessibilityFrame:(CGRect)accessibilityFrame
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityFrame, accessibilityFrame, accessibilityFrame, accessibilityFrame);
}

- (NSString *)accessibilityLanguage
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityLanguage, accessibilityLanguage);
}

- (void)setAccessibilityLanguage:(NSString *)accessibilityLanguage
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityLanguage, accessibilityLanguage, accessibilityLanguage, accessibilityLanguage);
}

- (BOOL)accessibilityElementsHidden
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityElementsHidden, accessibilityElementsHidden);
}

- (void)setAccessibilityElementsHidden:(BOOL)accessibilityElementsHidden
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityElementsHidden, accessibilityElementsHidden, accessibilityElementsHidden, accessibilityElementsHidden);
}

- (BOOL)accessibilityViewIsModal
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityViewIsModal, accessibilityViewIsModal);
}

- (void)setAccessibilityViewIsModal:(BOOL)accessibilityViewIsModal
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityViewIsModal, accessibilityViewIsModal, accessibilityViewIsModal, accessibilityViewIsModal);
}

- (BOOL)shouldGroupAccessibilityChildren
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_shouldGroupAccessibilityChildren, shouldGroupAccessibilityChildren);
}

- (void)setShouldGroupAccessibilityChildren:(BOOL)shouldGroupAccessibilityChildren
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_shouldGroupAccessibilityChildren, shouldGroupAccessibilityChildren, shouldGroupAccessibilityChildren, shouldGroupAccessibilityChildren);
}

- (NSString *)accessibilityIdentifier
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityIdentifier, accessibilityIdentifier);
}

- (void)setAccessibilityIdentifier:(NSString *)accessibilityIdentifier
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityIdentifier, accessibilityIdentifier, accessibilityIdentifier, accessibilityIdentifier);
}

- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityNavigationStyle, accessibilityNavigationStyle, accessibilityNavigationStyle, accessibilityNavigationStyle);
}

- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityNavigationStyle, accessibilityNavigationStyle);
}

#if TARGET_OS_TV
- (void)setAccessibilityHeaderElements:(NSArray *)accessibilityHeaderElements
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityHeaderElements, accessibilityHeaderElements, accessibilityHeaderElements, accessibilityHeaderElements);
}

- (NSArray *)accessibilityHeaderElements
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityHeaderElements, accessibilityHeaderElements);
}
#endif

- (void)setAccessibilityActivationPoint:(CGPoint)accessibilityActivationPoint
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityActivationPoint, accessibilityActivationPoint, accessibilityActivationPoint, accessibilityActivationPoint);
}

- (CGPoint)accessibilityActivationPoint
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityActivationPoint, accessibilityActivationPoint);
}

- (void)setAccessibilityPath:(UIBezierPath *)accessibilityPath
{
  _bridge_prologue_write;
  _setAccessibilityToViewAndProperty(_accessibilityPath, accessibilityPath, accessibilityPath, accessibilityPath);
}

- (UIBezierPath *)accessibilityPath
{
  _bridge_prologue_read;
  return _getAccessibilityFromViewOrProperty(_accessibilityPath, accessibilityPath);
}

- (NSInteger)accessibilityElementCount
{
  _bridge_prologue_read;
  return _getFromViewOnly(accessibilityElementCount);
}

@end


#pragma mark - ASAsyncTransactionContainer

@implementation ASDisplayNode (ASAsyncTransactionContainer)

- (BOOL)asyncdisplaykit_isAsyncTransactionContainer
{
  _bridge_prologue_read;
  return _getFromViewOrLayer(asyncdisplaykit_isAsyncTransactionContainer, asyncdisplaykit_isAsyncTransactionContainer);
}

- (void)asyncdisplaykit_setAsyncTransactionContainer:(BOOL)asyncTransactionContainer
{
  _bridge_prologue_write;
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

- (void)asyncdisplaykit_setCurrentAsyncTransaction:(_ASAsyncTransaction *)transaction
{
  _layer.asyncdisplaykit_currentAsyncTransaction = transaction;
}

- (_ASAsyncTransaction *)asyncdisplaykit_currentAsyncTransaction
{
  return _layer.asyncdisplaykit_currentAsyncTransaction;
}

@end

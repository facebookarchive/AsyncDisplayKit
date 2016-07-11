//
//  ASDisplayNodeInternal.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#import "_AS-objc-internal.h"
#import "ASDisplayNode.h"
#import "ASSentinel.h"
#import "ASThread.h"
#import "_ASTransitionContext.h"
#import "ASLayoutTransition.h"
#import "ASEnvironment.h"

#include <vector>

@protocol _ASDisplayLayerDelegate;
@class _ASDisplayLayer;
@class _ASPendingState;
@class ASSentinel;
struct ASDisplayNodeFlags;

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector);
BOOL ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(ASDisplayNodeFlags flags);

/// Get the pending view state for the node, creating one if needed.
_ASPendingState *ASDisplayNodeGetPendingState(ASDisplayNode *node);

typedef NS_OPTIONS(NSUInteger, ASDisplayNodeMethodOverrides)
{
  ASDisplayNodeMethodOverrideNone               = 0,
  ASDisplayNodeMethodOverrideTouchesBegan       = 1 << 0,
  ASDisplayNodeMethodOverrideTouchesCancelled   = 1 << 1,
  ASDisplayNodeMethodOverrideTouchesEnded       = 1 << 2,
  ASDisplayNodeMethodOverrideTouchesMoved       = 1 << 3,
  ASDisplayNodeMethodOverrideLayoutSpecThatFits = 1 << 4
};

@class _ASDisplayNodePosition;

FOUNDATION_EXPORT NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification;
FOUNDATION_EXPORT NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp;

// Allow 2^n increments of begin disabling hierarchy notifications
#define VISIBILITY_NOTIFICATIONS_DISABLED_BITS 4

#define TIME_DISPLAYNODE_OPS 0 // If you're using this information frequently, try: (DEBUG || PROFILE)

@interface ASDisplayNode ()
{
@package
  _ASPendingState *_pendingViewState;

  // Protects access to _view, _layer, _pendingViewState, _subnodes, _supernode, and other properties which are accessed from multiple threads.
  ASDN::RecursiveMutex _propertyLock;
  UIView *_view;
  CALayer *_layer;

  struct ASDisplayNodeFlags {
    // public properties
    unsigned synchronous:1;
    unsigned layerBacked:1;
    unsigned displaysAsynchronously:1;
    unsigned shouldRasterizeDescendants:1;
    unsigned shouldBypassEnsureDisplay:1;
    unsigned displaySuspended:1;
    unsigned shouldAnimateSizeChanges:1;
    unsigned hasCustomDrawingPriority:1;
    
    // Wrapped view handling
    
    // The layer contents should not be cleared in case the node is wrapping a UIImageView.UIImageView is specifically
    // optimized for performance and does not use the usual way to provide the contents of the CALayer via the
    // CALayerDelegate method that backs the UIImageView.
    unsigned canClearContentsOfLayer:1;
    
    // Prevent calling setNeedsDisplay on a layer that backs a UIImageView. Usually calling setNeedsDisplay on a CALayer
    // triggers a recreation of the contents of layer unfortunately calling it on a CALayer that backs a UIImageView
    // it goes trough the normal flow to assign the contents to a layer via the CALayerDelegate methods. Unfortunately
    // UIImageView does not do recreate the layer contents the usual way, it actually does not implement some of the
    // methods at all instead it throws away the contents of the layer and nothing will show up.
    unsigned canCallNeedsDisplayOfLayer:1;

    // whether custom drawing is enabled
    unsigned implementsInstanceDrawRect:1;
    unsigned implementsDrawRect:1;
    unsigned implementsInstanceImageDisplay:1;
    unsigned implementsImageDisplay:1;
    unsigned implementsDrawParameters:1;

    // internal state
    unsigned isEnteringHierarchy:1;
    unsigned isExitingHierarchy:1;
    unsigned isInHierarchy:1;
    unsigned visibilityNotificationsDisabled:VISIBILITY_NOTIFICATIONS_DISABLED_BITS;
  } _flags;
  
@protected
  ASDisplayNode * __weak _supernode;

  ASSentinel *_displaySentinel;

  int32_t _transitionID;
  BOOL _transitionInProgress;

  // This is the desired contentsScale, not the scale at which the layer's contents should be displayed
  CGFloat _contentsScaleForDisplay;

  ASEnvironmentState _environmentState;
  ASLayout *_layout;


  UIEdgeInsets _hitTestSlop;
  NSMutableArray *_subnodes;
  
  // Main thread only
  _ASTransitionContext *_transitionContext;
  BOOL _usesImplicitHierarchyManagement;

  int32_t _pendingTransitionID;
  ASLayoutTransition *_pendingLayoutTransition;
  
  ASDisplayNodeViewBlock _viewBlock;
  ASDisplayNodeLayerBlock _layerBlock;
  ASDisplayNodeDidLoadBlock _nodeLoadedBlock;
  Class _viewClass;
  Class _layerClass;
  
  UIImage *_placeholderImage;
  CALayer *_placeholderLayer;

  // keeps track of nodes/subnodes that have not finished display, used with placeholders
  NSMutableSet *_pendingDisplayNodes;

  ASDisplayNodeContextModifier _willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier _didDisplayNodeContentWithRenderingContext;

  // Accessibility support
  BOOL _isAccessibilityElement;
  NSString *_accessibilityLabel;
  NSString *_accessibilityHint;
  NSString *_accessibilityValue;
  UIAccessibilityTraits _accessibilityTraits;
  CGRect _accessibilityFrame;
  NSString *_accessibilityLanguage;
  BOOL _accessibilityElementsHidden;
  BOOL _accessibilityViewIsModal;
  BOOL _shouldGroupAccessibilityChildren;
  NSString *_accessibilityIdentifier;
  UIAccessibilityNavigationStyle _accessibilityNavigationStyle;
  NSArray *_accessibilityHeaderElements;
  CGPoint _accessibilityActivationPoint;
  UIBezierPath *_accessibilityPath;

#if TIME_DISPLAYNODE_OPS
@public
  NSTimeInterval _debugTimeToCreateView;
  NSTimeInterval _debugTimeToApplyPendingState;
  NSTimeInterval _debugTimeToAddSubnodeViews;
  NSTimeInterval _debugTimeForDidLoad;
#endif
}

+ (void)scheduleNodeForRecursiveDisplay:(ASDisplayNode *)node;

// The _ASDisplayLayer backing the node, if any.
@property (nonatomic, readonly, strong) _ASDisplayLayer *asyncLayer;

// Bitmask to check which methods an object overrides.
@property (nonatomic, assign, readonly) ASDisplayNodeMethodOverrides methodOverrides;

@property (nonatomic, assign) CGRect threadSafeBounds;


// Swizzle to extend the builtin functionality with custom logic
- (BOOL)__shouldLoadViewOrLayer;
- (BOOL)__shouldSize;

/**
 Invoked before a call to setNeedsLayout to the underlying view
 */
- (void)__setNeedsLayout;

/**
 Invoked after a call to setNeedsDisplay to the underlying view
 */
- (void)__setNeedsDisplay;

- (void)__layout;
- (void)__setSupernode:(ASDisplayNode *)supernode;

// Private API for helper functions / unit tests.  Use ASDisplayNodeDisableHierarchyNotifications() to control this.
- (BOOL)__visibilityNotificationsDisabled;
- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled;
- (void)__incrementVisibilityNotificationsDisabled;
- (void)__decrementVisibilityNotificationsDisabled;

// Helper method to summarize whether or not the node run through the display process
- (BOOL)__implementsDisplay;

// Display the node's view/layer immediately on the current thread, bypassing the background thread rendering. Will be deprecated.
- (void)displayImmediately;

// Alternative initialiser for backing with a custom view class.  Supports asynchronous display with _ASDisplayView subclasses.
- (instancetype)initWithViewClass:(Class)viewClass;

// Alternative initialiser for backing with a custom layer class.  Supports asynchronous display with _ASDisplayLayer subclasses.
- (instancetype)initWithLayerClass:(Class)layerClass;

@property (nonatomic, assign) CGFloat contentsScaleForDisplay;

- (void)applyPendingViewState;

/**
 * // TODO: NOT YET IMPLEMENTED
 *
 * @abstract Prevents interface state changes from affecting the node, until disabled.
 *
 * @discussion Useful to avoid flashing after removing a node from the hierarchy and re-adding it.
 * Removing a node from the hierarchy will cause it to exit the Display state, clearing its contents.
 * For some animations, it's desirable to be able to remove a node without causing it to re-display.
 * Once re-enabled, the interface state will be updated to the same value it would have been.
 *
 * @see ASInterfaceState
 */
@property (nonatomic, assign) BOOL interfaceStateSuspended;

/**
 * This method has proven helpful in a few rare scenarios, similar to a category extension on UIView,
 * but it's considered private API for now and its use should not be encouraged.
 * @param checkViewHierarchy If YES, and no supernode can be found, method will walk up from `self.view` to find a supernode.
 * If YES, this method must be called on the main thread and the node must not be layer-backed.
 */
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass checkViewHierarchy:(BOOL)checkViewHierarchy;

/**
 *  Convenience method to access this node's trait collection struct. Externally, users should interact
 *  with the trait collection via ASTraitCollection
 */
- (ASEnvironmentTraitCollection)environmentTraitCollection;

@end

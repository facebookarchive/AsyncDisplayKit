/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#import "_AS-objc-internal.h"
#import "ASDisplayNodeExtraIvars.h"
#import "ASDisplayNode.h"
#import "ASSentinel.h"
#import "ASThread.h"
#import "ASLayoutOptions.h"

@protocol _ASDisplayLayerDelegate;
@class _ASDisplayLayer;

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector);
void ASDisplayNodeRespectThreadAffinityOfNode(ASDisplayNode *node, void (^block)());

typedef NS_OPTIONS(NSUInteger, ASDisplayNodeMethodOverrides)
{
  ASDisplayNodeMethodOverrideNone               = 0,
  ASDisplayNodeMethodOverrideTouchesBegan       = 1 << 0,
  ASDisplayNodeMethodOverrideTouchesCancelled   = 1 << 1,
  ASDisplayNodeMethodOverrideTouchesEnded       = 1 << 2,
  ASDisplayNodeMethodOverrideTouchesMoved       = 1 << 3,
  ASDisplayNodeMethodOverrideLayoutSpecThatFits = 1 << 4
};

@class _ASPendingState;

// Allow 2^n increments of begin disabling hierarchy notifications
#define VISIBILITY_NOTIFICATIONS_DISABLED_BITS 4

#define TIME_DISPLAYNODE_OPS (DEBUG || PROFILE)

@interface ASDisplayNode ()
{
@protected
  // Protects access to _view, _layer, _pendingViewState, _subnodes, _supernode, and other properties which are accessed from multiple threads.
  ASDN::RecursiveMutex _propertyLock;

  ASDisplayNode * __weak _supernode;

  ASSentinel *_displaySentinel;
  ASSentinel *_replaceAsyncSentinel;

  // This is the desired contentsScale, not the scale at which the layer's contents should be displayed
  CGFloat _contentsScaleForDisplay;

  ASLayout *_layout;
  ASSizeRange _constrainedSize;
  UIEdgeInsets _hitTestSlop;
  NSMutableArray *_subnodes;

  ASDisplayNodeViewBlock _viewBlock;
  ASDisplayNodeLayerBlock _layerBlock;
  ASDisplayNodeDidLoadBlock _nodeLoadedBlock;
  Class _viewClass;
  Class _layerClass;
  UIView *_view;
  CALayer *_layer;

  UIImage *_placeholderImage;
  CALayer *_placeholderLayer;

  // keeps track of nodes/subnodes that have not finished display, used with placeholders
  NSMutableSet *_pendingDisplayNodes;

  _ASPendingState *_pendingViewState;
  
  struct ASDisplayNodeFlags {
    // public properties
    unsigned synchronous:1;
    unsigned layerBacked:1;
    unsigned displaysAsynchronously:1;
    unsigned shouldRasterizeDescendants:1;
    unsigned shouldBypassEnsureDisplay:1;
    unsigned displaySuspended:1;

    // whether custom drawing is enabled
    unsigned implementsDrawRect:1;
    unsigned implementsImageDisplay:1;
    unsigned implementsDrawParameters:1;

    // internal state
    unsigned isMeasured:1;
    unsigned isEnteringHierarchy:1;
    unsigned isExitingHierarchy:1;
    unsigned isInHierarchy:1;
    unsigned visibilityNotificationsDisabled:VISIBILITY_NOTIFICATIONS_DISABLED_BITS;
  } _flags;

  ASDisplayNodeExtraIvars _extra;

#if TIME_DISPLAYNODE_OPS
@public
  NSTimeInterval _debugTimeToCreateView;
  NSTimeInterval _debugTimeToApplyPendingState;
  NSTimeInterval _debugTimeToAddSubnodeViews;
  NSTimeInterval _debugTimeForDidLoad;
#endif
}

+ (void)scheduleNodeForDisplay:(ASDisplayNode *)node;

// The _ASDisplayLayer backing the node, if any.
@property (nonatomic, readonly, retain) _ASDisplayLayer *asyncLayer;

// Creates a pendingViewState if one doesn't exist. Allows setting view properties on a bg thread before there is a view.
@property (atomic, retain, readonly) _ASPendingState *pendingViewState;

// Bitmask to check which methods an object overrides.
@property (nonatomic, assign, readonly) ASDisplayNodeMethodOverrides methodOverrides;


// Swizzle to extend the builtin functionality with custom logic
- (BOOL)__shouldLoadViewOrLayer;
- (BOOL)__shouldSize;

// Core implementation of -measureWithSizeRange:. Must be called with _propertyLock held.
- (ASLayout *)__measureWithSizeRange:(ASSizeRange)constrainedSize;

- (void)__setNeedsLayout;
- (void)__layout;
- (void)__setSupernode:(ASDisplayNode *)supernode;

// Changed before calling willEnterHierarchy / didExitHierarchy.
@property (nonatomic, readwrite, assign, getter = isInHierarchy) BOOL inHierarchy;

// Private API for helper functions / unit tests.  Use ASDisplayNodeDisableHierarchyNotifications() to control this.
- (BOOL)__visibilityNotificationsDisabled;
- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled;
- (void)__incrementVisibilityNotificationsDisabled;
- (void)__decrementVisibilityNotificationsDisabled;

// Call willEnterHierarchy if necessary and set inHierarchy = YES if visibility notifications are enabled on all of its parents
- (void)__enterHierarchy;
// Call didExitHierarchy if necessary and set inHierarchy = NO if visibility notifications are enabled on all of its parents
- (void)__exitHierarchy;

// Helper method to summarize whether or not the node run through the display process
- (BOOL)__implementsDisplay;

// Display the node's view/layer immediately on the current thread, bypassing the background thread rendering. Will be deprecated.
- (void)displayImmediately;

// Alternative initialiser for backing with a custom view class.  Supports asynchronous display with _ASDisplayView subclasses.
- (id)initWithViewClass:(Class)viewClass;

// Alternative initialiser for backing with a custom layer class.  Supports asynchronous display with _ASDisplayLayer subclasses.
- (id)initWithLayerClass:(Class)layerClass;

@property (nonatomic, assign) CGFloat contentsScaleForDisplay;

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

@end

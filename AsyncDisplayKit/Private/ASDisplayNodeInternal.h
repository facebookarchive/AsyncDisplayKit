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

#import "_ASDisplayLayer.h"
#import "_AS-objc-internal.h"
#import "ASDisplayNodeExtraIvars.h"
#import "ASDisplayNode.h"
#import "ASSentinel.h"
#import "ASThread.h"

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector);
CGFloat ASDisplayNodeScreenScale();
void ASDisplayNodePerformBlockOnMainThread(void (^block)());

@class _ASPendingState;

// Allow 2^n increments of begin disabling hierarchy notifications
#define visibilityNotificationsDisabledBits 4

#define TIME_DISPLAYNODE_OPS (DEBUG || PROFILE)

@interface ASDisplayNode () <_ASDisplayLayerDelegate>
{
@protected
  ASDN::RecursiveMutex _propertyLock;  // Protects access to the _view, _pendingViewState, _subnodes, _supernode, _renderingSubnodes, and other properties which are accessed from multiple threads.

  ASDisplayNode * __weak _supernode;

  ASSentinel *_displaySentinel;
  ASSentinel *_replaceAsyncSentinel;

  // This is the desired contentsScale, not the scale at which the layer's contents should be displayed
  CGFloat _contentsScaleForDisplay;

  CGSize _size;
  CGSize _constrainedSize;
  UIEdgeInsets _hitTestSlop;
  NSMutableArray *_subnodes;

  Class _viewClass;
  Class _layerClass;
  UIView *_view;
  CALayer *_layer;

  _ASPendingState *_pendingViewState;

  struct {
    unsigned implementsDisplay:1;
    unsigned isSynchronous:1;
    unsigned isLayerBacked:1;
    unsigned sizeCalculated:1;
    unsigned preventOrCancelDisplay:1;
    unsigned displaysAsynchronously:1;
    unsigned shouldRasterizeDescendants:1;
    unsigned visibilityNotificationsDisabled:visibilityNotificationsDisabledBits;
    unsigned isInEnterHierarchy:1;
    unsigned isInExitHierarchy:1;
    unsigned inWindow:1;
    unsigned hasWillDisplayAsyncLayer:1;
    unsigned hasDrawParametersForAsyncLayer:1;
    unsigned hasClassDisplay:1;
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

// The _ASDisplayLayer backing the node, if any.
@property (nonatomic, readonly, retain) _ASDisplayLayer *asyncLayer;

// Creates a pendingViewState if one doesn't exist. Allows setting view properties on a bg thread before there is a view.
@property (atomic, retain, readonly) _ASPendingState *pendingViewState;

// Swizzle to extend the builtin functionality with custom logic
- (BOOL)__shouldLoadViewOrLayer;
- (BOOL)__shouldSize;
- (void)__exitedHierarchy;

- (void)__layout;
- (void)__setSupernode:(ASDisplayNode *)supernode;

// The visibility state of the node.  Changed before calling willAppear, willDisappear, and didDisappear.
@property (nonatomic, readwrite, assign, getter = isInWindow) BOOL inWindow;

// Private API for helper funcitons / unit tests. Use ASDisplayNodeDisableHierarchyNotifications() to control this.
- (BOOL)__visibilityNotificationsDisabled;
- (void)__incrementVisibilityNotificationsDisabled;
- (void)__decrementVisibilityNotificationsDisabled;

// Call willEnterHierarchy if necessary and set inWindow = YES if visibility notifications are enabled on all of its parents
- (void)__enterHierarchy;
// Call didExitHierarchy if necessary and set inWindow = NO if visibility notifications are enabled on all of its parents
- (void)__exitHierarchy;

// Returns the ancestor node that rasterizes descendants, or nil if none.
- (ASDisplayNode *)__rasterizedContainerNode;

@property (nonatomic, assign) CGFloat contentsScaleForDisplay;

@end

@interface UIView (ASDisplayNodeInternal)
@property (nonatomic, assign, readwrite) ASDisplayNode *asyncdisplaykit_node;
@end

@interface CALayer (ASDisplayNodeInternal)
@property (nonatomic, assign, readwrite) ASDisplayNode *asyncdisplaykit_node;
@end

//
//  _ASDisplayView.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "_ASDisplayView.h"

#import "_ASCoreAnimationExtras.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Subclasses.h"

@interface _ASDisplayView ()
@property (nonatomic, assign, readwrite) ASDisplayNode *asyncdisplaykit_node;

// Keep the node alive while its view is active.  If you create a view, add its layer to a layer hierarchy, then release
// the view, the layer retains the view to prevent a crash.  This replicates this behaviour for the node abstraction.
@property (nonatomic, strong, readwrite) ASDisplayNode *keepalive_node;
@end

@implementation _ASDisplayView
{
  __unsafe_unretained ASDisplayNode *_node;  // Though UIView has a .node property added via category, since we can add an ivar to a subclass, use that for performance.
  BOOL _inHitTest;
  BOOL _inPointInside;
  NSArray *_accessibleElements;
}

@synthesize asyncdisplaykit_node = _node;

+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark - NSObject Overrides
- (instancetype)init
{
  return [self initWithFrame:CGRectZero];
}

- (NSString *)description
{
  // The standard UIView description is useless for debugging because all ASDisplayNode subclasses have _ASDisplayView-type views.
  // This allows us to at least see the name of the node subclass and get its pointer directly from [[UIWindow keyWindow] recursiveDescription].
  return [NSString stringWithFormat:@"<%@, view = %@>", _node, [super description]];
}

#pragma mark - UIView Overrides

- (instancetype)initWithFrame:(CGRect)frame
{
  if (!(self = [super initWithFrame:frame]))
    return nil;

  return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
  BOOL visible = (newWindow != nil);
  if (visible && !_node.inHierarchy) {
    [_node __enterHierarchy];
  }
}

- (void)didMoveToWindow
{
  BOOL visible = (self.window != nil);
  if (!visible && _node.inHierarchy) {
    [_node __exitHierarchy];
  }
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
  // Keep the node alive while the view is in a view hierarchy.  This helps ensure that async-drawing views can always
  // display their contents as long as they are visible somewhere, and aids in lifecycle management because the
  // lifecycle of the node can be treated as the same as the lifecycle of the view (let the view hierarchy own the
  // view).
  UIView *currentSuperview = self.superview;
  if (!currentSuperview && newSuperview) {
    self.keepalive_node = _node;
  } else if (currentSuperview && !newSuperview) {
    // Clearing keepalive_node may cause deallocation of the node.  In this case, __exitHierarchy may not have an opportunity (e.g. _node will be cleared
    // by the time -didMoveToWindow occurs after this) to clear the Visible interfaceState, which we need to do before deallocation to meet an API guarantee.
    if (_node.inHierarchy) {
      [_node __exitHierarchy];
    }
    self.keepalive_node = nil;
  }
    
  ASDisplayNodeAssert(self.keepalive_node == nil || newSuperview != nil, @"Keepalive reference should not exist if there is no superview.");
  
  if (newSuperview) {
    ASDisplayNode *supernode = _node.supernode;
    BOOL supernodeLoaded = supernode.nodeLoaded;
    ASDisplayNodeAssert(!supernode.isLayerBacked, @"Shouldn't be possible for _ASDisplayView's supernode to be layer-backed.");
    
    BOOL needsSupernodeUpdate = NO;

    if (supernode) {
      if (supernodeLoaded) {
        if (supernode.layerBacked) {
          // See comment in -didMoveToSuperview.  This case should be avoided, but is possible with app-level coding errors.
          needsSupernodeUpdate = (supernode.layer != newSuperview.layer);
        } else {
          // If we have a supernode, compensate for users directly messing with views by hitching up to any new supernode.
          needsSupernodeUpdate = (supernode.view != newSuperview);
        }
      } else {
        needsSupernodeUpdate = YES;
      }
    } else {
      // If we have no supernode and we are now in a view hierarchy, check to see if we can hook up to a supernode.
      needsSupernodeUpdate = (newSuperview != nil);
    }

    if (needsSupernodeUpdate) {
      // -removeFromSupernode is called by -addSubnode:, if it is needed.
      [newSuperview.asyncdisplaykit_node addSubnode:_node];
    }
  }

}

- (void)didMoveToSuperview
{
  ASDisplayNode *supernode = _node.supernode;
  ASDisplayNodeAssert(!supernode.isLayerBacked, @"Shouldn't be possible for superview's node to be layer-backed.");
  
  if (supernode) {
    ASDisplayNodeAssertTrue(_node.nodeLoaded);
    UIView *superview = self.superview;
    BOOL supernodeLoaded = supernode.nodeLoaded;
    BOOL needsSupernodeRemoval = NO;
    
    if (superview) {
      // If our new superview is not the same as the supernode's view, or the supernode has no view, disconnect.
      if (supernodeLoaded) {
        if (supernode.layerBacked) {
          // As asserted at the top, this shouldn't be possible, but in production with assertions disabled it can happen.
          // We try to make such code behave as well as feasible because it's not that hard of an error to make if some deep
          // child node of a layer-backed node happens to be view-backed, but it is not supported and should be avoided.
          needsSupernodeRemoval = (supernode.layer != superview.layer);
        } else {
          needsSupernodeRemoval = (supernode.view != superview);
        }
      } else {
        needsSupernodeRemoval = YES;
      }
    } else {
      // If supernode is loaded but our superview is nil, the user likely manually removed us, so disconnect supernode.
      // The unlikely alternative: we are in __unloadNode, with shouldRasterizeSubnodes just having been turned on.
      // In the latter case, we don't want to disassemble the node hierarchy because all views are intentionally being destroyed.
      BOOL nodeIsRasterized = ((_node.hierarchyState & ASHierarchyStateRasterized) == ASHierarchyStateRasterized);
      needsSupernodeRemoval = (supernodeLoaded && !nodeIsRasterized);
    }
    
    if (needsSupernodeRemoval) {
      // The node will only disconnect from its supernode, not removeFromSuperview, in this condition.
      [_node removeFromSupernode];
    }
  }
}

- (void)setNeedsDisplay
{
  // Standard implementation does not actually get to the layer, at least for views that don't implement drawRect:.
  if (ASDisplayNodeThreadIsMain()) {
    [self.layer setNeedsDisplay];
  } else {
    dispatch_async(dispatch_get_main_queue(), ^ {
      [self.layer setNeedsDisplay];
    });
  }
}

- (void)setNeedsLayout
{
  if (ASDisplayNodeThreadIsMain()) {
    [super setNeedsLayout];
  } else {
    dispatch_async(dispatch_get_main_queue(), ^ {
      [super setNeedsLayout];
    });
  }
}

- (UIViewContentMode)contentMode
{
  return ASDisplayNodeUIContentModeFromCAContentsGravity(self.layer.contentsGravity);
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
  ASDisplayNodeAssert(contentMode != UIViewContentModeRedraw, @"Don't do this. Use needsDisplayOnBoundsChange instead.");

  // Do our own mapping so as not to call super and muck up needsDisplayOnBoundsChange. If we're in a production build, fall back to resize if we see redraw
  self.layer.contentsGravity = (contentMode != UIViewContentModeRedraw) ? ASDisplayNodeCAContentsGravityFromUIContentMode(contentMode) : kCAGravityResize;
}

- (void)setBounds:(CGRect)bounds
{
  [super setBounds:bounds];
  _node.threadSafeBounds = bounds;
}

#pragma mark - Event Handling + UIResponder Overrides
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (_node.methodOverrides & ASDisplayNodeMethodOverrideTouchesBegan) {
    [_node touchesBegan:touches withEvent:event];
  } else {
    [super touchesBegan:touches withEvent:event];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (_node.methodOverrides & ASDisplayNodeMethodOverrideTouchesMoved) {
    [_node touchesMoved:touches withEvent:event];
  } else {
    [super touchesMoved:touches withEvent:event];
  }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (_node.methodOverrides & ASDisplayNodeMethodOverrideTouchesEnded) {
    [_node touchesEnded:touches withEvent:event];
  } else {
    [super touchesEnded:touches withEvent:event];
  }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  if (_node.methodOverrides & ASDisplayNodeMethodOverrideTouchesCancelled) {
    [_node touchesCancelled:touches withEvent:event];
  } else {
    [super touchesCancelled:touches withEvent:event];
  }
}

- (void)__forwardTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];
}

- (void)__forwardTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesMoved:touches withEvent:event];
}

- (void)__forwardTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];
}

- (void)__forwardTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesCancelled:touches withEvent:event];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  // REVIEW: We should optimize these types of messages by setting a boolean in the associated ASDisplayNode subclass if
  // they actually override the method.  Same goes for -pointInside:withEvent: below.  Many UIKit classes use that
  // pattern for meaningful reductions of message send overhead in hot code (especially event handling).

  // Set boolean so this method can be re-entrant.  If the node subclass wants to default to / make use of UIView
  // hitTest:, it will call it on the view, which is _ASDisplayView.  After calling into the node, any additional calls
  // should use the UIView implementation of hitTest:
  if (!_inHitTest) {
    _inHitTest = YES;
    UIView *hitView = [_node hitTest:point withEvent:event];
    _inHitTest = NO;
    return hitView;
  } else {
    return [super hitTest:point withEvent:event];
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  // See comments in -hitTest:withEvent: for the strategy here.
  if (!_inPointInside) {
    _inPointInside = YES;
    BOOL result = [_node pointInside:point withEvent:event];
    _inPointInside = NO;
    return result;
  } else {
    return [super pointInside:point withEvent:event];
  }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  return [_node gestureRecognizerShouldBegin:gestureRecognizer];
}
#endif

- (void)asyncdisplaykit_asyncTransactionContainerStateDidChange
{
  [_node asyncdisplaykit_asyncTransactionContainerStateDidChange];
}

- (void)tintColorDidChange
{
    [super tintColorDidChange];
    
    [_node tintColorDidChange];
}

- (BOOL)canBecomeFirstResponder {
    return [_node canBecomeFirstResponder];
}

- (BOOL)canResignFirstResponder {
    return [_node canResignFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  // We forward responder-chain actions to our node if we can't handle them ourselves. See -targetForAction:withSender:.
  return ([super canPerformAction:action withSender:sender] || [_node respondsToSelector:action]);
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  // Ideally, we would implement -targetForAction:withSender: and simply return the node where we don't respond personally.
  // Unfortunately UIResponder's default implementation of -targetForAction:withSender: doesn't follow its own documentation. It doesn't call -targetForAction:withSender: up the responder chain when -canPerformAction:withSender: fails, but instead merely calls -canPerformAction:withSender: on itself and then up the chain. rdar://20111500.
  // Consequently, to forward responder-chain actions to our node, we override -canPerformAction:withSender: (used by the chain) to indicate support for responder chain-driven actions that our node supports, and then provide the node as a forwarding target here.
  return _node;
}

#if TARGET_OS_TV
#pragma mark - tvOS
- (BOOL)canBecomeFocused
{
  return [_node canBecomeFocused];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  return [_node didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
}

- (void)setNeedsFocusUpdate
{
  return [_node setNeedsFocusUpdate];
}

- (void)updateFocusIfNeeded
{
  return [_node updateFocusIfNeeded];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
  return [_node shouldUpdateFocusInContext:context];
}

- (UIView *)preferredFocusedView
{
  return [_node preferredFocusedView];
}
#endif
@end

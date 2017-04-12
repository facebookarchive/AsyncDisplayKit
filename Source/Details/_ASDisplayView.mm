//
//  _ASDisplayView.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/_ASDisplayViewAccessiblity.h>

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASLayout.h>

@interface _ASDisplayView ()
@property (nullable, atomic, weak, readwrite) ASDisplayNode *asyncdisplaykit_node;

// Keep the node alive while its view is active.  If you create a view, add its layer to a layer hierarchy, then release
// the view, the layer retains the view to prevent a crash.  This replicates this behaviour for the node abstraction.
@property (nonatomic, strong, readwrite) ASDisplayNode *keepalive_node;
@end

@implementation _ASDisplayView
{
  BOOL _inHitTest;
  BOOL _inPointInside;

  NSArray *_accessibleElements;
  CGRect _lastAccessibleElementsFrame;
}

+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark - NSObject Overrides

// e.g. <MYPhotoNodeView: 0xFFFFFF; node = <MYPhotoNode: 0xFFFFFE>; frame = ...>
- (NSString *)description
{
  NSMutableString *description = [[super description] mutableCopy];

  ASDisplayNode *node = _asyncdisplaykit_node;

  if (node != nil) {
    NSString *classString = [NSString stringWithFormat:@"%@-", [node class]];
    [description replaceOccurrencesOfString:@"_ASDisplay" withString:classString options:kNilOptions range:NSMakeRange(0, description.length)];
    NSUInteger semicolon = [description rangeOfString:@";"].location;
    if (semicolon != NSNotFound) {
      NSString *nodeString = [NSString stringWithFormat:@"; node = %@", node];
      [description insertString:nodeString atIndex:semicolon];
    }
    // Remove layer description – it never contains valuable info and it duplicates the node info. Noisy.
    NSRange layerDescriptionRange = [description rangeOfString:@"; layer = <.*>" options:NSRegularExpressionSearch];
    if (layerDescriptionRange.location != NSNotFound) {
      [description replaceCharactersInRange:layerDescriptionRange withString:@""];
      // Our regex will grab the closing angle bracket and I'm not clever enough to come up with a better one, so re-add it if needed.
      if ([description hasSuffix:@">"] == NO) {
        [description appendString:@">"];
      }
    }
  }
  return description;
}

#pragma mark - UIView Overrides

- (void)willMoveToWindow:(UIWindow *)newWindow
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  BOOL visible = (newWindow != nil);
  if (visible && !node.inHierarchy) {
    [node __enterHierarchy];
  }
}

- (void)didMoveToWindow
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  BOOL visible = (self.window != nil);
  if (!visible && node.inHierarchy) {
    [node __exitHierarchy];
  }
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
  // Keep the node alive while the view is in a view hierarchy.  This helps ensure that async-drawing views can always
  // display their contents as long as they are visible somewhere, and aids in lifecycle management because the
  // lifecycle of the node can be treated as the same as the lifecycle of the view (let the view hierarchy own the
  // view).
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  UIView *currentSuperview = self.superview;
  if (!currentSuperview && newSuperview) {
    self.keepalive_node = node;
  }
  
  if (newSuperview) {
    ASDisplayNode *supernode = node.supernode;
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
      // FIXME: Needs rethinking if automaticallyManagesSubnodes=YES
      [newSuperview.asyncdisplaykit_node _addSubnode:node];
    }
  }
}

- (void)didMoveToSuperview
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  UIView *superview = self.superview;
  if (superview == nil) {
    // Clearing keepalive_node may cause deallocation of the node.  In this case, __exitHierarchy may not have an opportunity (e.g. _node will be cleared
    // by the time -didMoveToWindow occurs after this) to clear the Visible interfaceState, which we need to do before deallocation to meet an API guarantee.
    if (node.inHierarchy) {
      [node __exitHierarchy];
    }
    self.keepalive_node = nil;
  }

  ASDisplayNode *supernode = node.supernode;
  ASDisplayNodeAssert(!supernode.isLayerBacked, @"Shouldn't be possible for superview's node to be layer-backed.");
  
  if (supernode) {
    ASDisplayNodeAssertTrue(node.nodeLoaded);
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
      BOOL nodeIsRasterized = ((node.hierarchyState & ASHierarchyStateRasterized) == ASHierarchyStateRasterized);
      needsSupernodeRemoval = (supernodeLoaded && !nodeIsRasterized);
    }
    
    if (needsSupernodeRemoval) {
      // The node will only disconnect from its supernode, not removeFromSuperview, in this condition.
      // FIXME: Needs rethinking if automaticallyManagesSubnodes=YES
      [node _removeFromSupernode];
    }
  }
}

- (void)addSubview:(UIView *)view
{
  [super addSubview:view];
  
#ifndef ASDK_ACCESSIBILITY_DISABLE
  self.accessibleElements = nil;
#endif
}

- (void)willRemoveSubview:(UIView *)subview
{
  [super willRemoveSubview:subview];
  
#ifndef ASDK_ACCESSIBILITY_DISABLE
  self.accessibleElements = nil;
#endif
}

- (CGSize)sizeThatFits:(CGSize)size
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return node ? [node layoutThatFits:ASSizeRangeMake(size)].size : [super sizeThatFits:size];
}

- (void)setNeedsDisplay
{
  ASDisplayNodeAssertMainThread();
  // Standard implementation does not actually get to the layer, at least for views that don't implement drawRect:.
  [self.layer setNeedsDisplay];
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
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  [super setBounds:bounds];
  node.threadSafeBounds = bounds;
}

#pragma mark - Event Handling + UIResponder Overrides
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (node.methodOverrides & ASDisplayNodeMethodOverrideTouchesBegan) {
    [node touchesBegan:touches withEvent:event];
  } else {
    [super touchesBegan:touches withEvent:event];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (node.methodOverrides & ASDisplayNodeMethodOverrideTouchesMoved) {
    [node touchesMoved:touches withEvent:event];
  } else {
    [super touchesMoved:touches withEvent:event];
  }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (node.methodOverrides & ASDisplayNodeMethodOverrideTouchesEnded) {
    [node touchesEnded:touches withEvent:event];
  } else {
    [super touchesEnded:touches withEvent:event];
  }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (node.methodOverrides & ASDisplayNodeMethodOverrideTouchesCancelled) {
    [node touchesCancelled:touches withEvent:event];
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
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (!_inHitTest) {
    _inHitTest = YES;
    UIView *hitView = [node hitTest:point withEvent:event];
    _inHitTest = NO;
    return hitView;
  } else {
    return [super hitTest:point withEvent:event];
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  // See comments in -hitTest:withEvent: for the strategy here.
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  if (!_inPointInside) {
    _inPointInside = YES;
    BOOL result = [node pointInside:point withEvent:event];
    _inPointInside = NO;
    return result;
  } else {
    return [super pointInside:point withEvent:event];
  }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_6_0
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node gestureRecognizerShouldBegin:gestureRecognizer];
}
#endif

- (void)tintColorDidChange
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  [super tintColorDidChange];
  
  [node tintColorDidChange];
}

- (BOOL)canBecomeFirstResponder {
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node canBecomeFirstResponder];
}

- (BOOL)canResignFirstResponder {
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node canResignFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  // We forward responder-chain actions to our node if we can't handle them ourselves. See -targetForAction:withSender:.
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return ([super canPerformAction:action withSender:sender] || [node respondsToSelector:action]);
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  // Ideally, we would implement -targetForAction:withSender: and simply return the node where we don't respond personally.
  // Unfortunately UIResponder's default implementation of -targetForAction:withSender: doesn't follow its own documentation. It doesn't call -targetForAction:withSender: up the responder chain when -canPerformAction:withSender: fails, but instead merely calls -canPerformAction:withSender: on itself and then up the chain. rdar://20111500.
  // Consequently, to forward responder-chain actions to our node, we override -canPerformAction:withSender: (used by the chain) to indicate support for responder chain-driven actions that our node supports, and then provide the node as a forwarding target here.
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return node;
}

#if TARGET_OS_TV
#pragma mark - tvOS
- (BOOL)canBecomeFocused
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node canBecomeFocused];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
}

- (void)setNeedsFocusUpdate
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node setNeedsFocusUpdate];
}

- (void)updateFocusIfNeeded
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node updateFocusIfNeeded];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node shouldUpdateFocusInContext:context];
}

- (UIView *)preferredFocusedView
{
  ASDisplayNode *node = _asyncdisplaykit_node; // Create strong reference to weak ivar.
  return [node preferredFocusedView];
}
#endif
@end

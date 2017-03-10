//
//  ASControlNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASControlNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASControlTargetAction.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASThread.h>

// UIControl allows dragging some distance outside of the control itself during
// tracking. This value depends on the device idiom (25 or 70 points), so
// so replicate that effect with the same values here for our own controls.
#define kASControlNodeExpandedInset (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? -25.0f : -70.0f)

// Initial capacities for dispatch tables.
#define kASControlNodeEventDispatchTableInitialCapacity 4
#define kASControlNodeActionDispatchTableInitialCapacity 4

@interface ASControlNode ()
{
@private
  ASDN::RecursiveMutex _controlLock;
  
  // Control Attributes
  BOOL _enabled;
  BOOL _highlighted;

  // Tracking
  BOOL _tracking;
  BOOL _touchInside;

  // Target action pairs stored in an array for each event type
  // ASControlEvent -> [ASTargetAction0, ASTargetAction1]
  NSMutableDictionary<id<NSCopying>, NSMutableArray<ASControlTargetAction *> *> *_controlEventDispatchTable;
}

// Read-write overrides.
@property (nonatomic, readwrite, assign, getter=isTracking) BOOL tracking;
@property (nonatomic, readwrite, assign, getter=isTouchInside) BOOL touchInside;

/**
  @abstract Returns a key to be used in _controlEventDispatchTable that identifies the control event.
  @param controlEvent A control event.
  @result A key for use in _controlEventDispatchTable.
 */
id<NSCopying> _ASControlNodeEventKeyForControlEvent(ASControlNodeEvent controlEvent);

/**
  @abstract Enumerates the ASControlNode events included mask, invoking the block for each event.
  @param mask An ASControlNodeEvent mask.
  @param block The block to be invoked for each ASControlNodeEvent included in mask.
 */
void _ASEnumerateControlEventsIncludedInMaskWithBlock(ASControlNodeEvent mask, void (^block)(ASControlNodeEvent anEvent));

/**
 @abstract Returns the expanded bounds used to determine if a touch is considered 'inside' during tracking.
 @param controlNode A control node.
 @result The expanded bounds of the node.
 */
CGRect _ASControlNodeGetExpandedBounds(ASControlNode *controlNode);


@end

@implementation ASControlNode
{
  ASImageNode *_debugHighlightOverlay;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _enabled = YES;

  // As we have no targets yet, we start off with user interaction off. When a target is added, it'll get turned back on.
  self.userInteractionEnabled = NO;
  
  return self;
}

#if TARGET_OS_TV
- (void)didLoad
{
  // On tvOS all controls, such as buttons, interact with the focus system even if they don't have a target set on them.
  // Here we add our own internal tap gesture to handle this behaviour.
  self.userInteractionEnabled = YES;
  UITapGestureRecognizer *tapGestureRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pressDown)];
  tapGestureRec.allowedPressTypes = @[@(UIPressTypeSelect)];
  [self.view addGestureRecognizer:tapGestureRec];
}
#endif

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled
{
  [super setUserInteractionEnabled:userInteractionEnabled];
  self.isAccessibilityElement = userInteractionEnabled;
}

- (void)__exitHierarchy
{
  [super __exitHierarchy];
  
  // If a control node is exit the hierarchy and is tracking we have to cancel it
  if (self.tracking) {
    [self _cancelTrackingWithEvent:nil];
  }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

#pragma mark - ASDisplayNode Overrides

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled) {
    return;
  }
  
  // Check if the tracking should start
  UITouch *theTouch = [touches anyObject];
  if (![self beginTrackingWithTouch:theTouch withEvent:event]) {
    return;
  }

  // If we get more than one touch down on us, cancel.
  // Additionally, if we're already tracking a touch, a second touch beginning is cause for cancellation.
  if (touches.count > 1 || self.tracking) {
    [self _cancelTrackingWithEvent:event];
  } else {
    // Otherwise, begin tracking.
    self.tracking = YES;

    // No need to check bounds on touchesBegan as we wouldn't get the call if it wasn't in our bounds.
    self.touchInside = YES;
    self.highlighted = YES;

    // Send the appropriate touch-down control event depending on how many times we've been tapped.
    ASControlNodeEvent controlEventMask = (theTouch.tapCount == 1) ? ASControlNodeEventTouchDown : ASControlNodeEventTouchDownRepeat;
    [self sendActionsForControlEvents:controlEventMask withEvent:event];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled) {
    return;
  }

  NSParameterAssert(touches.count == 1);
  UITouch *theTouch = [touches anyObject];
  
  // Check if tracking should continue
  if (!self.tracking || ![self continueTrackingWithTouch:theTouch withEvent:event]) {
    self.tracking = NO;
    return;
  }
  
  CGPoint touchLocation = [theTouch locationInView:self.view];

  // Update our touchInside state.
  BOOL dragIsInsideBounds = [self pointInside:touchLocation withEvent:nil];

  // Update our highlighted state.
  CGRect expandedBounds = _ASControlNodeGetExpandedBounds(self);
  BOOL dragIsInsideExpandedBounds = CGRectContainsPoint(expandedBounds, touchLocation);
  self.touchInside = dragIsInsideExpandedBounds;
  self.highlighted = dragIsInsideExpandedBounds;

  [self sendActionsForControlEvents:(dragIsInsideBounds ? ASControlNodeEventTouchDragInside : ASControlNodeEventTouchDragOutside)
                          withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled) {
    return;
  }

  // Note that we've cancelled tracking.
  [self _cancelTrackingWithEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled) {
    return;
  }

  // On iPhone 6s, iOS 9.2 (and maybe other versions) sometimes calls -touchesEnded:withEvent:
  // twice on the view for one call to -touchesBegan:withEvent:. On ASControlNode, it used to
  // trigger an action twice unintentionally. Now, we ignore that event if we're not in a tracking
  // state in order to have a correct behavior.
  // It might be related to that issue: http://www.openradar.me/22910171
  if (!self.tracking) {
    return;
  }

  NSParameterAssert([touches count] == 1);
  UITouch *theTouch = [touches anyObject];
  CGPoint touchLocation = [theTouch locationInView:self.view];

  // Update state.
  self.tracking = NO;
  self.touchInside = NO;
  self.highlighted = NO;

  // Note that we've ended tracking.
  [self endTrackingWithTouch:theTouch withEvent:event];

  // Send the appropriate touch-up control event.
  CGRect expandedBounds = _ASControlNodeGetExpandedBounds(self);
  BOOL touchUpIsInsideExpandedBounds = CGRectContainsPoint(expandedBounds, touchLocation);

  [self sendActionsForControlEvents:(touchUpIsInsideExpandedBounds ? ASControlNodeEventTouchUpInside : ASControlNodeEventTouchUpOutside)
                          withEvent:event];
}

- (void)_cancelTrackingWithEvent:(UIEvent *)event
{
  // We're no longer tracking and there is no touch to be inside.
  self.tracking = NO;
  self.touchInside = NO;
  self.highlighted = NO;
  
  // Send the cancel event.
  [self sendActionsForControlEvents:ASControlNodeEventTouchCancel withEvent:event];
}

#pragma clang diagnostic pop

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();

  // If not enabled we should not care about receving touches
  if (! self.enabled) {
    return nil;
  }

  return [super hitTest:point withEvent:event];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  // If we're interested in touches, this is a tap (the only gesture we care about) and passed -hitTest for us, then no, you may not begin. Sir.
  if (self.enabled && [gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] && gestureRecognizer.view != self.view) {
    UITapGestureRecognizer *tapRecognizer = (UITapGestureRecognizer *)gestureRecognizer;
    // Allow double-tap gestures
    return tapRecognizer.numberOfTapsRequired != 1;
  }

  // Otherwise, go ahead. :]
  return YES;
}

#pragma mark - Action Messages

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(ASControlNodeEvent)controlEventMask
{
  NSParameterAssert(action);
  NSParameterAssert(controlEventMask != 0);
  
  // ASControlNode cannot be layer backed if adding a target
  ASDisplayNodeAssert(!self.isLayerBacked, @"ASControlNode is layer backed, will never be able to call target in target:action: pair.");
  
  ASDN::MutexLocker l(_controlLock);

  if (!_controlEventDispatchTable) {
    _controlEventDispatchTable = [[NSMutableDictionary alloc] initWithCapacity:kASControlNodeEventDispatchTableInitialCapacity]; // enough to handle common types without re-hashing the dictionary when adding entries.
    
    // only show tap-able areas for views with 1 or more addTarget:action: pairs
    if ([ASControlNode enableHitTestDebug] && _debugHighlightOverlay == nil) {
      ASPerformBlockOnMainThread(^{
        // add a highlight overlay node with area of ASControlNode + UIEdgeInsets
        self.clipsToBounds = NO;
        _debugHighlightOverlay = [[ASImageNode alloc] init];
        _debugHighlightOverlay.zPosition = 1000;  // ensure we're over the top of any siblings
        _debugHighlightOverlay.layerBacked = YES;
        [self addSubnode:_debugHighlightOverlay];
      });
    }
  }
  
  // Create new target action pair
  ASControlTargetAction *targetAction = [[ASControlTargetAction alloc] init];
  targetAction.action = action;
  targetAction.target = target;

  // Enumerate the events in the mask, adding the target-action pair for each control event included in controlEventMask
  _ASEnumerateControlEventsIncludedInMaskWithBlock(controlEventMask, ^
    (ASControlNodeEvent controlEvent)
    {
      // Do we already have an event table for this control event?
      id<NSCopying> eventKey = _ASControlNodeEventKeyForControlEvent(controlEvent);
      NSMutableArray *eventTargetActionArray = _controlEventDispatchTable[eventKey];
      
      if (!eventTargetActionArray) {
        eventTargetActionArray = [[NSMutableArray alloc] init];
      }
      
      // Remove any prior target-action pair for this event, as UIKit does.
      [eventTargetActionArray removeObject:targetAction];
      
      // Register the new target-action as the last one to be sent.
      [eventTargetActionArray addObject:targetAction];
      
      if (eventKey) {
        [_controlEventDispatchTable setObject:eventTargetActionArray forKey:eventKey];
      }
    });

  self.userInteractionEnabled = YES;
}

- (NSArray *)actionsForTarget:(id)target forControlEvent:(ASControlNodeEvent)controlEvent
{
  NSParameterAssert(target);
  NSParameterAssert(controlEvent != 0 && controlEvent != ASControlNodeEventAllEvents);

  ASDN::MutexLocker l(_controlLock);
  
  // Grab the event target action array for this event.
  NSMutableArray *eventTargetActionArray = _controlEventDispatchTable[_ASControlNodeEventKeyForControlEvent(controlEvent)];
  if (!eventTargetActionArray) {
    return nil;
  }

  NSMutableArray *actions = [[NSMutableArray alloc] init];
  
  // Collect all actions for this target.
  for (ASControlTargetAction *targetAction in eventTargetActionArray) {
    if ((target == nil && targetAction.createdWithNoTarget) || (target != nil && target == targetAction.target)) {
      [actions addObject:NSStringFromSelector(targetAction.action)];
    }
  }
  
  return actions;
}

- (NSSet *)allTargets
{
  ASDN::MutexLocker l(_controlLock);
  
  NSMutableSet *targets = [[NSMutableSet alloc] init];

  // Look at each event...
  for (NSMutableArray *eventTargetActionArray in [_controlEventDispatchTable objectEnumerator]) {
    // and each event's targets...
    for (ASControlTargetAction *targetAction in eventTargetActionArray) {
      [targets addObject:targetAction.target];
    }
  }

  return targets;
}

- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(ASControlNodeEvent)controlEventMask
{
  NSParameterAssert(controlEventMask != 0);
  
  ASDN::MutexLocker l(_controlLock);

  // Enumerate the events in the mask, removing the target-action pair for each control event included in controlEventMask.
  _ASEnumerateControlEventsIncludedInMaskWithBlock(controlEventMask, ^
    (ASControlNodeEvent controlEvent)
    {
      // Grab the dispatch table for this event (if we have it).
      id<NSCopying> eventKey = _ASControlNodeEventKeyForControlEvent(controlEvent);
      NSMutableArray *eventTargetActionArray = _controlEventDispatchTable[eventKey];
      if (!eventTargetActionArray) {
        return;
      }
      
      NSPredicate *filterPredicate = [NSPredicate predicateWithBlock:^BOOL(ASControlTargetAction *_Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (!target || evaluatedObject.target == target) {
          if (!action) {
            return NO;
          } else if (evaluatedObject.action == action) {
            return NO;
          }
        }
        
        return YES;
      }];
      [eventTargetActionArray filterUsingPredicate:filterPredicate];
      
      if (eventTargetActionArray.count == 0) {
        // If there are no targets for this event anymore, remove it.
        [_controlEventDispatchTable removeObjectForKey:eventKey];
      }
    });
}

#pragma mark -

- (void)sendActionsForControlEvents:(ASControlNodeEvent)controlEvents withEvent:(UIEvent *)event
{
  NSParameterAssert(controlEvents != 0);
  
  ASDN::MutexLocker l(_controlLock);

  // Enumerate the events in the mask, invoking the target-action pairs for each.
  _ASEnumerateControlEventsIncludedInMaskWithBlock(controlEvents, ^
    (ASControlNodeEvent controlEvent)
    {
      // Use a copy to itereate, the action perform could call remove causing a mutation crash.
      NSMutableArray *eventTargetActionArray = [_controlEventDispatchTable[_ASControlNodeEventKeyForControlEvent(controlEvent)] copy];
      
      // Iterate on each target action pair
      for (ASControlTargetAction *targetAction in eventTargetActionArray) {
        SEL action = targetAction.action;
        id responder = targetAction.target;
        
        // NSNull means that a nil target was set, so start at self and travel the responder chain
        if (!responder && targetAction.createdWithNoTarget) {
          // if the target cannot perform the action, travel the responder chain to try to find something that does
          responder = [self.view targetForAction:action withSender:self];
        }
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [responder performSelector:action withObject:self withObject:event];
#pragma clang diagnostic pop
      }
    });
}

#pragma mark - Convenience

id<NSCopying> _ASControlNodeEventKeyForControlEvent(ASControlNodeEvent controlEvent)
{
  return @(controlEvent);
}

void _ASEnumerateControlEventsIncludedInMaskWithBlock(ASControlNodeEvent mask, void (^block)(ASControlNodeEvent anEvent))
{
  if (block == nil) {
    return;
  }
  // Start with our first event (touch down) and work our way up to the last event (PrimaryActionTriggered)
  for (ASControlNodeEvent thisEvent = ASControlNodeEventTouchDown; thisEvent <= ASControlNodeEventPrimaryActionTriggered; thisEvent <<= 1) {
    // If it's included in the mask, invoke the block.
    if ((mask & thisEvent) == thisEvent)
      block(thisEvent);
  }
}

CGRect _ASControlNodeGetExpandedBounds(ASControlNode *controlNode) {
  return CGRectInset(UIEdgeInsetsInsetRect(controlNode.view.bounds, controlNode.hitTestSlop), kASControlNodeExpandedInset, kASControlNodeExpandedInset);
}

#pragma mark - For Subclasses

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)touchEvent
{
  return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)touchEvent
{
  return YES;
}

- (void)cancelTrackingWithEvent:(UIEvent *)touchEvent
{
  // Subclass hook
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)touchEvent
{
  // Subclass hook
}

#pragma mark - Debug
- (ASImageNode *)debugHighlightOverlay
{
  return _debugHighlightOverlay;
}
@end

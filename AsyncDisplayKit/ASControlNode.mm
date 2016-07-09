//
//  ASControlNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASControlNode.h"
#import "ASControlNode+Subclasses.h"
#import "ASImageNode.h"
#import "AsyncDisplayKit+Debug.h"
#import "ASInternalHelpers.h"

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

  // Target Messages.
  /*
     The table structure is as follows:

   {
    AnEvent -> {
                  target1 -> (action1, ...)
                  target2 -> (action1, ...)
                  ...
               }
    ...
   }
   */
  NSMutableDictionary *_controlEventDispatchTable;
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
  @param anEvent An even that is included in mask.
 */
void _ASEnumerateControlEventsIncludedInMaskWithBlock(ASControlNodeEvent mask, void (^block)(ASControlNodeEvent anEvent));

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


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

#pragma mark - ASDisplayNode Overrides
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled)
    return;

  ASControlNodeEvent controlEventMask = 0;

  // If we get more than one touch down on us, cancel.
  // Additionally, if we're already tracking a touch, a second touch beginning is cause for cancellation.
  if ([touches count] > 1 || self.tracking)
  {
    self.tracking = NO;
    self.touchInside = NO;
    [self cancelTrackingWithEvent:event];
    controlEventMask |= ASControlNodeEventTouchCancel;
  }
  else
  {
    // Otherwise, begin tracking.
    self.tracking = YES;

    // No need to check bounds on touchesBegan as we wouldn't get the call if it wasn't in our bounds.
    self.touchInside = YES;
    self.highlighted = YES;

    UITouch *theTouch = [touches anyObject];
    [self beginTrackingWithTouch:theTouch withEvent:event];

    // Send the appropriate touch-down control event depending on how many times we've been tapped.
    controlEventMask |= (theTouch.tapCount == 1) ? ASControlNodeEventTouchDown : ASControlNodeEventTouchDownRepeat;
  }

  [self sendActionsForControlEvents:controlEventMask withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled)
    return;

  NSParameterAssert([touches count] == 1);
  UITouch *theTouch = [touches anyObject];
  CGPoint touchLocation = [theTouch locationInView:self.view];

  // Update our touchInside state.
  BOOL dragIsInsideBounds = [self pointInside:touchLocation withEvent:nil];

  // Update our highlighted state.
  CGRect expandedBounds = CGRectInset(self.view.bounds, kASControlNodeExpandedInset, kASControlNodeExpandedInset);
  BOOL dragIsInsideExpandedBounds = CGRectContainsPoint(expandedBounds, touchLocation);
  self.touchInside = dragIsInsideExpandedBounds;
  self.highlighted = dragIsInsideExpandedBounds;

  // Note we are continuing to track the touch.
  [self continueTrackingWithTouch:theTouch withEvent:event];

  [self sendActionsForControlEvents:(dragIsInsideBounds ? ASControlNodeEventTouchDragInside : ASControlNodeEventTouchDragOutside)
                          withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled)
    return;

  // We're no longer tracking and there is no touch to be inside.
  self.tracking = NO;
  self.touchInside = NO;
  self.highlighted = NO;

  // Note that we've cancelled tracking.
  [self cancelTrackingWithEvent:event];

  // Send the cancel event.
  [self sendActionsForControlEvents:ASControlNodeEventTouchCancel
                          withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  // If we're not interested in touches, we have nothing to do.
  if (!self.enabled)
    return;

  // On iPhone 6s, iOS 9.2 (and maybe other versions) sometimes calls -touchesEnded:withEvent:
  // twice on the view for one call to -touchesBegan:withEvent:. On ASControlNode, it used to
  // trigger an action twice unintentionally. Now, we ignore that event if we're not in a tracking
  // state in order to have a correct behavior.
  // It might be related to that issue: http://www.openradar.me/22910171
  if (!self.tracking)
    return;

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
  CGRect expandedBounds = CGRectInset(self.view.bounds, kASControlNodeExpandedInset, kASControlNodeExpandedInset);
  BOOL touchUpIsInsideExpandedBounds = CGRectContainsPoint(expandedBounds, touchLocation);

  [self sendActionsForControlEvents:(touchUpIsInsideExpandedBounds ? ASControlNodeEventTouchUpInside : ASControlNodeEventTouchUpOutside)
                          withEvent:event];
}

#pragma clang diagnostic pop

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
  
  ASDN::MutexLocker l(_controlLock);
  
  // Convert nil to [NSNull null] so that it can be used as a key for NSMapTable.
  if (!target)
    target = [NSNull null];

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

  // Enumerate the events in the mask, adding the target-action pair for each control event included in controlEventMask
  _ASEnumerateControlEventsIncludedInMaskWithBlock(controlEventMask, ^
    (ASControlNodeEvent controlEvent)
    {
      // Do we already have an event table for this control event?
      id<NSCopying> eventKey = _ASControlNodeEventKeyForControlEvent(controlEvent);
      NSMapTable *eventDispatchTable = _controlEventDispatchTable[eventKey];
      // Create it if necessary.
      if (!eventDispatchTable)
      {
        // Create the dispatch table for this event.
        eventDispatchTable = [NSMapTable weakToStrongObjectsMapTable];
        _controlEventDispatchTable[eventKey] = eventDispatchTable;
      }

      // Have we seen this target before for this event?
      NSMutableSet *targetActions = [eventDispatchTable objectForKey:target];
      if (!targetActions)
      {
        // Nope. Create an action set for it.
        targetActions = [[NSMutableSet alloc] initWithCapacity:kASControlNodeActionDispatchTableInitialCapacity]; // enough to handle common types without re-hashing the dictionary when adding entries.
        [eventDispatchTable setObject:targetActions forKey:target];
      }

      // Add the action message.
      // UIControl does not support duplicate target-action-events entries, so we replicate that behavior.
      // See: https://github.com/facebook/AsyncDisplayKit/files/205466/DuplicateActionsTest.playground.zip
      [targetActions addObject:NSStringFromSelector(action)];
    });

  self.userInteractionEnabled = YES;
}

- (NSArray *)actionsForTarget:(id)target forControlEvent:(ASControlNodeEvent)controlEvent
{
  NSParameterAssert(target);
  NSParameterAssert(controlEvent != 0 && controlEvent != ASControlNodeEventAllEvents);

  ASDN::MutexLocker l(_controlLock);
  
  // Grab the event dispatch table for this event.
  NSMapTable *eventDispatchTable = _controlEventDispatchTable[_ASControlNodeEventKeyForControlEvent(controlEvent)];
  if (!eventDispatchTable)
    return nil;

  // Return the actions for this target.
  return [eventDispatchTable objectForKey:target];
}

- (NSSet *)allTargets
{
  ASDN::MutexLocker l(_controlLock);
  
  NSMutableSet *targets = [[NSMutableSet alloc] init];

  // Look at each event...
  for (NSMapTable *eventDispatchTable in [_controlEventDispatchTable allValues])
  {
    // and each event's targets...
    for (id target in eventDispatchTable)
      [targets addObject:target];
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
      NSMapTable *eventDispatchTable = _controlEventDispatchTable[eventKey];
      if (!eventDispatchTable)
        return;

      void (^removeActionFromTarget)(id <NSCopying> targetKey, SEL action) = ^
        (id aTarget, SEL theAction)
        {
          // Grab the targetActions for this target.
          NSMutableArray *targetActions = [eventDispatchTable objectForKey:aTarget];

          // Remove action if we have it.
          if (theAction)
            [targetActions removeObject:NSStringFromSelector(theAction)];
          // Or all actions if not.
          else
            [targetActions removeAllObjects];

          // If there are no actions left, remove this target entry.
          if ([targetActions count] == 0)
          {
            [eventDispatchTable removeObjectForKey:aTarget];

            // If there are no targets for this event anymore, remove it.
            if ([eventDispatchTable count] == 0)
              [_controlEventDispatchTable removeObjectForKey:eventKey];
          }
        };


      // Unlike addTarget:, if target is nil here we remove all targets with action.
      if (!target)
      {
        // Look at every target, removing target-pairs that have action (or all of its actions).
        for (id aTarget in [eventDispatchTable copy])
          removeActionFromTarget(aTarget, action);
      }
      else
        removeActionFromTarget(target, action);
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
      NSMapTable *eventDispatchTable = [_controlEventDispatchTable[_ASControlNodeEventKeyForControlEvent(controlEvent)] copy];

      // For each target interested in this event...
      for (id target in eventDispatchTable)
      {
        NSArray *targetActions = [eventDispatchTable objectForKey:target];

        // Invoke each of the actions on target.
        for (NSString *actionMessage in targetActions)
        {
          SEL action = NSSelectorFromString(actionMessage);
          id responder = target;

          // NSNull means that a nil target was set, so start at self and travel the responder chain
          if (responder == [NSNull null]) {
            // if the target cannot perform the action, travel the responder chain to try to find something that does
            responder = [self.view targetForAction:action withSender:self];
          }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
          [responder performSelector:action withObject:self withObject:event];
#pragma clang diagnostic pop
        }
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
  // Start with our first event (touch down) and work our way up to the last event (touch cancel)
  for (ASControlNodeEvent thisEvent = ASControlNodeEventTouchDown; thisEvent <= ASControlNodeEventTouchCancel; thisEvent <<= 1)
  {
    // If it's included in the mask, invoke the block.
    if ((mask & thisEvent) == thisEvent)
      block(thisEvent);
  }
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
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)touchEvent
{
}

#pragma mark - Debug
- (ASImageNode *)debugHighlightOverlay
{
  return _debugHighlightOverlay;
}

@end

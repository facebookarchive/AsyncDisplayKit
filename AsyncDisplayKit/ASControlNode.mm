/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASControlNode.h"
#import "ASControlNode+Subclasses.h"
#import "ASThread.h"
#import "ASDisplayNodeExtras.h"
#import "ASImageNode.h"

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

static BOOL _enableHitTestDebug = NO;

@implementation ASControlNode
{
  ASImageNode *_debugHighlightOverlay;
}

#pragma mark - Lifecycle

- (id)init
{
  if (!(self = [super init]))
    return nil;

  _enabled = YES;

  // As we have no targets yet, we start off with user interaction off. When a target is added, it'll get turned back on.
  self.userInteractionEnabled = NO;
  return self;
}

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
    if (_enableHitTestDebug) {
      
      // add a highlight overlay node with area of ASControlNode + UIEdgeInsets
      self.clipsToBounds = NO;
      _debugHighlightOverlay = [[ASImageNode alloc] init];
      _debugHighlightOverlay.zPosition = 1000;  // CALayer doesn't have -moveSublayerToFront, but this will ensure we're over the top of any siblings.
      _debugHighlightOverlay.layerBacked = YES;
      [self addSubnode:_debugHighlightOverlay];
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
// Layout method required when _enableHitTestDebug is enabled.
- (void)layout
{
  [super layout];
  
  if (_debugHighlightOverlay) {
    
    // Even if our parents don't have clipsToBounds set and would allow us to display the debug overlay, UIKit event delivery (hitTest:)
    // will not search sub-hierarchies if one of our parents does not return YES for pointInside:.  In such a scenario, hitTestSlop
    // may not be able to expand the tap target as much as desired without also setting some hitTestSlop on the limiting parents.
    CGRect intersectRect = UIEdgeInsetsInsetRect(self.bounds, [self hitTestSlop]);
    UIRectEdge clippedEdges = UIRectEdgeNone;
    UIRectEdge clipsToBoundsClippedEdges = UIRectEdgeNone;
    CALayer *layer = self.layer;
    CALayer *intersectLayer = layer;
    CALayer *intersectSuperlayer = layer.superlayer;
    
    // Stop climbing if we encounter a UIScrollView, as its offset bounds origin may make it seem like our events will be clipped when
    // scrolling will actually reveal them (because this process will not re-run due to scrolling)
    while (intersectSuperlayer && ![intersectSuperlayer.delegate respondsToSelector:@selector(contentOffset)]) {
      // Get our parent's tappable bounds.  If the parent has an associated node, consider hitTestSlop, as it will extend its pointInside:.
      CGRect parentHitRect = intersectSuperlayer.bounds;
      BOOL parentClipsToBounds = NO;
      
      ASDisplayNode *parentNode = ASLayerToDisplayNode(intersectSuperlayer);
      if (parentNode) {
        UIEdgeInsets parentSlop = [parentNode hitTestSlop];
        
        // if parent has a hitTestSlop as well, we need to account for the fact that events will be routed towards us in that area too.
        if (!UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, parentSlop)) {
          parentClipsToBounds = parentNode.clipsToBounds;
          // if the parent is clipping, this will prevent us from showing the overlay outside that area.
          // in this case, we will make the overlay smaller so that the special highlight to indicate the overlay
          // cannot accurately display the true tappable area is shown.
          if (!parentClipsToBounds) {
            parentHitRect = UIEdgeInsetsInsetRect(parentHitRect, [parentNode hitTestSlop]);
          }
        }
      }
      
      // Convert our current rectangle to parent coordinates, and intersect with the parent's hit rect.
      CGRect intersectRectInParentCoordinates = [intersectSuperlayer convertRect:intersectRect fromLayer:intersectLayer];
      intersectRect = CGRectIntersection(parentHitRect, intersectRectInParentCoordinates);
      if (!CGSizeEqualToSize(parentHitRect.size, intersectRectInParentCoordinates.size)) {
        clippedEdges = [self setEdgesOfIntersectionForChildRect:intersectRectInParentCoordinates
                                                     parentRect:parentHitRect rectEdge:clippedEdges];
        if (parentClipsToBounds) {
          clipsToBoundsClippedEdges = [self setEdgesOfIntersectionForChildRect:intersectRectInParentCoordinates
                                                                    parentRect:parentHitRect rectEdge:clipsToBoundsClippedEdges];
        }
      }

      // Advance up the tree.
      intersectLayer = intersectSuperlayer;
      intersectSuperlayer = intersectLayer.superlayer;
    }
    
    CGRect finalRect = [intersectLayer convertRect:intersectRect toLayer:layer];
    UIColor *fillColor = [[UIColor greenColor] colorWithAlphaComponent:0.4];
  
    // determine if edges are clipped
    if (clippedEdges == UIRectEdgeNone) {
      _debugHighlightOverlay.backgroundColor = fillColor;
    } else {
      const CGFloat borderWidth = 2.0;
      UIColor *borderColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8];
      UIColor *clipsBorderColor = [UIColor colorWithRed:30/255.0 green:90/255.0 blue:50/255.0 alpha:0.7];
      CGRect imgRect = CGRectMake(0, 0, 2.0 * borderWidth + 1.0, 2.0 * borderWidth + 1.0);
      UIGraphicsBeginImageContext(imgRect.size);
      
      [fillColor setFill];
      UIRectFill(imgRect);
      
      [self drawEdgeIfClippedWithEdges:clippedEdges color:clipsBorderColor borderWidth:borderWidth imgRect:imgRect];
      [self drawEdgeIfClippedWithEdges:clipsToBoundsClippedEdges color:borderColor borderWidth:borderWidth imgRect:imgRect];
      
      UIImage *debugHighlightImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
  
      UIEdgeInsets edgeInsets = UIEdgeInsetsMake(borderWidth, borderWidth, borderWidth, borderWidth);
      _debugHighlightOverlay.image = [debugHighlightImage resizableImageWithCapInsets:edgeInsets
                                                                         resizingMode:UIImageResizingModeStretch];
      _debugHighlightOverlay.backgroundColor = nil;
    }
    
    _debugHighlightOverlay.frame = finalRect;
  }
}

- (UIRectEdge)setEdgesOfIntersectionForChildRect:(CGRect)childRect parentRect:(CGRect)parentRect rectEdge:(UIRectEdge)rectEdge
{
  if (childRect.origin.y < parentRect.origin.y) {
    rectEdge |= UIRectEdgeTop;
  }
  if (childRect.origin.x < parentRect.origin.x) {
    rectEdge |= UIRectEdgeLeft;
  }
  if (CGRectGetMaxY(childRect) > CGRectGetMaxY(parentRect)) {
    rectEdge |= UIRectEdgeBottom;
  }
  if (CGRectGetMaxX(childRect) > CGRectGetMaxX(parentRect)) {
    rectEdge |= UIRectEdgeRight;
  }
  
  return rectEdge;
}

- (void)drawEdgeIfClippedWithEdges:(UIRectEdge)rectEdge color:(UIColor *)color borderWidth:(CGFloat)borderWidth imgRect:(CGRect)imgRect
{
  [color setFill];
  
  if (rectEdge & UIRectEdgeTop) {
    UIRectFill(CGRectMake(0.0, 0.0, imgRect.size.width, borderWidth));
  }
  if (rectEdge & UIRectEdgeLeft) {
    UIRectFill(CGRectMake(0.0, 0.0, borderWidth, imgRect.size.height));
  }
  if (rectEdge & UIRectEdgeBottom) {
    UIRectFill(CGRectMake(0.0, imgRect.size.height - borderWidth, imgRect.size.width, borderWidth));
  }
  if (rectEdge & UIRectEdgeRight) {
    UIRectFill(CGRectMake(imgRect.size.width - borderWidth, 0.0, borderWidth, imgRect.size.height));
  }
}

+ (void)setEnableHitTestDebug:(BOOL)enable
{
  _enableHitTestDebug = enable;
}

@end

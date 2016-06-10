//
//  ASControlNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

/**
  @abstract Kinds of events possible for control nodes.
  @discussion These events are identical to their UIControl counterparts.
 */
typedef NS_OPTIONS(NSUInteger, ASControlNodeEvent)
{
  /** A touch-down event in the control node. */
  ASControlNodeEventTouchDown         = 1 << 0,
  /** A repeated touch-down event in the control node; for this event the value of the UITouch tapCount method is greater than one. */
  ASControlNodeEventTouchDownRepeat   = 1 << 1,
  /** An event where a finger is dragged inside the bounds of the control node. */
  ASControlNodeEventTouchDragInside   = 1 << 2,
  /** An event where a finger is dragged just outside the bounds of the control. */
  ASControlNodeEventTouchDragOutside  = 1 << 3,
  /** A touch-up event in the control node where the finger is inside the bounds of the node. */
  ASControlNodeEventTouchUpInside     = 1 << 4,
  /** A touch-up event in the control node where the finger is outside the bounds of the node. */
  ASControlNodeEventTouchUpOutside    = 1 << 5,
  /** A system event canceling the current touches for the control node. */
  ASControlNodeEventTouchCancel       = 1 << 6,
  /** A system event when the Play/Pause button on the Apple TV remote is pressed. */
  ASControlNodeEventPrimaryActionTriggered = 1 << 13,
    
  /** All events, including system events. */
  ASControlNodeEventAllEvents         = 0xFFFFFFFF
};

typedef NS_OPTIONS(NSUInteger, ASControlState) {
    ASControlStateNormal       = 0,
    ASControlStateHighlighted  = 1 << 0,                  // used when ASControlNode isHighlighted is set
    ASControlStateDisabled     = 1 << 1,
    ASControlStateSelected     = 1 << 2,                  // used when ASControlNode isSelected is set
    ASControlStateReserved     = 0xFF000000               // flags reserved for internal framework use
};

/**
  @abstract ASControlNode is the base class for control nodes (such as buttons), or nodes that track touches to invoke targets with action messages.
  @discussion ASControlNode cannot be used directly. It instead defines the common interface and behavior structure for all its subclasses. Subclasses should import "ASControlNode+Subclasses.h" for information on methods intended to be overriden.
 */
@interface ASControlNode : ASDisplayNode

#pragma mark - Control State

/**
  @abstract Indicates whether or not the receiver is enabled.
  @discussion Specify YES to make the control enabled; otherwise, specify NO to make it disabled. The default value is YES. If the enabled state is NO, the control ignores touch events and subclasses may draw differently.
 */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/**
  @abstract Indicates whether or not the receiver is highlighted.
  @discussion This is set automatically when the there is a touch inside the control and removed on exit or touch up. This is different from touchInside in that it includes an area around the control, rather than just for touches inside the control.
 */
@property (nonatomic, assign, getter=isHighlighted) BOOL highlighted;

/**
 @abstract Indicates whether or not the receiver is highlighted.
 @discussion This is set automatically when the receiver is tapped.
 */
@property (nonatomic, assign, getter=isSelected) BOOL selected;

#pragma mark - Tracking Touches
/**
  @abstract Indicates whether or not the receiver is currently tracking touches related to an event.
  @discussion YES if the receiver is tracking touches; NO otherwise.
 */
@property (nonatomic, readonly, assign, getter=isTracking) BOOL tracking;

/**
  @abstract Indicates whether or not a touch is inside the bounds of the receiver.
  @discussion YES if a touch is inside the receiver's bounds; NO otherwise.
 */
@property (nonatomic, readonly, assign, getter=isTouchInside) BOOL touchInside;

#pragma mark - Action Messages
/**
  @abstract Adds a target-action pair for a particular event (or events).
  @param target The object to which the action message is sent. If this is nil, the responder chain is searched for an object willing to respond to the action message. target is not retained.
  @param action A selector identifying an action message. May optionally include the sender and the event as parameters, in that order. May not be NULL.
  @param controlEvents A bitmask specifying the control events for which the action message is sent. May not be 0. See "Control Events" for bitmask constants.
  @discussion You may call this method multiple times, and you may specify multiple target-action pairs for a particular event. Targets are held weakly.
 */
- (void)addTarget:(nullable id)target action:(SEL)action forControlEvents:(ASControlNodeEvent)controlEvents;

/**
  @abstract Returns the actions that are associated with a target and a particular control event.
  @param target The target object. May not be nil.
  @param controlEvent A single constant of type ASControlNodeEvent that specifies a particular user action on the control; for a list of these constants, see "Control Events". May not be 0 or ASControlNodeEventAllEvents.
  @result An array of selector names as NSString objects, or nil if there are no action selectors associated with controlEvent.
 */
- (nullable NSArray<NSString *> *)actionsForTarget:(id)target forControlEvent:(ASControlNodeEvent)controlEvent;

/**
  @abstract Returns all target objects associated with the receiver.
  @result A set of all targets for the receiver. The set may include NSNull to indicate at least one nil target (meaning, the responder chain is searched for a target.)
 */
- (NSSet *)allTargets;

/**
  @abstract Removes a target-action pair for a particular event.
  @param target The target object. Pass nil to remove all targets paired with action and the specified control events.
  @param action A selector identifying an action message. Pass NULL to remove all action messages paired with target.
  @param controlEvents A bitmask specifying the control events associated with target and action. See "Control Events" for bitmask constants. May not be 0.
 */
- (void)removeTarget:(nullable id)target action:(nullable SEL)action forControlEvents:(ASControlNodeEvent)controlEvents;

/**
  @abstract Sends the actions for the control events for a particular event.
  @param controlEvents A bitmask specifying the control events for which to send actions. See "Control Events" for bitmask constants. May not be 0.
  @param event The event which triggered these control actions. May be nil.
 */
- (void)sendActionsForControlEvents:(ASControlNodeEvent)controlEvents withEvent:(nullable UIEvent *)event;
#if TARGET_OS_TV
/**
 @abstract How the node looks when it isn't focused. Exposed here so that subclasses can override.
 */
- (void)setDefaultFocusAppearance;
#endif
@end

NS_ASSUME_NONNULL_END

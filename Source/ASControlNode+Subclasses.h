//
//  ASControlNode+Subclasses.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The subclass header _ASControlNode+Subclasses_ defines methods to be
 * overridden by custom nodes that subclass ASControlNode.
 *
 * These methods should never be called directly by other classes.
 */

@interface ASControlNode (Subclassing)

/**
 @abstract Sends action messages for the given control events.
 @param controlEvents A bitmask whose set flags specify the control events for which action messages are sent. See "Control Events" in ASControlNode.h for bitmask constants.
 @param touchEvent An event object encapsulating the information specific to the user event.
 @discussion ASControlNode implements this method to send all action messages associated with controlEvents. The list of targets is constructed from prior invocations of addTarget:action:forControlEvents:.
 */
- (void)sendActionsForControlEvents:(ASControlNodeEvent)controlEvents withEvent:(nullable UIEvent *)touchEvent;

/**
 @abstract Sent to the control when tracking begins.
 @param touch The touch on the receiving control.
 @param touchEvent An event object encapsulating the information specific to the user event.
 @result YES if the receiver should respond continuously (respond when touch is dragged); NO otherwise.
 */
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(nullable UIEvent *)touchEvent;

/**
 @abstract Sent continuously to the control as it tracks a touch within the control's bounds.
 @param touch The touch on the receiving control.
 @param touchEvent An event object encapsulating the information specific to the user event.
 @result YES if touch tracking should continue; NO otherwise.
 */
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(nullable UIEvent *)touchEvent;

/**
 @abstract Sent to the control when tracking should be cancelled.
 @param touchEvent An event object encapsulating the information specific to the user event. This parameter may be nil, indicating that the cancelation was caused by something other than an event, such as the display node being removed from its supernode.
 */
- (void)cancelTrackingWithEvent:(nullable UIEvent *)touchEvent;

/**
 @abstract Sent to the control when the last touch completely ends, telling it to stop tracking.
 @param touch The touch that ended.
 @param touchEvent An event object encapsulating the information specific to the user event.
 */
- (void)endTrackingWithTouch:(nullable UITouch *)touch withEvent:(nullable UIEvent *)touchEvent;

/**
 @abstract Settable version of highlighted property.
 */
@property (nonatomic, readwrite, assign, getter=isHighlighted) BOOL highlighted;

@end

NS_ASSUME_NONNULL_END

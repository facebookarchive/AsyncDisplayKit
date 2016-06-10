//
//  _ASPendingState.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import "UIView+ASConvenience.h"

/**

 Private header for ASDisplayNode.mm

 _ASPendingState is a proxy for a UIView that has yet to be created.
 In response to its setters, it sets an internal property and a flag that indicates that that property has been set.

 When you want to configure a view from this pending state information, just call -applyToView:
 */

@interface _ASPendingState : NSObject <ASDisplayNodeViewProperties, ASDisplayProperties>

// Supports all of the properties included in the ASDisplayNodeViewProperties protocol

- (void)applyToView:(UIView *)view withSpecialPropertiesHandling:(BOOL)setFrameDirectly;
- (void)applyToLayer:(CALayer *)layer;

+ (_ASPendingState *)pendingViewStateFromLayer:(CALayer *)layer;
+ (_ASPendingState *)pendingViewStateFromView:(UIView *)view;

@property (nonatomic, readonly) BOOL hasSetNeedsLayout;
@property (nonatomic, readonly) BOOL hasSetNeedsDisplay;

@property (nonatomic, readonly) BOOL hasChanges;

- (void)clearChanges;

@end

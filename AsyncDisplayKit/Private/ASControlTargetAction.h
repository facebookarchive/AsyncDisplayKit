//
//  ASControlTargetAction.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

/**
 @abstract ASControlTargetAction stores target action pairs registered for specific ASControlNodeEvent values.
 */
@interface ASControlTargetAction : NSObject

/** 
 The action to be called on the registered target.
 */
@property (nonatomic, readwrite, assign) SEL action;

/**
 Event handler target. The specified action will be called on this object.
 */
@property (nonatomic, readwrite, weak) id target;

/**
 Indicated whether this target was created without a target, so the action should travel up in the responder chain.
 */
@property (nonatomic, readonly) BOOL createdWithNoTarget;

@end

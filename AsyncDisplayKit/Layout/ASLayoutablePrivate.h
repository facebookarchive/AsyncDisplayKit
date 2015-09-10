/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <Foundation/Foundation.h>

@class ASLayoutSpec;
@class ASLayoutOptions;
@protocol ASLayoutable;

@protocol ASLayoutablePrivate <NSObject>

/**
 *  @abstract A display node cannot implement both calculateSizeThatFits: and layoutSpecThatFits:. This
 *  method exists to give the user a chance to wrap an ASLayoutable in an ASLayoutSpec just before it is
 *  added to a parent ASLayoutSpec. For example, if you wanted an ASTextNode that was always inside of an
 *  ASInsetLayoutSpec, you could subclass ASTextNode and implement finalLayoutable so that it wraps
 *  self in an inset spec.
 *
 *  Note that any ASLayoutable other than self that is returned MUST set isFinalLayoutable to YES BEFORE
 *  adding a child.
 *
 *  @return The layoutable that will be added to the parent layout spec. Defaults to self.
 */
- (id<ASLayoutable>)finalLayoutable;

/**
 *  A flag to indicate that this ASLayoutable was created in finalLayoutable. This MUST be set to YES
 *  before adding a child to this layoutable.
 */
@property (nonatomic, assign) BOOL isFinalLayoutable;

@property (nonatomic, strong, readonly) ASLayoutOptions *layoutOptions;
@end

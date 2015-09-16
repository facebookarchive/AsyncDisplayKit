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

/**
 *  The base protocol for ASLayoutable. Generally the methods/properties in this class do not need to be
 *  called by the end user and are only called internally. However, there may be a case where the methods are useful.
 */
@protocol ASLayoutablePrivate <NSObject>

/**
 *  @abstract This method can be used to give the user a chance to wrap an ASLayoutable in an ASLayoutSpec 
 *  just before it is added to a parent ASLayoutSpec. For example, if you wanted an ASTextNode that was always 
 *  inside of an ASInsetLayoutSpec, you could subclass ASTextNode and implement finalLayoutable so that it wraps
 *  itself in an inset spec.
 *
 *  Note that any ASLayoutable other than self that is returned MUST set isFinalLayoutable to YES. Make sure
 *  to do this BEFORE adding a child to the ASLayoutable.
 *
 *  @return The layoutable that will be added to the parent layout spec. Defaults to self.
 */
- (id<ASLayoutable>)finalLayoutable;

/**
 *  A flag to indicate that this ASLayoutable was created in finalLayoutable. This MUST be set to YES
 *  before adding a child to this layoutable.
 */
@property (nonatomic, assign) BOOL isFinalLayoutable;


/**
 *  The class that holds all of the layoutOptions set on an ASLayoutable.
 */
@property (nonatomic, strong, readonly) ASLayoutOptions *layoutOptions;
@end

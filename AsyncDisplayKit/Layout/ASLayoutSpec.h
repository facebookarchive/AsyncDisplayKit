/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutable.h>

/** A layout spec is an immutable object that describes a layout, loosely inspired by React. */
@interface ASLayoutSpec : NSObject <ASLayoutable>

/** 
 Creation of a layout spec should only happen by a user in layoutSpecThatFits:. During that method, a
 layout spec can be created and mutated. Once it is passed back to ASDK, the isMutable flag will be 
 set to NO and any further mutations will cause an assert.
 */
@property (nonatomic, assign) BOOL isMutable;

- (instancetype)init;

/**
 *  Set child methods
 *
 *  Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 *  reponsibility of holding on to the spec children. For a layout spec like ASInsetLayoutSpec that
 *  only requires a single child, the child can be added by calling setChild:.
 *
 *  For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 *  a subclass should use the setChild to set the "primary" child. It can then use setChild:forIdentifier:
 *  to set any other required children. Ideally a subclass would hide this from the user, and use the
 *  setChildWithIdentifier: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 *  property that behind the scenes is calling setChild:forIdentifier:.
 *
 *  Finally, a layout spec like ASStackLayoutSpec can take an unknown number of children. In this case, 
 *  the setChildren: method should be used. For good measure, in these layout specs it probably makes
 *  sense to define setChild: to do something appropriate or to assert.
 */
- (void)setChild:(id<ASLayoutable>)child;
- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier;
- (void)setChildren:(NSArray *)children;

/**
 *  Get child methods
 *
 *  There is a corresponding "getChild" method for the above "setChild" methods.  If a subclass
 *  has extra layoutable children, it is recommended to make a corresponding get method for that 
 *  child. For example, the ASBackgroundLayoutSpec responds to backgroundChild.
 *
 *  If a get method is called on a spec that doesn't make sense, then the standard is to assert. 
 *  For example, calling children on an ASInsetLayoutSpec will assert.
 */
- (id<ASLayoutable>)child;
- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier;
- (NSArray *)children;

@end

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
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>

/** A layout spec is an immutable object that describes a layout, loosely inspired by React. */
@interface ASLayoutSpec : NSObject <ASLayoutable>

/** 
 * Creation of a layout spec should only happen by a user in layoutSpecThatFits:. During that method, a
 * layout spec can be created and mutated. Once it is passed back to ASDK, the isMutable flag will be
 * set to NO and any further mutations will cause an assert.
 */
@property (nonatomic, assign) BOOL isMutable;

- (instancetype)init;

/**
 * Adds a child to this layout spec using a default identifier.
 *
 * @param child A child to be added.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * reponsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass should use this method to set the "primary" child. It can then use setChild:forIdentifier:
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:forIdentifier: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 * property that behind the scenes is calling setChild:forIdentifier:.
 */
- (void)setChild:(id<ASLayoutable>)child;

/**
 * Adds a child with the given identifier to this layout spec.
 *
 * @param child A child to be added.
 *
 * @param identifier An identifier associated with the child.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * reponsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass should use the setChild method to set the "primary" child. It can then use this method
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:forIdentifier: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 * property that behind the scenes is calling setChild:forIdentifier:.
 */
- (void)setChild:(id<ASLayoutable>)child forIdentifier:(NSString *)identifier;

/**
 * Adds childen to this layout spec.
 *
 * @param children An array of ASLayoutable children to be added.
 * 
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * reponsibility of holding on to the spec children. Some layout specs, like ASStackLayoutSpec,
 * can take an unknown number of children. In this case, the this method should be used.
 * For good measure, in these layout specs it probably makes sense to define
 * setChild: and setChild:forIdentifier: methods to do something appropriate or to assert.
 */
- (void)setChildren:(NSArray *)children;

/**
 * Get child methods
 *
 * There is a corresponding "getChild" method for the above "setChild" methods.  If a subclass
 * has extra layoutable children, it is recommended to make a corresponding get method for that
 * child. For example, the ASBackgroundLayoutSpec responds to backgroundChild.
 * 
 * If a get method is called on a spec that doesn't make sense, then the standard is to assert.
 * For example, calling children on an ASInsetLayoutSpec will assert.
 */

/** Returns the child added to this layout spec using the default identifier. */
- (id<ASLayoutable>)child;

/**
 * Returns the child added to this layout spec using the given identifier.
 *
 * @param identifier An identifier associated withe the child.
 */
- (id<ASLayoutable>)childForIdentifier:(NSString *)identifier;

/** Returns all children added to this layout spec. */
- (NSArray *)children;
@end

@interface ASLayoutSpec (Debugging) <ASLayoutableAsciiArtProtocol>
/**
 *  Used by other layout specs to create ascii art debug strings
 */
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction;
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName;

@end

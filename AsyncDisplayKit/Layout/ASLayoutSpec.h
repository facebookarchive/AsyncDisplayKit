//
//  ASLayoutSpec.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A layout spec is an immutable object that describes a layout, loosely inspired by React.
 */
@interface ASLayoutSpec : NSObject <ASLayoutElement, ASStackLayoutElement, ASAbsoluteLayoutElement>

/** 
 * Creation of a layout spec should only happen by a user in layoutSpecThatFits:. During that method, a
 * layout spec can be created and mutated. Once it is passed back to ASDK, the isMutable flag will be
 * set to NO and any further mutations will cause an assert.
 */
@property (nonatomic, assign) BOOL isMutable;

/**
 * Parent of the layout spec
 */
@property (nullable, nonatomic, weak) id<ASLayoutElement> parent;

/**
 * Adds a child to this layout spec using a default identifier.
 *
 * @param child A child to be added.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * responsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass should use this method to set the "primary" child. It can then use setChild:forIdentifier:
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:forIdentifier: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 * property that behind the scenes is calling setChild:forIdentifier:.
 */
@property (nullable, strong, nonatomic) id<ASLayoutElement> child;

/**
 * Adds childen to this layout spec.
 *
 * @param children An array of ASLayoutElement children to be added.
 * 
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * reponsibility of holding on to the spec children. Some layout specs, like ASStackLayoutSpec,
 * can take an unknown number of children. In this case, the this method should be used.
 * For good measure, in these layout specs it probably makes sense to define
 * setChild: and setChild:forIdentifier: methods to do something appropriate or to assert.
 */
@property (nullable, strong, nonatomic) NSArray<id<ASLayoutElement>> *children;

@end

/**
 * An ASLayoutSpec subclass that can wrap a ASLayoutElement and calculates the layout of the child.
 */
@interface ASWrapperLayoutSpec : ASLayoutSpec

/*
 * Returns an ASWrapperLayoutSpec object with the given layoutElement as child
 */
+ (instancetype)wrapperWithLayoutElement:(id<ASLayoutElement>)layoutElement AS_WARN_UNUSED_RESULT;

/*
 * Returns an ASWrapperLayoutSpec object initialized with the given layoutElement as child
 */
- (instancetype)initWithLayoutElement:(id<ASLayoutElement>)layoutElement NS_DESIGNATED_INITIALIZER;;

/*
 * Init not available for ASWrapperLayoutSpec
 */
- (instancetype)init __unavailable;

@end

@interface ASLayoutSpec (Debugging) <ASLayoutElementAsciiArtProtocol>
/**
 *  Used by other layout specs to create ascii art debug strings
 */
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName direction:(ASStackLayoutDirection)direction;
+ (NSString *)asciiArtStringForChildren:(NSArray *)children parentName:(NSString *)parentName;

@end

NS_ASSUME_NONNULL_END

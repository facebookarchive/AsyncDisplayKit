//
//  ASLayoutSpec+Subclasses.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 9/15/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASLayout.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASLayoutElement;

@interface ASLayoutSpec (Subclassing)

/**
 * Helper method for finalLayoutElement support
 *
 * @warning If you are getting recursion crashes here after implementing finalLayoutElement, make sure
 * that you are setting isFinalLayoutElement flag to YES. This must be one BEFORE adding a child
 * to the new ASLayoutElement.
 *
 * For example:
 * - (id<ASLayoutElement>)finalLayoutElement
 * {
 *   ASInsetLayoutSpec *insetSpec = [[ASInsetLayoutSpec alloc] init];
 *   insetSpec.insets = UIEdgeInsetsMake(10,10,10,10);
 *   insetSpec.isFinalLayoutElement = YES;
 *   [insetSpec setChild:self];
 *   return insetSpec;
 * }
 *
 * @see finalLayoutElement
 */
- (id<ASLayoutElement>)layoutElementToAddFromLayoutElement:(id<ASLayoutElement>)child;

/**
 * Adds a child with the given identifier to this layout spec.
 *
 * @param child A child to be added.
 *
 * @param index An index associated with the child.
 *
 * @discussion Every ASLayoutSpec must act on at least one child. The ASLayoutSpec base class takes the
 * responsibility of holding on to the spec children. Some layout specs, like ASInsetLayoutSpec,
 * only require a single child.
 *
 * For layout specs that require a known number of children (ASBackgroundLayoutSpec, for example)
 * a subclass can use the setChild method to set the "primary" child. It should then use this method
 * to set any other required children. Ideally a subclass would hide this from the user, and use the
 * setChild:forIndex: internally. For example, ASBackgroundLayoutSpec exposes a backgroundChild
 * property that behind the scenes is calling setChild:forIndex:.
 */
- (void)setChild:(id<ASLayoutElement>)child atIndex:(NSUInteger)index;

/**
 * Returns the child added to this layout spec using the given index.
 *
 * @param index An identifier associated with the the child.
 */
- (nullable id<ASLayoutElement>)childAtIndex:(NSUInteger)index;

@end

@interface ASLayout ()

/**
 * Position in parent. Default to CGPointNull.
 *
 * @discussion When being used as a sublayout, this property must not equal CGPointNull.
 */
@property (nonatomic, assign, readwrite) CGPoint position;

@end

NS_ASSUME_NONNULL_END

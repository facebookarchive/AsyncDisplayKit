/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASContextTransitioning.h"

ASDISPLAYNODE_EXTERN_C_BEGIN
void ASPerformBlockOnMainThread(void (^block)());
void ASPerformBlockOnBackgroundThread(void (^block)()); // DISPATCH_QUEUE_PRIORITY_DEFAULT
ASDISPLAYNODE_EXTERN_C_END

@interface ASDisplayNode (Beta)

+ (BOOL)usesImplicitHierarchyManagement;
+ (void)setUsesImplicitHierarchyManagement:(BOOL)enabled;

/** @name Layout */


/**
 * @abstract Recursively ensures node and all subnodes are displayed.
 * @see Full documentation in ASDisplayNode+FrameworkPrivate.h
 */
- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously;

/**
 * @abstract allow modification of a context before the node's content is drawn
 *
 * @discussion Set the block to be called after the context has been created and before the node's content is drawn.
 * You can override this to modify the context before the content is drawn. You are responsible for saving and
 * restoring context if necessary. Restoring can be done in contextDidDisplayNodeContent
 * This block can be called from *any* thread and it is unsafe to access any UIKit main thread properties from it.
 */
@property (nonatomic, strong) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;

/**
 * @abstract allow modification of a context after the node's content is drawn
 */
@property (nonatomic, strong) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;

/** @name Layout Transitioning */

@property (nonatomic) BOOL usesImplicitHierarchyManagement;

/**
 * @discussion A place to perform your animation. New nodes have been inserted here. You can also use this time to re-order the hierarchy.
 */
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context;

/**
 * @discussion A place to clean up your nodes after the transition
 */
- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context;

/**
 * @abstract Transitions the current layout with a new constrained size.
 *
 * @discussion Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 * If the passed constrainedSize is the the same as the node's current constrained size, this method is noop.
 */
- (ASLayout *)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize animated:(BOOL)animated;

/**
 * @abstract Invalidates the current layout and begins a relayout of the node with the current `constrainedSize`.
 *
 * @discussion Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 */
- (ASLayout *)transitionLayoutWithAnimation:(BOOL)animated;

@end

//
//  ASDisplayNode+Beta.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASContextTransitioning.h"

NS_ASSUME_NONNULL_BEGIN

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
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier willDisplayNodeContentWithRenderingContext;

/**
 * @abstract allow modification of a context after the node's content is drawn
 */
@property (nonatomic, copy, nullable) ASDisplayNodeContextModifier didDisplayNodeContentWithRenderingContext;

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
 * @abstract Transitions the current layout with a new constrained size. Must be called on main thread.
 *
 * @param animated Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 *
 * @param shouldMeasureAsync Measure the layout asynchronously.
 *
 * @param measurementCompletion Optional completion block called only if a new layout is calculated.
 * It is called on main, right after the measurement and before -animateLayoutTransition:.
 *
 * @discussion If the passed constrainedSize is the the same as the node's current constrained size, this method is noop.
 *
 * @see animateLayoutTransition:
 */
- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(nullable void(^)())completion;

/**
 * @abstract Invalidates the current layout and begins a relayout of the node with the current `constrainedSize`. Must be called on main thread.
 *
 * @param animated Animation is optional, but will still proceed through your `animateLayoutTransition` implementation with `isAnimated == NO`.
 *
 * @param shouldMeasureAsync Measure the layout asynchronously.
 *
 * @param measurementCompletion Optional completion block called only if a new layout is calculated.
 * It is called right after the measurement and before -animateLayoutTransition:.
 *
 * @see animateLayoutTransition:
 */
- (void)transitionLayoutWithAnimation:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(nullable void(^)())completion;


/**
 * @abstract Currently used by ASNetworkImageNode and ASMultiplexImageNode to allow their placeholders to stay if they are loading an image from the network.
 * Otherwise, a display pass is scheduled and completes, but does not actually draw anything - and ASDisplayNode considers the element finished.
 */
- (BOOL)placeholderShouldPersist;

/**
 * @abstract Cancels all performing layout transitions. Can be called on any thread.
 */
- (void)cancelLayoutTransitionsInProgress;

/**
 * @abstract Indicates that the receiver and all subnodes have finished displaying. May be called more than once, for example if the receiver has
 * a network image node. This is called after the first display pass even if network image nodes have not downloaded anything (text would be done,
 * and other nodes that are ready to do their final display). Each render of every progressive jpeg network node would cause this to be called, so
 * this hook could be called up to 1 + (pJPEGcount * pJPEGrenderCount) times. The render count depends on how many times the downloader calls the
 * progressImage block.
 */
- (void)hierarchyDisplayDidFinish;

@end

NS_ASSUME_NONNULL_END

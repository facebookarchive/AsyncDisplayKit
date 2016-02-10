//
//  ASContextTransitioning.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>

extern NSString * const ASTransitionContextFromLayoutKey;
extern NSString * const ASTransitionContextToLayoutKey;

@protocol ASContextTransitioning <NSObject>

/**
 @abstreact Defines if the given transition is animated
 */
- (BOOL)isAnimated;

/**
 * @abstract Retrieve either the "from" or "to" layout
 */
- (ASLayout *)layoutForKey:(NSString *)key;

/**
 * @abstract Retrieve either the "from" or "to" constrainedSize
 */
- (ASSizeRange)constrainedSizeForKey:(NSString *)key;

/**
 * @abstract Retrieve the subnodes from either the "from" or "to" layout
 */
- (NSArray<ASDisplayNode *> *)subnodesForKey:(NSString *)key;

/**
 * @abstract Subnodes that have been inserted in the layout transition
 */
- (NSArray<ASDisplayNode *> *)insertedSubnodes;

/**
 * @abstract Subnodes that will be removed in the layout transition
 */
- (NSArray<ASDisplayNode *> *)removedSubnodes;

/**
 @abstract The frame for the given node before the transition began.
 @discussion Returns CGRectNull if the node was not in the hierarchy before the transition.
 */
- (CGRect)initialFrameForNode:(ASDisplayNode *)node;

/**
 @abstract The frame for the given node when the transition completes.
 @discussion Returns CGRectNull if the node is no longer in the hierarchy after the transition.
 */
- (CGRect)finalFrameForNode:(ASDisplayNode *)node;

/**
 @abstract Invoke this method when the transition is completed in `animateLayoutTransition:`
 @discussion Passing NO to `didComplete` will set the original layout as the new layout.
 */
- (void)completeTransition:(BOOL)didComplete;

@end

//
//  ASContextTransitioning.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@protocol ASContextTransitioning <NSObject>

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

- (NSArray<ASLayout *> *)sublayouts;

/**
 @abstract Invoke this method when the transition is completed in `transitionLayout:`
 @discussion Passing NO to `didComplete` will set the original layout as the new layout.
 */
- (void)completeTransition:(BOOL)didComplete;

@end

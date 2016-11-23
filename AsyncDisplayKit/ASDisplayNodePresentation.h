//
//  ASDisplayNodePresentation.h
//  AsyncDisplayKit
//
//  Created by Bussiere, Mathieu on 2015-08-11.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

@class ASDisplayNode;
@class ASDisplayNodeController;
@protocol ASDisplayNodeAnimatedTransitioning <NSObject>
@required
- (void)animateTransitionNodeController:(ASDisplayNodeController *)nodeController containerNode:(ASDisplayNode *)containerNode completion:(void(^)(BOOL))completion;
@end

@protocol ASDisplayNodeTransitioningDelegate <NSObject>
@required
- (id<ASDisplayNodeAnimatedTransitioning>)animationControllerForPresentedNodeController:(ASDisplayNodeController *)presented;
- (id<ASDisplayNodeAnimatedTransitioning>)animationControllerForDismissedNodeController:(ASDisplayNodeController *)dismissed;
@end

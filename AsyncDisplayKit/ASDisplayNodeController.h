/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDisplayNodePresentation.h"

#import "ASDisplayNodeDelegate.h"
#import "ASDisplayNodeContainerDelegate.h"
#import "ASDisplayNode.h"

@interface ASDisplayNodeController : NSObject <ASDisplayNodeDelegate, ASDisplayNodeContainerDelegate>

@property (nonatomic) ASDisplayNode *node;

@property (nonatomic, readonly, weak) ASDisplayNodeController *parentNodeController;
@property (nonatomic, readonly) NSArray *childNodeControllers;
@property (nonatomic, weak) id<ASDisplayNodeContainerDelegate> containerDelegate;
@property (nonatomic, weak) id<ASDisplayNodeTransitioningDelegate> nodeTransitioningDelegate;

@property (nonatomic, readonly) NSMutableSet *pendingAsyncNodes;

- (void)createNode;
- (void)configureNode;

- (BOOL)isNodeCreated;
- (BOOL)isNodeLoaded;

- (void)addChildNodeController:(ASDisplayNodeController *)nodeController;
- (void)addChildNodeController:(ASDisplayNodeController *)nodeController superNode:(ASDisplayNode *)superNode;
- (void)removeFromParentNodeController;

- (void)willMoveToParentNodeController:(ASDisplayNodeController *)parentNodeController;
- (void)didMoveToParentNodeController:(ASDisplayNodeController *)parentNodeController;

- (void)displayStateDidChange:(BOOL)inDisplayState;
- (CGSize)preferredFrameSize;

@end

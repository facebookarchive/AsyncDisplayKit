//
/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDisplayNodeController.h"

@interface ASDisplayNodeController ()
@property (nonatomic) NSMutableArray *childControllers;
@property (nonatomic) ASDisplayNodeController *parentNodeController;
@property (nonatomic) BOOL nodeEnteredNodeHierarchy;
@property (nonatomic) NSMutableSet *pendingAsyncNodes;
@end

@interface ASDisplayNode (Test)
- (void)__setDelegate:(id)test;
@end


@implementation ASDisplayNodeController

- (instancetype)init
{
	self = [super init];

    if(self) {
		self.childControllers = [NSMutableArray array];
        self.pendingAsyncNodes = [NSMutableSet set];
	}
	
    return self;
}

- (ASDisplayNode *)node
{
	if(!_node) {
		[self createNode];
	}
	return _node;
}

#pragma mark - Public methods
- (void)createNode
{
	if(!self.isNodeCreated) {
		self.node = [[ASDisplayNode alloc] init];
	}

    self.node.containerDelegate = self;
    self.node.nodeDelegate = self;
}

- (void)configureNode
{
    // Implement in subclass
}

- (BOOL)isNodeCreated
{
    return _node != nil;
}

- (BOOL)isNodeLoaded
{
    return [self isNodeCreated] && self.node.isNodeLoaded;
}

- (NSArray *)childNodeControllers
{
	return [self.childControllers copy];
}

- (void)addChildNodeController:(ASDisplayNodeController *)nodeController
{
    [self addChildNodeController:nodeController superNode:self.node];
}

- (void)addChildNodeController:(ASDisplayNodeController *)nodeController superNode:(ASDisplayNode *)superNode
{
    @synchronized(_childControllers) {
        [self.childControllers addObject:nodeController];
    }
    
    ASDisplayNode *controllerSuperNode = superNode ?: self.node;
    
    if(controllerSuperNode.layerBacked && !nodeController.node.layerBacked) {
        controllerSuperNode.layerBacked = NO;
    }

    [controllerSuperNode addSubnode:nodeController.node];
    [nodeController didMoveToParentNodeController:self];

    [nodeController recursivelySetContainerDelegate:self];
}

- (void)removeFromParentNodeController
{
	[self willMoveToParentNodeController:nil];
	
    @synchronized(_childControllers) {
        [self.parentNodeController.childControllers removeObject:self];
    }
    
	self.parentNodeController = nil;
	[self.node removeFromSupernode];
	
	[self didMoveToParentNodeController:nil];
}

- (void)willMoveToParentNodeController:(ASDisplayNodeController *)parentNodeController
{
    // Implement in subclass
}

- (void)didMoveToParentNodeController:(ASDisplayNodeController *)parentNodeController
{
    self.parentNodeController = parentNodeController;
}

- (void)displayStateDidChange:(BOOL)inDisplayState
{
    if (!inDisplayState) {
        self.nodeEnteredNodeHierarchy = NO;
        [self.pendingAsyncNodes removeAllObjects];
    }
}

- (CGSize)preferredFrameSize
{
  return CGSizeZero;
}

#pragma mark - ASDisplayNodeContainerDelegate
- (void)nodeContainerWillDisplayNode:(ASDisplayNode *)node
{
    if (!self.nodeEnteredNodeHierarchy) {
        if (self.pendingAsyncNodes.count == 0 && self.containerDelegate) {
            [self.containerDelegate nodeContainerWillDisplayNode:self.node];
        }

        @synchronized(self.pendingAsyncNodes) {
            [self.pendingAsyncNodes addObject:node];
        }
    }
}

- (void)nodeContainerDidDisplayNode:(ASDisplayNode *)node
{
    if (!self.nodeEnteredNodeHierarchy && [self.pendingAsyncNodes containsObject:node]) {
        @synchronized(self.pendingAsyncNodes) {
            [self.pendingAsyncNodes removeObject:node];
        }

        if (self.pendingAsyncDisplayNodesHaveFinished) {
            self.nodeEnteredNodeHierarchy = YES;

            if (self.containerDelegate) {
                [self.containerDelegate nodeContainerDidDisplayNode:self.node];
            }
        }
    }
}

#pragma mark - ASDisplayNodeDelegate

- (void)nodeDidLoad
{
    // Implement in subclass
}

#pragma mark - Private methods
- (void)recursivelySetContainerDelegate:(id<ASDisplayNodeContainerDelegate>)containerDelegate
{
    if (!self.node.displaySuspended) {
        self.node.containerDelegate = containerDelegate;

        for (ASDisplayNodeController *childController in self.childNodeControllers) {
            [childController recursivelySetContainerDelegate:containerDelegate];
        }
    }
}

- (BOOL)pendingAsyncDisplayNodesHaveFinished
{
    return self.pendingAsyncNodes.count == 0;
}

@end

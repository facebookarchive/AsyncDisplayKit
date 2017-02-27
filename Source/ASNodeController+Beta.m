//
//  ASNodeController.mm
//  AsyncDisplayKit
//
//  Created by Hannah Troisi for Scott Goodson on 1/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASNodeController+Beta.h"

#import "ASDisplayNode+FrameworkPrivate.h"

@implementation ASNodeController

@synthesize node = _node;

- (instancetype)init
{
  self = [super init];
  if (self) {
    
  }
  return self;
}

- (void)loadNode
{
  self.node = [[ASDisplayNode alloc] init];
}

- (ASDisplayNode *)node
{
  if (_node == nil) {
    [self loadNode];
  }
  return _node;
}

-(void)setNode:(ASDisplayNode *)node
{
  _node = node;
  _node.interfaceStateDelegate = self;
}

// subclass overrides
- (void)didEnterVisibleState {}
- (void)didExitVisibleState  {}

- (void)didEnterDisplayState {}
- (void)didExitDisplayState  {}

- (void)didEnterPreloadState {}
- (void)didExitPreloadState  {}

- (void)interfaceStateDidChange:(ASInterfaceState)newState
                      fromState:(ASInterfaceState)oldState {}

@end

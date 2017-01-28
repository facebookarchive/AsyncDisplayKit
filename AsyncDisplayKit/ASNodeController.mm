//
//  ASNodeController.mm
//  AsyncDisplayKit
//
//  Created by Hannah Troisi for Scott Goodson on 1/27/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASNodeController.h"

@implementation ASNodeController

- (instancetype)init
{
  self = [super init];
  if (self) {
        
  }
  return self;
}

- (void)loadNode
{
  _node = [[ASDisplayNode alloc] init];
}

- (ASDisplayNode *)node
{
  if (_node == nil) {
    [self loadNode];
  }
  return _node;
}

@end

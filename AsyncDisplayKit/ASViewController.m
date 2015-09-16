//
//  ASViewController.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASViewController.h"
#import "ASAssert.h"
#import "ASDimension.h"

@implementation ASViewController

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (!(self = [super init])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(node, @"Node must not be nil");
  ASDisplayNodeAssertTrue(!node.layerBacked);
  _node = node;
  
  return self;
}

- (void)loadView
{
  ASDisplayNodeAssertTrue(!_node.layerBacked);
  self.view = _node.view;
}

- (void)viewWillLayoutSubviews
{
  ASSizeRange constrainedSize = ASSizeRangeMake(self.view.bounds.size, self.view.bounds.size);
  [_node measureWithSizeRange:constrainedSize];
  [super viewWillLayoutSubviews];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [_node recursivelyFetchData];
}

@end

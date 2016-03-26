//
//  ViewController.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ViewController.h"
#import "PlaygroundContainerNode.h"
#import "ASLayoutableInspectorNode.h"

@interface ViewController () <PlaygroundContainerNodeDelegate, ASLayoutableInspectorNodeDelegate>
@end

@implementation ViewController
{
  ASSizeRange _sizeRange;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  PlaygroundContainerNode *containerNode = [[PlaygroundContainerNode alloc] init];
  self = [super initWithNode:containerNode];
  
  if (self) {
    self.navigationItem.title   = @"ASLayoutSpec Playground";
    self.edgesForExtendedLayout = UIRectEdgeNone;
    containerNode.delegate      = self;
    [ASLayoutableInspectorNode sharedInstance].delegate = self;
  }
  
  return self;
}

// [ASViewController] Override this method to provide a custom size range to the backing node.
// Neccessary to allow the user to stretch / shrink the size of playground container.
- (ASSizeRange)nodeConstrainedSize
{
  if (CGSizeEqualToSize(_sizeRange.max, CGSizeZero)) {
    return [super nodeConstrainedSize];
  }
  return _sizeRange;
}

#pragma mark - PlaygroundContainerNodeDelegate

- (void)relayoutWithSize:(ASSizeRange)size
{
  _sizeRange = size;
  [self.view setNeedsLayout];
}

#pragma mark - ASLayoutableInspectorNodeDelegate

- (void)toggleVizualization:(BOOL)toggle            // FIXME: this doesn't work currently
{
  NSLog(@"shouldVisualizeLayoutSpecs:%d", toggle);
  [self.node shouldVisualizeLayoutSpecs:toggle];
  [self.view setNeedsLayout];
}

@end

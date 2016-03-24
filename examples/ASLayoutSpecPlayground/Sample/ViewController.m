//
//  ViewController.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ViewController.h"
#import "PlaygroundContainerNode.h"
#import "ASDisplayNode+Beta.h" // FIXME?

@interface ViewController () <PlaygroundContainerNodeDelegate>

@end

// Need ASPagerNode, ASCollectionView, ASViewController or ASTableView to implement (calls measure: for you)

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
    self.navigationItem.title = @"ASLayoutSpec Playground";
    
    containerNode.delegate = self;
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [ASLayoutableInspectorNode sharedInstance].delegate = self;
  }
  return self;
}

- (ASSizeRange)nodeConstrainedSize
{
  if (CGSizeEqualToSize(_sizeRange.max, CGSizeZero)) {
    return [super nodeConstrainedSize];
  }
  return _sizeRange;
}

#pragma mark - UISplitViewControllerDelegate

- (void)shouldShowMasterSplitViewController
{
  self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
}


- (void)relayoutWithSize:(ASSizeRange)size
{
  _sizeRange = size;
  [self.view setNeedsLayout];
}

@end

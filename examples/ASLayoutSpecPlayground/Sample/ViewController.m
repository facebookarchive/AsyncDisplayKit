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

@interface ViewController ()

@end

// Need ASPagerNode, ASCollectionView, ASViewController or ASTableView to implement (calls measure: for you)

@implementation ViewController

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super initWithNode:[[PlaygroundContainerNode alloc] init]];
  if (self) {
    self.navigationItem.title = @"ASLayoutSpec Playground";
    [ASLayoutableInspectorNode sharedInstance].delegate = self;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}


#pragma mark - UISplitViewControllerDelegate

- (void)shouldShowMasterSplitViewController
{
  self.splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
}

@end

//
//  ASTabBarController.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 5/10/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASTabBarController.h"

@implementation ASTabBarController
{
  BOOL _parentManagesVisibilityDepth;
  NSInteger _visibilityDepth;
}

ASVisibilityDidMoveToParentViewController;

ASVisibilityViewWillAppear;

ASVisibilityViewDidDisappearImplementation;

ASVisibilitySetVisibilityDepth;

ASVisibilityDepthImplementation;

- (void)visibilityDepthDidChange
{
  for (UIViewController *viewController in self.viewControllers) {
    if ([viewController conformsToProtocol:@protocol(ASVisibilityDepth)]) {
      [(id <ASVisibilityDepth>)viewController visibilityDepthDidChange];
    }
  }
}

- (NSInteger)visibilityDepthOfChildViewController:(UIViewController *)childViewController
{
  if (self.selectedViewController == childViewController) {
    return [self visibilityDepth];
  }
  return [self visibilityDepth] + 1;
}

#pragma mark - UIKit overrides

- (void)setViewControllers:(NSArray<__kindof UIViewController *> *)viewControllers
{
  [super setViewControllers:viewControllers];
  [self visibilityDepthDidChange];
}

- (void)setViewControllers:(NSArray<__kindof UIViewController *> *)viewControllers animated:(BOOL)animated
{
  [super setViewControllers:viewControllers animated:animated];
  [self visibilityDepthDidChange];
}

- (void)setSelectedIndex:(NSUInteger)selectedIndex
{
  [super setSelectedIndex:selectedIndex];
  [self visibilityDepthDidChange];
}

- (void)setSelectedViewController:(__kindof UIViewController *)selectedViewController
{
  [super setSelectedViewController:selectedViewController];
  [self visibilityDepthDidChange];
}

@end

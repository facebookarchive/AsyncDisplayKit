//
//  AppDelegate.m
//  ASDKgram
//
//  Created by Hannah Troisi on 2/16/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "AppDelegate.h"
#import "PhotoFeedViewController.h"
#import "PhotoFeedNodeController.h"
#import "WindowWithStatusBarUnderlay.h"
#import "Utilities.h"

@interface AppDelegate () <UITabBarControllerDelegate>
@end

@implementation AppDelegate
{
  WindowWithStatusBarUnderlay *_window;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  _window                           = [[WindowWithStatusBarUnderlay alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor           = [UIColor whiteColor];
  
  // UIKit Home Feed viewController & navController
  PhotoFeedNodeController *asdkHomeFeedVC     = [[PhotoFeedNodeController alloc] init];
  UINavigationController *asdkHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:asdkHomeFeedVC];
  asdkHomeFeedNavCtrl.tabBarItem              = [[UITabBarItem alloc] initWithTitle:@"ASDK" image:[UIImage imageNamed:@"home"] tag:0];
  asdkHomeFeedNavCtrl.hidesBarsOnSwipe        = YES;
  
  // ASDK Home Feed viewController & navController
  PhotoFeedViewController *uikitHomeFeedVC     = [[PhotoFeedViewController alloc] init];
  UINavigationController *uikitHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:uikitHomeFeedVC];
  uikitHomeFeedNavCtrl.tabBarItem              = [[UITabBarItem alloc] initWithTitle:@"UIKit" image:[UIImage imageNamed:@"home"] tag:0];
  uikitHomeFeedNavCtrl.hidesBarsOnSwipe        = YES;

  // UITabBarController
  UITabBarController *tabBarController    = [[UITabBarController alloc] init];
  tabBarController.viewControllers        = @[uikitHomeFeedNavCtrl, asdkHomeFeedNavCtrl];
  tabBarController.selectedViewController = asdkHomeFeedNavCtrl;
  tabBarController.delegate               = self;
  
  // Nav Bar appearance
  [[UINavigationBar appearance] setBarTintColor:[UIColor darkBlueColor]];
  [[UINavigationBar appearance] setTranslucent:NO];
  NSDictionary *attributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
  [[UINavigationBar appearance] setTitleTextAttributes:attributes];
  // make the status bar have white text (changes after scrolling, but not on initial app startup)
  // UINavigationController does not forward on preferredStatusBarStyle calls to its child view controllers.
  // Instead it manages its own state...http://stackoverflow.com/questions/19022210/preferredstatusbarstyle-isnt-called/19513714#19513714
  uikitHomeFeedNavCtrl.navigationBar.barStyle = UIBarStyleBlack;
  asdkHomeFeedNavCtrl.navigationBar.barStyle  = UIBarStyleBlack;
  
  _window.rootViewController = tabBarController;
  [_window makeKeyAndVisible];
  
  // iOS8 hides the status bar in landscape orientation, this forces the status bar hidden status to NO
  [application setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
  [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
  
  return YES;
}

#pragma mark - UITabBarControllerDelegate

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
  if ([viewController isKindOfClass:[UINavigationController class]]) { 
    NSArray *viewControllers = [(UINavigationController *)viewController viewControllers];
    UIViewController *rootViewController = viewControllers[0];
    if ([rootViewController conformsToProtocol:@protocol(PhotoFeedControllerProtocol)]) {
      // FIXME: the dataModel does not currently handle clearing data during loading properly
//      [(id <PhotoFeedControllerProtocol>)rootViewController resetAllData];
    }
  }
}

@end

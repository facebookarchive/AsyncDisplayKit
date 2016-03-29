//
//  AppDelegate.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/16/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "AppDelegate.h"
#import "PhotoTableViewController.h"
#import "PhotoFeedNodeController.h"
#import "Utilities.h"
#import "AsyncDisplayKit+Debug.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
  // Nav Bar appearance
  [[UINavigationBar appearance] setBarTintColor:[UIColor darkBlueColor]];
  [[UINavigationBar appearance] setTranslucent:NO];
  NSDictionary *attributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
  [[UINavigationBar appearance] setTitleTextAttributes:attributes];

  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];
  UITabBarController *tabBarController    = [[UITabBarController alloc] init];
  self.window.rootViewController          = tabBarController;
  [self.window makeKeyAndVisible];
  
  // create UIKit-powered Home Feed viewController & navController
  PhotoFeedNodeController *asdkPoweredHomeFeedVC = [[PhotoFeedNodeController alloc] init];
  UINavigationController *asdkHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:asdkPoweredHomeFeedVC];
  asdkHomeFeedNavCtrl.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"ASDK" image:[UIImage imageNamed:@"home"] tag:0];
  
  // create ASDK-powered Home Feed viewController & navController
  PhotoTableViewController *uikitPoweredHomeFeedVC = [[PhotoTableViewController alloc] init];
  UINavigationController *uikitHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:uikitPoweredHomeFeedVC];
  uikitHomeFeedNavCtrl.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"UIKit" image:[UIImage imageNamed:@"home"] tag:0];
  
  // UINavigationController does not forward on preferredStatusBarStyle calls to its child view controllers.
  // Instead it manages its own state...
  //http://stackoverflow.com/questions/19022210/preferredstatusbarstyle-isnt-called/19513714#19513714
  uikitHomeFeedNavCtrl.navigationBar.barStyle = UIBarStyleBlack;
  asdkHomeFeedNavCtrl.navigationBar.barStyle = UIBarStyleBlack;
  
  // configure UITabBarController and add viewControllers
  tabBarController.viewControllers = @[uikitHomeFeedNavCtrl, asdkHomeFeedNavCtrl];
  tabBarController.selectedViewController = asdkHomeFeedNavCtrl;
  
//  [KMCGeigerCounter sharedGeigerCounter].enabled = YES;
  
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end

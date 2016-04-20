//
//  AppDelegate.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "ASLayoutableInspectorNode.h"
#import "Utilities.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  
  UIViewController *rootVC = nil;
  
  UIDevice *device = [UIDevice currentDevice];
  if (device.userInterfaceIdiom == UIUserInterfaceIdiomPad) {

    ASViewController *masterVC        = [[ASViewController alloc] initWithNode:[ASLayoutableInspectorNode sharedInstance]];
    masterVC.view.backgroundColor     = [UIColor customOrangeColor];
    UINavigationController *masterNav = [[UINavigationController alloc] initWithRootViewController:masterVC];

    ViewController *detailVC          = [[ViewController alloc] init];
    UINavigationController *detailNav = [[UINavigationController alloc] initWithRootViewController:detailVC];
    
    UISplitViewController *splitVC    = [[UISplitViewController alloc] init];
    splitVC.viewControllers           = @[masterNav, detailNav];
    splitVC.preferredDisplayMode      = UISplitViewControllerDisplayModeAllVisible;
    splitVC.maximumPrimaryColumnWidth = 250;
    
    rootVC = splitVC;
    
  } else {
    // FIXME: make this work for iPhones
    NSAssert(YES, @"App optimized for iPad only.");
  }
  
  [self.window setRootViewController:rootVC];
  [self.window makeKeyAndVisible];
  
  return YES;
}

@end

//
//  AppDelegate.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "AppDelegate.h"

#import "ViewController.h"
#import "TableViewController.h"
#import "CollectionViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];
  UITabBarController *tabController = [[UITabBarController alloc] init];
  [tabController setViewControllers:@[[[ViewController alloc] init], [[TableViewController alloc] init], [[CollectionViewController alloc] init]]];
  self.window.rootViewController = tabController;
  [self.window makeKeyAndVisible];
  return YES;
}

@end

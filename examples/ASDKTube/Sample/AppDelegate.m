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
#import "WindowWithStatusBarUnderlay.h"
#import "Utilities.h"
#import "VideoFeedNodeController.h"


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  // this UIWindow subclass is neccessary to make the status bar opaque
  _window                  = [[WindowWithStatusBarUnderlay alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor  = [UIColor whiteColor];


  VideoFeedNodeController *asdkHomeFeedVC      = [[VideoFeedNodeController alloc] init];
  UINavigationController *asdkHomeFeedNavCtrl  = [[UINavigationController alloc] initWithRootViewController:asdkHomeFeedVC];


  _window.rootViewController = asdkHomeFeedNavCtrl;
  [_window makeKeyAndVisible];

  // Nav Bar appearance
  NSDictionary *attributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
  [[UINavigationBar appearance] setTitleTextAttributes:attributes];
  [[UINavigationBar appearance] setBarTintColor:[UIColor lighOrangeColor]];
  [[UINavigationBar appearance] setTranslucent:NO];

  [application setStatusBarStyle:UIStatusBarStyleLightContent];


  return YES;
}
@end

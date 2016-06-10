//
//  AppDelegate.m
//  Sample
//
//  Created by Michael Schneider on 4/24/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "AppDelegate.h"
#import "OverviewComponentsViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[OverviewComponentsViewController new]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:47/255.0 green:184/255.0 blue:253/255.0 alpha:1.0]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];;
    
    return YES;
}

@end

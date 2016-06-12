//
//  AppDelegate.m
//  Sample
//
//  Created by Hannah Troisi on 2/16/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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
  
  // this UIWindow subclass is neccessary to make the status bar opaque
  _window                  = [[WindowWithStatusBarUnderlay alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor  = [UIColor whiteColor];
  
  // UIKit Home Feed viewController & navController
  PhotoFeedNodeController *asdkHomeFeedVC      = [[PhotoFeedNodeController alloc] init];
  UINavigationController *asdkHomeFeedNavCtrl  = [[UINavigationController alloc] initWithRootViewController:asdkHomeFeedVC];
  asdkHomeFeedNavCtrl.tabBarItem               = [[UITabBarItem alloc] initWithTitle:@"ASDK" image:[UIImage imageNamed:@"home"] tag:0];
  asdkHomeFeedNavCtrl.hidesBarsOnSwipe         = YES;
  
  // ASDK Home Feed viewController & navController
  PhotoFeedViewController *uikitHomeFeedVC     = [[PhotoFeedViewController alloc] init];
  UINavigationController *uikitHomeFeedNavCtrl = [[UINavigationController alloc] initWithRootViewController:uikitHomeFeedVC];
  uikitHomeFeedNavCtrl.tabBarItem              = [[UITabBarItem alloc] initWithTitle:@"UIKit" image:[UIImage imageNamed:@"home"] tag:0];
  uikitHomeFeedNavCtrl.hidesBarsOnSwipe        = YES;

  // UITabBarController
  UITabBarController *tabBarController         = [[UITabBarController alloc] init];
  tabBarController.viewControllers             = @[uikitHomeFeedNavCtrl, asdkHomeFeedNavCtrl];
  tabBarController.selectedViewController      = asdkHomeFeedNavCtrl;
  tabBarController.delegate                    = self;
  [[UITabBar appearance] setTintColor:[UIColor darkBlueColor]];
  
  _window.rootViewController = tabBarController;
  [_window makeKeyAndVisible];
  
  // Nav Bar appearance
  NSDictionary *attributes = @{NSForegroundColorAttributeName:[UIColor whiteColor]};
  [[UINavigationBar appearance] setTitleTextAttributes:attributes];
  [[UINavigationBar appearance] setBarTintColor:[UIColor darkBlueColor]];
  [[UINavigationBar appearance] setTranslucent:NO];
  
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

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
#import "Utilities.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "PhotoCellNode.h"
#import "PhotoFeedModel.h"

@interface AppDelegate () <UITabBarControllerDelegate>
@end

@implementation AppDelegate
{
  UIWindow *_window;
  PhotoFeedModel *_feed;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  // this UIWindow subclass is neccessary to make the status bar opaque
  _window                  = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  _window.backgroundColor  = [UIColor whiteColor];
  _window.rootViewController = [[UIViewController alloc] init];
  [_window makeKeyAndVisible];
  
  _feed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[UIScreen mainScreen].bounds.size];
  [_feed refreshFeedWithCompletionBlock:^(NSArray *newItems) {
    
  } numResultsToReturn:1];
  ASDisplayNode *node = [[PhotoCellNode alloc] initWithPhotoObject:[PhotoModel samplePhotoModel]];
  [[ASDisplayNodeDebugUIManager sharedManager] showDebugUIWithNode:node sizes:nil];
  
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

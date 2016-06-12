//
//  AppDelegate.m
//  Sample
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

#import "PresentingViewController.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.backgroundColor = [UIColor whiteColor];
  self.window.rootViewController = [[UINavigationController alloc] init];
  
  [self pushNewViewControllerAnimated:NO];
  
  [self.window makeKeyAndVisible];
  
  return YES;
}

- (void)pushNewViewControllerAnimated:(BOOL)animated
{
  UINavigationController *navController = (UINavigationController *)self.window.rootViewController;

#if SIMULATE_WEB_RESPONSE
  UIViewController *viewController = [[PresentingViewController alloc] init];
#else
  UIViewController *viewController = [[ViewController alloc] init];
  viewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Push Another Copy" style:UIBarButtonItemStylePlain target:self action:@selector(pushNewViewController)];
#endif
  
  [navController pushViewController:viewController animated:animated];
}

- (void)pushNewViewController
{
  [self pushNewViewControllerAnimated:YES];
}

@end

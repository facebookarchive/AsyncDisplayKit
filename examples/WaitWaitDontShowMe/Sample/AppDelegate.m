/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "AppDelegate.h"

#import "ExpensiveController.h"
#import "CheapController.h"

#define AS_DEMO_PRELOADING 1

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  CGRect screenBounds = [[UIScreen mainScreen] bounds];
  UIWindow *window = [[UIWindow alloc] initWithFrame:screenBounds];

  CheapController *cheap = [[CheapController alloc] init];
  cheap.tabBarItem.title = @"Cheap";
  cheap.tabBarItem.image = [UIImage imageNamed:@"cheap"];

  ExpensiveController *expensive = [[ExpensiveController alloc] init];
  expensive.tabBarItem.title = @"Expensive";
  expensive.tabBarItem.image = [UIImage imageNamed:@"expensive"];

#if AS_DEMO_PRELOADING
  [expensive preloadForSize:screenBounds.size];
#endif

  UITabBarController *tab = [[UITabBarController alloc] init];
  tab.viewControllers = @[cheap, expensive];

  window.rootViewController = tab;
  [window makeKeyAndVisible];
  [self setWindow:window];

  return YES;
}

@end

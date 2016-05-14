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

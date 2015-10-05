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

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#import "AsyncTableViewController.h"
#import "RandomCoreGraphicsNode.h"

@interface AsyncTableViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;
}

@end

@implementation AsyncTableViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;
  
  ASRangeTuningParameters tuningParameters;
  tuningParameters.leadingBufferScreenfuls = 0.5;
  tuningParameters.trailingBufferScreenfuls = 1.0;
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypePreload];
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeRender];
  
  self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)reloadEverything
{
  [_tableView reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_tableView];
}

- (void)viewWillLayoutSubviews
{
  _tableView.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

#pragma mark -
#pragma mark ASTableView.

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
  elementNode.preferredFrameSize = CGSizeMake(320, 100);
  return elementNode;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end

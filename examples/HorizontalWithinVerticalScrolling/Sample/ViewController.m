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

#import "ViewController.h"
#import "HorizontalScrollCellNode.h"

@interface ViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;
}

@end

@implementation ViewController

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
  
  self.title = @"Horizontal Scrolling Gradients";
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

#pragma mark -
#pragma mark ASTableView.

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  HorizontalScrollCellNode *node = [[HorizontalScrollCellNode alloc] initWithElementSize:CGSizeMake(100, 100)];
  return node;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end

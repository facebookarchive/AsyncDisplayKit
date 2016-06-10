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

#import "TableViewController.h"
#import "KittenNode.h"

@interface TableViewController () <ASTableViewDataSource, ASTableViewDelegate>
@property (nonatomic, strong) ASTableNode *tableNode;
@end

@implementation TableViewController

- (instancetype)init
{
  ASTableNode *tableNode = [[ASTableNode alloc] init];
  if (!(self = [super initWithNode:tableNode]))
    return nil;
  
  _tableNode = tableNode;
  tableNode.delegate = self;
  tableNode.dataSource = self;
  self.title = @"Table Node";
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.tableNode.view.contentInset = UIEdgeInsetsMake(CGRectGetHeight([[UIApplication sharedApplication] statusBarFrame]), 0, CGRectGetHeight(self.tabBarController.tabBar.frame), 0);
}

#pragma mark -
#pragma mark ASTableView.

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  KittenNode *cell = [[KittenNode alloc] init];
  cell.imageTappedBlock = ^{
    [KittenNode defaultImageTappedAction:self];
  };
  return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 15;
}

@end

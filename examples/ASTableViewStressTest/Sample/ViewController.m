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

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#define NumberOfSections 10
#define NumberOfRowsPerSection 20
#define NumberOfReloadIterations 50

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

  _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain asyncDataFetching:YES];
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // KittenNode has its own separator
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;

  return self;
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

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  [self thrashTableView];
}

- (void)thrashTableView
{
  // Keep the viewport moderately sized so that new cells are loaded on scrolling
  ASTableView *tableView = [[ASTableView alloc] initWithFrame:CGRectMake(0, 0, 100, 500)
                                                        style:UITableViewStylePlain
                                            asyncDataFetching:NO];
  
  tableView.asyncDelegate = self;
  tableView.asyncDataSource = self;
  
  [tableView reloadData];
  
  [tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1,2)] withRowAnimation:UITableViewRowAnimationNone];
  
  for (int i = 0; i < NumberOfReloadIterations; ++i) {
    NSInteger randA = arc4random_uniform(NumberOfSections - 1);
    NSInteger randB = arc4random_uniform(NumberOfSections - 1);
    
    [tableView reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(MIN(randA, randB), MAX(randA, randB) - MIN(randA, randB))] withRowAnimation:UITableViewRowAnimationNone];
    
    BOOL animated = (arc4random_uniform(1) == 0 ? YES : NO);
    
    [tableView setContentOffset:CGPointMake(0, arc4random_uniform(tableView.contentSize.height - tableView.bounds.size.height)) animated:animated];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return NumberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return NumberOfRowsPerSection;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASTextCellNode *textCellNode = [ASTextCellNode new];
  textCellNode.text = indexPath.description;
  
  return textCellNode;
}

@end

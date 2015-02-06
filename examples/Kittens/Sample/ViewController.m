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

#import "BlurbNode.h"
#import "KittenNode.h"

static const NSInteger kLitterSize = 20;

static const NSUInteger kButtonHeight = 50;


@interface ViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;

  // array of boxed CGSizes corresponding to placekitten kittens
  NSArray *_kittenDataSource;

  UIButton *_testButton;
}

@end


@implementation ViewController

#pragma mark - Testing

- (UIButton *)_createLoadingButtonWithTitle:(NSString *)title {
  UIButton *button = [[UIButton alloc] init];
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16.0f];
  [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  [button sizeToFit];

  button.layer.borderWidth=1.0f;
  button.layer.borderColor=[[UIColor lightGrayColor] CGColor];
  button.layer.cornerRadius = 8.0f;

  return button;
}

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // KittenNode has its own separator
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;

  _kittenDataSource = [self createKittenDataSource];

  _testButton = [self _createLoadingButtonWithTitle:@"Reload Data"];
  [_testButton addTarget:self action:@selector(testButtonPressed) forControlEvents:UIControlEventTouchDown];

  return self;
}

- (NSArray *)createKittenDataSource {
  // populate our "data source" with some random kittens
  NSMutableArray *kittenDataSource = [NSMutableArray arrayWithCapacity:kLitterSize];
  for (NSInteger i = 0; i < kLitterSize; i++) {
    u_int32_t deltaX = arc4random_uniform(10) - 5;
    u_int32_t deltaY = arc4random_uniform(10) - 5;
    CGSize size = CGSizeMake(350 + 2 * deltaX, 350 + 4 * deltaY);

    [kittenDataSource addObject:[NSValue valueWithCGSize:size]];
  }

  return kittenDataSource;
}

- (void)testButtonPressed {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    _kittenDataSource = [self createKittenDataSource];
    [_tableView reloadData];
  });
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_tableView];

  [self.view addSubview:_testButton];
}

- (void)viewWillLayoutSubviews
{
  CGRect bounds = self.view.bounds;
  _tableView.frame = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height - kButtonHeight);

  _testButton.frame = CGRectMake(bounds.origin.x, bounds.origin.y + bounds.size.height - kButtonHeight, bounds.size.width, kButtonHeight);
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

#pragma mark -
#pragma mark Kittens.

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  // special-case the first row
  if (indexPath.section == 0 && indexPath.row == 0) {
    BlurbNode *node = [[BlurbNode alloc] init];
    return node;
  }

  NSValue *size = _kittenDataSource[indexPath.row - 1];
  KittenNode *node = [[KittenNode alloc] initWithKittenOfSize:size.CGSizeValue];
  return node;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  // blurb node + kLitterSize kitties
  return 1 + _kittenDataSource.count;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
  // disable row selection
  return NO;
}

@end

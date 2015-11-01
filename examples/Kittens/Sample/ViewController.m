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

#import "BlurbNode.h"
#import "KittenNode.h"


static const NSInteger kLitterSize = 20;            // intial number of kitten cells in ASTableView
static const NSInteger kLitterBatchSize = 10;       // number of kitten cells to add to ASTableView
static const NSInteger kMaxLitterSize = 100;        // max number of kitten cells allowed in ASTableView

@interface ViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;

  // array of boxed CGSizes corresponding to placekitten.com kittens
  NSMutableArray *_kittenDataSource;

  BOOL _dataSourceLocked;
  NSIndexPath *_blurbNodeIndexPath;
}

@property (nonatomic, strong) NSMutableArray *kittenDataSource;
@property (atomic, assign) BOOL dataSourceLocked;

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

  // populate our "data source" with some random kittens
  _kittenDataSource = [self createLitterWithSize:kLitterSize];

  _blurbNodeIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  
  self.title = @"Kittens";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                         target:self
                                                                                         action:@selector(toggleEditingMode)];

  return self;
}

- (NSMutableArray *)createLitterWithSize:(NSInteger)litterSize
{
  NSMutableArray *kittens = [NSMutableArray arrayWithCapacity:litterSize];
  for (NSInteger i = 0; i < litterSize; i++) {
      
    // placekitten.com will return the same kitten picture if the same pixel height & width are requested,
    // so generate kittens with different width & height values.
    u_int32_t deltaX = arc4random_uniform(10) - 5;
    u_int32_t deltaY = arc4random_uniform(10) - 5;
    CGSize size = CGSizeMake(350 + 2 * deltaX, 350 + 4 * deltaY);
      
    [kittens addObject:[NSValue valueWithCGSize:size]];
  }
  return kittens;
}

- (void)setKittenDataSource:(NSMutableArray *)kittenDataSource {
  ASDisplayNodeAssert(!self.dataSourceLocked, @"Could not update data source when it is locked !");

  _kittenDataSource = kittenDataSource;
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

- (void)toggleEditingMode
{
  [_tableView setEditing:!_tableView.editing animated:YES];
}


#pragma mark -
#pragma mark ASTableView.

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [_tableView deselectRowAtIndexPath:indexPath animated:YES];
  // Assume only kitten nodes are selectable (see -tableView:shouldHighlightRowAtIndexPath:).
  KittenNode *node = (KittenNode *)[_tableView nodeForRowAtIndexPath:indexPath];
  [node toggleImageEnlargement];
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  // special-case the first row
  if ([_blurbNodeIndexPath compare:indexPath] == NSOrderedSame) {
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
  // Enable selection for kitten nodes
  return [_blurbNodeIndexPath compare:indexPath] != NSOrderedSame;
}

- (void)tableViewLockDataSource:(ASTableView *)tableView
{
  self.dataSourceLocked = YES;
}

- (void)tableViewUnlockDataSource:(ASTableView *)tableView
{
  self.dataSourceLocked = NO;
}

- (BOOL)shouldBatchFetchForTableView:(UITableView *)tableView
{
  return _kittenDataSource.count < kMaxLitterSize;
}

- (void)tableView:(UITableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    sleep(1);
    dispatch_async(dispatch_get_main_queue(), ^{
        
      // populate a new array of random-sized kittens
      NSArray *moarKittens = [self createLitterWithSize:kLitterBatchSize];

      NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        
      // find number of kittens in the data source and create their indexPaths
      NSInteger existingRows = _kittenDataSource.count + 1;
        
      for (NSInteger i = 0; i < moarKittens.count; i++) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:existingRows + i inSection:0]];
      }

      // add new kittens to the data source & notify table of new indexpaths
      [_kittenDataSource addObjectsFromArray:moarKittens];
      [tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];

      [context completeBatchFetching:YES];
    });
  });
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Enable editing for Kitten nodes
  return [_blurbNodeIndexPath compare:indexPath] != NSOrderedSame;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Assume only kitten nodes are editable (see -tableView:canEditRowAtIndexPath:).
    [_kittenDataSource removeObjectAtIndex:indexPath.row - 1];
    [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
  }
}

@end

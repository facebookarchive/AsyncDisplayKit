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
#import "GradientTableNode.h"

@interface ViewController () <ASCollectionViewDataSource, ASCollectionViewDelegate>
{
  ASCollectionView *_pagerView;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
  flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
//  flowLayout.itemSize = [[UIScreen mainScreen] bounds].size;
  flowLayout.minimumInteritemSpacing = 0;
  flowLayout.minimumLineSpacing = 0;
  
  _pagerView = [[ASCollectionView alloc] initWithCollectionViewLayout:flowLayout];
  
  ASRangeTuningParameters rangeTuningParameters;
  rangeTuningParameters.leadingBufferScreenfuls = 1.0;
  rangeTuningParameters.trailingBufferScreenfuls = 1.0;
  [_pagerView setTuningParameters:rangeTuningParameters forRangeType:ASLayoutRangeTypeRender];
  
  _pagerView.pagingEnabled = YES;
  _pagerView.asyncDataSource = self;
  _pagerView.asyncDelegate = self;
  
  self.title = @"Paging Table Nodes";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)reloadEverything
{
  [_pagerView reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_pagerView];
}

- (void)viewWillLayoutSubviews
{
  _pagerView.frame = self.view.bounds;
  _pagerView.contentInset = UIEdgeInsetsZero;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

#pragma mark -
#pragma mark ASTableView.

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath;
{
  CGSize boundsSize = collectionView.bounds.size;
  CGSize gradientRowSize = CGSizeMake(boundsSize.width, 100);
  GradientTableNode *node = [[GradientTableNode alloc] initWithElementSize:gradientRowSize];
  node.preferredFrameSize = boundsSize;
  return node;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return (section == 0 ? 10 : 0);
}

@end

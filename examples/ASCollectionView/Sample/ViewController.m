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

@interface ViewController () <ASCollectionViewDataSource, ASCollectionViewDelegate>
{
  ASCollectionView *_collectionView;
}

@end


@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  
  _collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout asyncDataFetching:YES];
  _collectionView.asyncDataSource = self;
  _collectionView.asyncDelegate = self;
  _collectionView.backgroundColor = [UIColor whiteColor];
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_collectionView];
}

- (void)viewWillLayoutSubviews
{
  _collectionView.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}


#pragma mark -
#pragma mark ASCollectionView data source.

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [NSString stringWithFormat:@"[%zd.%zd] says hi", indexPath.section, indexPath.item];
  ASTextCellNode *node = [[ASTextCellNode alloc] init];
  node.text = text;
  node.backgroundColor = [UIColor lightGrayColor];
  
  return node;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 300;
}

- (void)collectionViewLockDataSource:(ASCollectionView *)collectionView
{
  // lock the data source
  // The data source should not be change until it is unlocked.
}

- (void)collectionViewUnlockDataSource:(ASCollectionView *)collectionView
{
  // unlock the data source to enable data source updating.
}

- (void)collectionView:(UICollectionView *)collectionView beginBatchFetchingWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [context completeBatchFetching:YES];
}

@end

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
#import "SupplementaryNode.h"
#import "ItemNode.h"

@interface ViewController () <ASCollectionViewDataSource, ASCollectionViewDelegateFlowLayout>
{
  ASCollectionView *_collectionView;
  NSArray *_data;
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
  layout.headerReferenceSize = CGSizeMake(50.0, 50.0);
  layout.footerReferenceSize = CGSizeMake(50.0, 50.0);
  
  _collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  _collectionView.asyncDataSource = self;
  _collectionView.asyncDelegate = self;
  _collectionView.backgroundColor = [UIColor whiteColor];
  
  [_collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [_collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
  
#if !SIMULATE_WEB_RESPONSE
  self.navigationItem.leftItemsSupplementBackButton = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped)];
#endif
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_collectionView];

#if SIMULATE_WEB_RESPONSE
  __weak typeof(self) weakSelf = self;
  void(^mockWebService)() = ^{
    NSLog(@"ViewController \"got data from a web service\"");
    ViewController *strongSelf = weakSelf;
    if (strongSelf != nil)
    {
      NSLog(@"ViewController is not nil");
      strongSelf->_data = [[NSArray alloc] init];
      [strongSelf->_collectionView performBatchUpdates:^{
        [strongSelf->_collectionView insertSections:[[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, 100)]];
      } completion:nil];
      NSLog(@"ViewController finished updating collectionView");
    }
    else {
      NSLog(@"ViewController is nil - won't update collectionView");
    }
  };
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), mockWebService);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.navigationController popViewControllerAnimated:YES];
  });
#endif
}

- (void)viewWillLayoutSubviews
{
  _collectionView.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)reloadTapped
{
  [_collectionView reloadData];
}

#pragma mark -
#pragma mark ASCollectionView data source.

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [NSString stringWithFormat:@"[%zd.%zd] says hi", indexPath.section, indexPath.item];
  return [[ItemNode alloc] initWithString:text];
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [kind isEqualToString:UICollectionElementKindSectionHeader] ? @"Header" : @"Footer";
  SupplementaryNode *node = [[SupplementaryNode alloc] initWithText:text];
  if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
    node.backgroundColor = [UIColor blueColor];
  } else {
    node.backgroundColor = [UIColor redColor];
  }
  return node;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return 10;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
#if SIMULATE_WEB_RESPONSE
  return _data == nil ? 0 : 100;
#else
  return 100;
#endif
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

- (void)collectionView:(UICollectionView *)collectionView willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [context completeBatchFetching:YES];
}

- (UIEdgeInsets)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  return UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0);
}

#if SIMULATE_WEB_RESPONSE
-(void)dealloc
{
  NSLog(@"ViewController is deallocing");
}
#endif

@end

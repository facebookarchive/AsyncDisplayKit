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
#import "ItemNode.h"
#import "BlurbNode.h"
#import "LoadingNode.h"

static const NSTimeInterval kWebResponseDelay = 1.0;
static const BOOL kSimulateWebResponse = YES;
static const NSInteger kBatchSize = 20;

static const CGFloat kHorizontalSectionPadding = 10.0f;
static const CGFloat kVerticalSectionPadding = 20.0f;

@interface ViewController () <ASCollectionViewDataSource, ASCollectionViewDelegateFlowLayout>
{
  ASCollectionView *_collectionView;
  NSMutableArray *_data;
}

@end


@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    
    self.title = @"Cat Deals";
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    
    _collectionView = [[ASCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collectionView.asyncDataSource = self;
    _collectionView.asyncDelegate = self;
    _collectionView.backgroundColor = [UIColor grayColor];
    _collectionView.leadingScreensForBatching = 2;
    
    ASRangeTuningParameters fetchDataTuning;
    fetchDataTuning.leadingBufferScreenfuls = 2;
    fetchDataTuning.trailingBufferScreenfuls = 1;
    [_collectionView setTuningParameters:fetchDataTuning forRangeType:ASLayoutRangeTypeFetchData];
    
    ASRangeTuningParameters preRenderTuning;
    preRenderTuning.leadingBufferScreenfuls = 1;
    preRenderTuning.trailingBufferScreenfuls = 0.5;
    [_collectionView setTuningParameters:preRenderTuning forRangeType:ASLayoutRangeTypeDisplay];
    
    [_collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
    [_collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
    
    _data = [[NSMutableArray alloc] init];
    
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped)];
  }
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_collectionView];
  [self fetchMoreCatsWithCompletion:nil];
}

- (void)fetchMoreCatsWithCompletion:(void (^)(BOOL))completion {
  if (kSimulateWebResponse) {
    __weak typeof(self) weakSelf = self;
    void(^mockWebService)() = ^{
      NSLog(@"ViewController \"got data from a web service\"");
      ViewController *strongSelf = weakSelf;
      if (strongSelf != nil)
      {
        NSLog(@"ViewController is not nil");
        [strongSelf appendMoreItems:kBatchSize completion:completion];
        NSLog(@"ViewController finished updating collectionView");
      }
      else {
        NSLog(@"ViewController is nil - won't update collectionView");
      }
    };
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWebResponseDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), mockWebService);
  } else {
    [self appendMoreItems:kBatchSize completion:completion];
  }
}

- (void)appendMoreItems:(NSInteger)numberOfNewItems completion:(void (^)(BOOL))completion {
  NSArray *newData = [self getMoreData:numberOfNewItems];
  dispatch_async(dispatch_get_main_queue(), ^{
    [_collectionView performBatchUpdates:^{
      [_data addObjectsFromArray:newData];
      NSArray *addedIndexPaths = [self indexPathsForObjects:newData];
      [_collectionView insertItemsAtIndexPaths:addedIndexPaths];
    } completion:completion];
  });
}

- (NSArray *)getMoreData:(NSInteger)count {
  NSMutableArray *data = [NSMutableArray array];
  for (int i = 0; i < count; i++) {
    [data addObject:[ItemViewModel randomItem]];
  }
  return data;
}

- (NSArray *)indexPathsForObjects:(NSArray *)data {
  NSMutableArray *indexPaths = [NSMutableArray array];
  NSInteger section = 0;
  for (ItemViewModel *viewModel in data) {
    NSInteger item = [_data indexOfObject:viewModel];
    NSAssert(item < [_data count] && item != NSNotFound, @"Item should be in _data");
    [indexPaths addObject:[NSIndexPath indexPathForItem:item inSection:section]];
  }
  return indexPaths;
}

- (void)viewWillLayoutSubviews
{
  _collectionView.frame = self.view.bounds;
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
  [_collectionView.collectionViewLayout invalidateLayout];
}

- (void)reloadTapped
{
  [_collectionView reloadData];
}

#pragma mark -
#pragma mark ASCollectionView data source.

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ItemViewModel *viewModel = _data[indexPath.item];
  return ^{
    return [[ItemNode alloc] initWithViewModel:viewModel];
  };
}

- (ASCellNode *)collectionView:(UICollectionView *)collectionView nodeForSupplementaryElementOfKind:(nonnull NSString *)kind atIndexPath:(nonnull NSIndexPath *)indexPath {
  if ([kind isEqualToString:UICollectionElementKindSectionHeader] && indexPath.section == 0) {
    return [[BlurbNode alloc] init];
  } else if ([kind isEqualToString:UICollectionElementKindSectionFooter] && indexPath.section == 0) {
    return [[LoadingNode alloc] init];
  }
  return nil;
}

- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    CGFloat width = CGRectGetWidth(self.view.frame) - 2 * kHorizontalSectionPadding;
    return CGSizeMake(width, [BlurbNode desiredHeightForWidth:width]);
  }
  return CGSizeZero;
}

- (CGSize)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
  if (section == 0) {
    CGFloat width = CGRectGetWidth(self.view.frame);
    return CGSizeMake(width, [LoadingNode desiredHeightForWidth:width]);
  }
  return CGSizeZero;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat collectionViewWidth = CGRectGetWidth(self.view.frame) - 2 * kHorizontalSectionPadding;
  CGFloat oneItemWidth = [ItemNode preferredViewSize].width;
  NSInteger numColumns = floor(collectionViewWidth / oneItemWidth);
  // Number of columns should be at least 1
  numColumns = MAX(1, numColumns);
  
  CGFloat totalSpaceBetweenColumns = (numColumns - 1) * kHorizontalSectionPadding;
  CGFloat itemWidth = ((collectionViewWidth - totalSpaceBetweenColumns) / numColumns);
  CGSize itemSize = [ItemNode sizeForWidth:itemWidth];
  return ASSizeRangeMake(itemSize, itemSize);
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [_data count];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return 1;
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
  [self fetchMoreCatsWithCompletion:^(BOOL finished){
    [context completeBatchFetching:YES];
  }];
}

- (UIEdgeInsets)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  return UIEdgeInsetsMake(kVerticalSectionPadding, kHorizontalSectionPadding, kVerticalSectionPadding, kHorizontalSectionPadding);
}

-(void)dealloc
{
  NSLog(@"ViewController is deallocing");
}

@end

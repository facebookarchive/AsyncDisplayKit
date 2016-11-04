//
//  ViewController.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

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

@interface ViewController () <ASCollectionDataSource, ASCollectionDelegate, ASCollectionViewDelegateFlowLayout>
{
  ASCollectionNode *_collectionNode;
  NSMutableArray<ItemViewModel *> *_data;
}

@end


@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  _collectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];

  self = [super initWithNode:_collectionNode];
  
  if (self) {
    
    self.title = @"Cat Deals";
  
    _collectionNode.dataSource = self;
    _collectionNode.delegate = self;
    _collectionNode.backgroundColor = [UIColor grayColor];
    
    ASRangeTuningParameters preloadTuning;
    preloadTuning.leadingBufferScreenfuls = 2;
    preloadTuning.trailingBufferScreenfuls = 1;
    [_collectionNode setTuningParameters:preloadTuning forRangeType:ASLayoutRangeTypePreload];
    
    ASRangeTuningParameters displayTuning;
    displayTuning.leadingBufferScreenfuls = 1;
    displayTuning.trailingBufferScreenfuls = 0.5;
    [_collectionNode setTuningParameters:displayTuning forRangeType:ASLayoutRangeTypeDisplay];
    
    [_collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
    [_collectionNode registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
    
    _data = [[NSMutableArray alloc] init];
    
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped)];
  }
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  // set any collectionView properties here (once the node's backing view is loaded)
  _collectionNode.view.leadingScreensForBatching = 2;
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
    [_collectionNode performBatchAnimated:YES updates:^{
      [_data addObjectsFromArray:newData];
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

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
  [_collectionNode.view.collectionViewLayout invalidateLayout];
}

- (void)reloadTapped
{
  [_collectionNode reloadData];
}

#pragma mark - ASCollectionNodeDelegate / ASCollectionNodeDataSource

- (ASCollectionData *)dataForCollectionNode:(ASCollectionNode *)collectionNode
{
  ASCollectionData *data = [collectionNode createNewData];
  [data addSectionWithIdentifier:@"Single Section" block:^(ASCollectionData * _Nonnull data) {
    for (ItemViewModel *item in _data) {
      [data addItemWithIdentifier:item.uuid nodeBlock:^ASCellNode * _Nonnull{
        return [[ItemNode alloc] initWithViewModel:item];
      }];
    }
  }];
  return data;
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  if ([kind isEqualToString:UICollectionElementKindSectionHeader] && indexPath.section == 0) {
    return [[BlurbNode alloc] init];
  } else if ([kind isEqualToString:UICollectionElementKindSectionFooter] && indexPath.section == 0) {
    return [[LoadingNode alloc] init];
  }
  return nil;
}

- (ASSizeRange)collectionNode:(ASCollectionNode *)collectionNode constrainedSizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
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

- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [self fetchMoreCatsWithCompletion:^(BOOL finished){
    [context completeBatchFetching:YES];
  }];
}

#pragma mark - ASCollectionViewDelegateFlowLayout

- (UIEdgeInsets)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  return UIEdgeInsetsMake(kVerticalSectionPadding, kHorizontalSectionPadding, kVerticalSectionPadding, kHorizontalSectionPadding);
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


@end

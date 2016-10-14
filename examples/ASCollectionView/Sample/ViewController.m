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
#import "SupplementaryNode.h"
#import "ItemNode.h"

@interface ViewController ()
@property (nonatomic, strong) ASCollectionView *collectionView;
@property (nonatomic, strong) NSArray *data;
@end

@interface ViewController () <ASCollectionDataSource, ASCollectionViewDelegateFlowLayout>

@end


@implementation ViewController

- (void)dealloc
{
  self.collectionView.asyncDataSource = nil;
  self.collectionView.asyncDelegate = nil;
  
  NSLog(@"ViewController is deallocing");
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.headerReferenceSize = CGSizeMake(50.0, 50.0);
  layout.footerReferenceSize = CGSizeMake(50.0, 50.0);
  
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  self.collectionView = [[ASCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
  self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.collectionView.asyncDataSource = self;
  self.collectionView.asyncDelegate = self;
  self.collectionView.backgroundColor = [UIColor whiteColor];
  
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  [self.collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionHeader];
  [self.collectionView registerSupplementaryNodeOfKind:UICollectionElementKindSectionFooter];
  [self.view addSubview:self.collectionView];
  
#if !SIMULATE_WEB_RESPONSE
  self.navigationItem.leftItemsSupplementBackButton = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadTapped)];
#endif

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

- (void)reloadTapped
{
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  [self.collectionView reloadData];
}

#pragma mark -
#pragma mark ASCollectionView data source.

- (ASCellNodeBlock)collectionView:(ASCollectionView *)collectionView nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;
{
  NSString *text = [NSString stringWithFormat:@"[%zd.%zd] says hi", indexPath.section, indexPath.item];
  return ^{
    return [[ItemNode alloc] initWithString:text];
  };
}

- (ASCellNode *)collectionView:(ASCollectionView *)collectionView nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [kind isEqualToString:UICollectionElementKindSectionHeader] ? @"Header" : @"Footer";
  SupplementaryNode *node = [[SupplementaryNode alloc] initWithText:text];
  BOOL isHeaderSection = [kind isEqualToString:UICollectionElementKindSectionHeader];
  node.backgroundColor = isHeaderSection ? [UIColor blueColor] : [UIColor redColor];
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

- (UIEdgeInsets)collectionView:(ASCollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
  return UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0);
}

@end

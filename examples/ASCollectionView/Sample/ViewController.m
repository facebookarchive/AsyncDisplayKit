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

@interface ViewController () <ASCollectionDataSource, ASCollectionDelegateFlowLayout>

@property (nonatomic, strong) ASCollectionNode *collectionNode;
@property (nonatomic, strong) NSArray *data;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)dealloc
{
  self.collectionNode.dataSource = nil;
  self.collectionNode.delegate = nil;
  
  NSLog(@"ViewController is deallocing");
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.collectionNode = [[ASCollectionNode alloc] initWithLayoutDelegate:[[ASCollectionFlowLayoutDelegate alloc] init] layoutFacilitator:nil];
  self.collectionNode.dataSource = self;
  self.collectionNode.delegate = self;
  
  self.collectionNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.collectionNode.backgroundColor = [UIColor whiteColor];
  
  [self.view addSubnode:self.collectionNode];
  self.collectionNode.frame = self.view.bounds;
  
#if !SIMULATE_WEB_RESPONSE
  self.navigationItem.leftItemsSupplementBackButton = YES;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                        target:self
                                                                                        action:@selector(reloadTapped)];
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

#pragma mark - Button Actions

- (void)reloadTapped
{
  // This method is deprecated because we reccommend using ASCollectionNode instead of ASCollectionView.
  // This functionality & example project remains for users who insist on using ASCollectionView.
  [self.collectionNode reloadData];
}

#pragma mark - ASCollectionView Data Source

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath;
{
  NSString *text = [NSString stringWithFormat:@"[%zd.%zd] says hi", indexPath.section, indexPath.item];
  return ^{
    return [[ItemNode alloc] initWithString:text];
  };
}

- (ASCellNode *)collectionNode:(ASCollectionNode *)collectionNode nodeForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  NSString *text = [kind isEqualToString:UICollectionElementKindSectionHeader] ? @"Header" : @"Footer";
  SupplementaryNode *node = [[SupplementaryNode alloc] initWithText:text];
  BOOL isHeaderSection = [kind isEqualToString:UICollectionElementKindSectionHeader];
  node.backgroundColor = isHeaderSection ? [UIColor blueColor] : [UIColor redColor];
  return node;
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
  return 10;
}

- (NSInteger)numberOfSectionsInCollectionNode:(ASCollectionNode *)collectionNode
{
#if SIMULATE_WEB_RESPONSE
  return _data == nil ? 0 : 100;
#else
  return 100;
#endif
}

- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  NSLog(@"fetch additional content");
  [context completeBatchFetching:YES];
}

@end

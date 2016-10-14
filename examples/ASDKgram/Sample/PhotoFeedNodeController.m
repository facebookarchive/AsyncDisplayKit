//
//  PhotoFeedNodeController.m
//  Sample
//
//  Created by Hannah Troisi on 2/17/16.
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

#import "PhotoFeedNodeController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "Utilities.h"
#import "PhotoModel.h"
#import "PhotoCellNode.h"
#import "PhotoFeedModel.h"

#define AUTO_TAIL_LOADING_NUM_SCREENFULS  2.5

@interface PhotoFeedNodeController () <ASTableDelegate, ASTableDataSource>
@end

@implementation PhotoFeedNodeController
{
  PhotoFeedModel          *_photoFeed;
  ASTableNode             *_tableNode;
  UIActivityIndicatorView *_activityIndicatorView;
}

#pragma mark - Lifecycle

// -init is often called off the main thread in ASDK. Therefore it is imperative that no UIKit objects are accessed.
// Examples of common errors include accessing the node’s view or creating a gesture recognizer.
- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] init];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    self.navigationItem.title = @"ASDK";
    [self.navigationController setNavigationBarHidden:YES];
    
    _tableNode.dataSource = self;
    _tableNode.delegate = self;
    
  }
  
  return self;
}

// -loadView is guaranteed to be called on the main thread and is the appropriate place to
// set up an UIKit objects you may be using.
- (void)loadView
{
  [super loadView];
  
  _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  
  _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[self imageSizeForScreenWidth]];
  [self refreshFeed];
  
  CGSize boundSize = self.view.bounds.size;

  [_activityIndicatorView sizeToFit];
  CGRect refreshRect = _activityIndicatorView.frame;
  refreshRect.origin = CGPointMake((boundSize.width - _activityIndicatorView.frame.size.width) / 2.0,
                                   (boundSize.height - _activityIndicatorView.frame.size.height) / 2.0);
  _activityIndicatorView.frame = refreshRect;
  
  [self.view addSubview:_activityIndicatorView];
  
  self.view.backgroundColor = [UIColor whiteColor];
  _tableNode.view.allowsSelection = NO;
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableNode.view.leadingScreensForBatching = AUTO_TAIL_LOADING_NUM_SCREENFULS;  // overriding default of 2.0
}

#pragma mark - helper methods

- (void)refreshFeed
{
  [_activityIndicatorView startAnimating];
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [_activityIndicatorView stopAnimating];
    
    [self insertNewRowsInTableView:newPhotos];
//    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPageWithContext:nil];
    
  } numResultsToReturn:4];
}

- (void)loadPageWithContext:(ASBatchContext *)context
{
  [_photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    
    [self insertNewRowsInTableView:newPhotos];
//    [self requestCommentsForPhotos:newPhotos];
    if (context) {
      [context completeBatchFetching:YES];
    }
  } numResultsToReturn:20];
}

//- (void)requestCommentsForPhotos:(NSArray *)newPhotos
//{
//  for (PhotoModel *photo in newPhotos) {
//    [photo.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
//      
//      NSInteger rowNum      = [_photoFeed indexOfPhotoModel:photo];
//      NSIndexPath *cellPath = [NSIndexPath indexPathForRow:rowNum inSection:0];
//      PhotoCellNode *cell   = (PhotoCellNode *)[_tableNode.view nodeForRowAtIndexPath:cellPath];
//      
//      if (cell) {
//        [cell loadCommentsForPhoto:photo];
//        [_tableNode.view beginUpdates];
//        [_tableNode.view endUpdates];
//      }
//    }];
//  }
//}

- (void)insertNewRowsInTableView:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSUInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSUInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  
  [_tableNode insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return UIStatusBarStyleLightContent;
}

- (CGSize)imageSizeForScreenWidth
{
  CGRect screenRect   = [[UIScreen mainScreen] bounds];
  CGFloat screenScale = [[UIScreen mainScreen] scale];
  return CGSizeMake(screenRect.size.width * screenScale, screenRect.size.width * screenScale);
}

#pragma mark - ASTableDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_photoFeed numberOfItemsInFeed];
}

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PhotoModel *photoModel = [_photoFeed objectAtIndex:indexPath.row];
  // this will be executed on a background thread - important to make sure it's thread safe
  ASCellNode *(^ASCellNodeBlock)() = ^ASCellNode *() {
    PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhotoObject:photoModel];
    return cellNode;
  };
  
  return ASCellNodeBlock;
}

#pragma mark - ASTableDelegate methods

// Receive a message that the tableView is near the end of its data set and more data should be fetched if necessary.
- (void)tableView:(ASTableView *)tableView willBeginBatchFetchWithContext:(ASBatchContext *)context
{
  [context beginBatchFetching];
  [self loadPageWithContext:context];
}

#pragma mark - PhotoFeedViewControllerProtocol

- (void)resetAllData
{
  [_photoFeed clearFeed];
  [_tableNode reloadData];
  [self refreshFeed];
}

@end

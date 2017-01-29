//
//  PhotoFeedBaseController.m
//  Sample
//
//  Created by Huy Nguyen on 20/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

#import "PhotoFeedBaseController.h"
#import "PhotoFeedModel.h"

@implementation PhotoFeedBaseController
{
  UIActivityIndicatorView *_activityIndicatorView;
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
  
  self.tableView.allowsSelection = NO;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  self.view.backgroundColor = [UIColor whiteColor];
}

- (void)refreshFeed
{
  [_activityIndicatorView startAnimating];
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [_activityIndicatorView stopAnimating];
    
    [self insertNewRows:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPage];
    
  } numResultsToReturn:4];
}

- (void)insertNewRows:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
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

#pragma mark - PhotoFeedViewControllerProtocol

- (void)resetAllData
{
  [_photoFeed clearFeed];
  [self.tableView reloadData];
  [self refreshFeed];
}

#pragma mark - Subclassing

- (UITableView *)tableView
{
  NSAssert(NO, @"Subclasses must override this method");
  return nil;
}

- (void)loadPage
{
  NSAssert(NO, @"Subclasses must override this method");
}

- (void)requestCommentsForPhotos:(NSArray *)newPhotos
{
  NSAssert(NO, @"Subclasses must override this method");
}

@end

//
//  PhotoFeedViewController.m
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

#import "PhotoFeedViewController.h"
#import "Utilities.h"
#import "PhotoTableViewCell.h"
#import "PhotoFeedModel.h"
#import "CommentView.h"

#define AUTO_TAIL_LOADING_NUM_SCREENFULS  2.5

@interface PhotoFeedViewController () <UITableViewDelegate, UITableViewDataSource>
@end

@implementation PhotoFeedViewController
{
  UITableView *_tableView;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super initWithNibName:nil bundle:nil];
  
  if (self) {
    self.navigationItem.title = @"UIKit";
    [self.navigationController setNavigationBarHidden:YES];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _tableView.delegate = self;
    _tableView.dataSource = self;
  }
  
  return self;
}

// anything involving the view should go here, not init
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_tableView];
  _tableView.frame = self.view.bounds;
  [_tableView registerClass:[PhotoTableViewCell class] forCellReuseIdentifier:@"photoCell"];
}

#pragma mark - Subclassing

- (UITableView *)tableView
{
  return _tableView;
}

- (void)loadPage
{
  [self.photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    [self insertNewRows:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
  } numResultsToReturn:20];
}

- (void)requestCommentsForPhotos:(NSArray *)newPhotos
{
  for (PhotoModel *photo in newPhotos) {
    [photo.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
      
      NSInteger rowNum         = [self.photoFeed indexOfPhotoModel:photo];
      NSIndexPath *cellPath    = [NSIndexPath indexPathForRow:rowNum inSection:0];
      PhotoTableViewCell *cell = [_tableView cellForRowAtIndexPath:cellPath];
      
      if (cell) {
        [cell loadCommentsForPhoto:photo];
        [_tableView beginUpdates];
        [_tableView endUpdates];
        
        // adjust scrollView contentOffset if inserting above visible cells
        NSIndexPath *visibleCellPath = [_tableView indexPathForCell:_tableView.visibleCells.firstObject];
        if (cellPath.row < visibleCellPath.row) {
          CGFloat commentViewHeight = [CommentView heightForCommentFeedModel:photo.commentFeed withWidth:self.view.bounds.size.width];
          _tableView.contentOffset = CGPointMake(_tableView.contentOffset.x, _tableView.contentOffset.y + commentViewHeight);
        }
      }
    }];
  }
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.photoFeed numberOfItemsInFeed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PhotoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoCell" forIndexPath:indexPath];
  [cell updateCellWithPhotoObject:[self.photoFeed objectAtIndex:indexPath.row]];
  
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  PhotoModel *photo = [self.photoFeed objectAtIndex:indexPath.row];
  return [PhotoTableViewCell heightForPhotoModel:photo withWidth:self.view.bounds.size.width];
}

#pragma mark - UITableViewDelegate methods

// table automatic tail loading
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  CGFloat currentOffSetY = scrollView.contentOffset.y;
  CGFloat contentHeight  = scrollView.contentSize.height;
  CGFloat screenHeight   = [UIScreen mainScreen].bounds.size.height;

  CGFloat screenfullsBeforeBottom = (contentHeight - currentOffSetY) / screenHeight;
  if (screenfullsBeforeBottom < AUTO_TAIL_LOADING_NUM_SCREENFULS) {
    [self loadPage];
  }
}

@end

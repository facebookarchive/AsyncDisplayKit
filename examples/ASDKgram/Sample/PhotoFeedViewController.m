//
//  PhotoFeedViewController.m
//  ASDKgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
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
  PhotoFeedModel *_photoFeed;
  UITableView    *_tableView;
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
    
    _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[self imageSizeForScreenWidth]];
    [self refreshFeed];
  }
  
  return self;
}

// anything involving the view should go here, not init
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_tableView];
  _tableView.frame = self.view.bounds;
  _tableView.allowsSelection = NO;
  _tableView.separatorStyle  = UITableViewCellSeparatorStyleNone;
  [_tableView registerClass:[PhotoTableViewCell class] forCellReuseIdentifier:@"photoCell"];
}

#pragma mark - helper methods

- (void)refreshFeed
{
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    [self insertNewRowsInTableView:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPage];
    
  } numResultsToReturn:4];
}

- (void)loadPage
{
  [_photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    [self insertNewRowsInTableView:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
  } numResultsToReturn:20];
}

- (void)requestCommentsForPhotos:(NSArray *)newPhotos
{
  for (PhotoModel *photo in newPhotos) {
    [photo.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
      
      NSInteger rowNum         = [_photoFeed indexOfPhotoModel:photo];
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

- (void)insertNewRowsInTableView:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
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

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_photoFeed numberOfItemsInFeed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  PhotoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"photoCell" forIndexPath:indexPath];
  [cell updateCellWithPhotoObject:[_photoFeed objectAtIndex:indexPath.row]];
  
  return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
  PhotoModel *photo = [_photoFeed objectAtIndex:indexPath.row];
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

#pragma mark - PhotoFeedViewControllerProtocol

- (void)resetAllData
{
  [_photoFeed clearFeed];
  [_tableView reloadData];
  [self refreshFeed];
}

@end

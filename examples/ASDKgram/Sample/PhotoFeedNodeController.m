//
//  PhotoFeedNodeController.m
//  ASDKgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
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
  PhotoFeedModel   *_photoFeed;
  ASTableNode      *_tableNode;
  UIView           *_statusBarOpaqueUnderlayView;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] init];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    self.navigationItem.title = @"ASDK";
    [self.navigationController setNavigationBarHidden:YES];
    
    _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular
                                                          imageSize:[self imageSizeForScreenWidth]];
    [self refreshFeed];

    _tableNode.dataSource = self;
    _tableNode.delegate = self;
  }
  
  return self;
}

// do any ASDK view stuff in loadView
- (void)loadView
{
  [super loadView];
  
  self.view.backgroundColor = [UIColor whiteColor];
  _tableNode.view.allowsSelection = NO;
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;

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
      
      NSInteger rowNum      = [_photoFeed indexOfPhotoModel:photo];
      NSIndexPath *cellPath = [NSIndexPath indexPathForRow:rowNum inSection:0];
      PhotoCellNode *cell   = (PhotoCellNode *)[_tableNode.view nodeForRowAtIndexPath:cellPath];
      
      if (cell) {
        [cell loadCommentsForPhoto:photo];
        [_tableNode.view beginUpdates];
        [_tableNode.view endUpdates];
      }
    }];
  }
}

- (void)insertNewRowsInTableView:(NSArray *)newPhotos
{
  NSInteger section = 0;
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSUInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSUInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  
  [_tableNode.view insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
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

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath;
{
  PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhotoObject:[_photoFeed objectAtIndex:indexPath.row]];
  
  return cellNode;
}

#pragma mark - ASTableDelegate methods

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

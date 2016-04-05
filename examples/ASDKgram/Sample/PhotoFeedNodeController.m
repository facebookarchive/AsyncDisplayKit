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
  _tableNode.view.leadingScreensForBatching = AUTO_TAIL_LOADING_NUM_SCREENFULS;  // overriding default of 2.0

}

#pragma mark - helper methods

- (void)refreshFeed
{
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [self insertNewRowsInTableView:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPageWithContext:nil];
    
  } numResultsToReturn:4];
}

- (void)loadPageWithContext:(ASBatchContext *)context
{
  [_photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    [self insertNewRowsInTableView:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
    if (context) {
      [context completeBatchFetching:YES];
    }
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

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  // this will be executed on a background thread - important to make sure it's thread safe
  ASCellNode *(^ASCellNodeBlock)() = ^ASCellNode *() {
    PhotoCellNode *cellNode = [[PhotoCellNode alloc] initWithPhotoObject:[_photoFeed objectAtIndex:indexPath.row]];
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

@end

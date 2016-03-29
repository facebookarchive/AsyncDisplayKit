//
//  PhotoFeedNodeController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoFeedNodeController.h"
#import "PhotoModel.h"
#import "PhotoCellNode.h"
#import "PhotoTableViewCell.h"
#import "UserProfileViewController.h"
#import "LocationCollectionViewController.h"
#import "PhotoFeedModel.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "Utilities.h"

#define AUTO_TAIL_LOADING_NUM_SCREENFULS  2.5

@interface PhotoFeedNodeController () <ASTableDelegate, ASTableDataSource, PhotoTableViewCellProtocol>
@end

@implementation PhotoFeedNodeController
{
  PhotoFeedModel *_photoFeed;
  ASTableView    *_tableView;
  UIView         *_statusBarOpaqueUnderlayView;
}


#pragma mark - Lifecycle

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  
  if (self) {
    
    self.navigationItem.title      = @"500pixgram";
    [self.navigationController setNavigationBarHidden:YES];
    
//    _tableView.refreshControl      = [[UIRefreshControl alloc] init];
//    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[self imageSizeForScreenWidth]];
    [self refreshFeed];
    
    _statusBarOpaqueUnderlayView                 = [[UIView alloc] init];
    _statusBarOpaqueUnderlayView.backgroundColor = [UIColor darkBlueColor];
    [[[UIApplication sharedApplication] keyWindow] addSubview:_statusBarOpaqueUnderlayView];

    
    // ASTABLEVIEW
    _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain asyncDataFetching:YES];
    _tableView.asyncDataSource = self;
    _tableView.asyncDelegate = self;
    _tableView.allowsSelection = NO;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    // enable tableView pull-to-refresh & add target-action pair
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
  }
  
  return self;
}

- (CGSize)imageSizeForScreenWidth
{
  CGRect screenRect   = [[UIScreen mainScreen] bounds];
  CGFloat screenScale = [[UIScreen mainScreen] scale];
  return CGSizeMake(screenRect.size.width * screenScale, screenRect.size.width * screenScale);
}

- (void)loadView
{
  [super loadView];
  
  [self.view addSubview:_tableView];  //FIXME: self use implicit heirarchy?
  self.view.backgroundColor = [UIColor whiteColor]; //ditto
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  self.navigationController.hidesBarsOnSwipe = YES;
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  _tableView.frame = self.view.bounds;
  _statusBarOpaqueUnderlayView.frame = [[UIApplication sharedApplication] statusBarFrame];
}

#pragma mark - Gesture Handling

- (void)refreshFeed
{
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [_tableView reloadData];        // overwrite tableView instead of inserting new rows
//    [self.refreshControl endRefreshing];
    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPage];
    
  } numResultsToReturn:4];
}

- (UIStatusBarStyle)preferredStatusBarStyle   // FIXME - doesn't work?
{
  return UIStatusBarStyleLightContent;
}

- (void)loadPage
{
//  NSLog(@"_photoFeed number of items = %lu", [_photoFeed numberOfItemsInFeed]);
  
  [self logPhotoIDsInPhotoFeed];

  [_photoFeed requestPageWithCompletionBlock:^(NSArray *newPhotos){
    
    [self insertNewRowsInTableView:newPhotos];
    [self requestCommentsForPhotos:newPhotos];
    [self logPhotoIDsInPhotoFeed];

  } numResultsToReturn:20];
}

- (void)requestCommentsForPhotos:(NSArray *)newPhotos
{
  for (PhotoModel *photo in newPhotos) {
    
    [photo.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
      
      NSInteger rowNum = [_photoFeed indexOfPhotoModel:photo];
      PhotoCellNode *cell = (PhotoCellNode *)[_tableView nodeForRowAtIndexPath:[NSIndexPath indexPathForRow:rowNum inSection:0]];
      
      if (cell) {
        [cell loadCommentsForPhoto:photo];
        [_tableView beginUpdates];
        [_tableView endUpdates];
      }
    }];
  }
}

- (void)logPhotoIDsInPhotoFeed
{
//  NSLog(@"_photoFeed number of items = %lu", [_photoFeed numberOfItemsInFeed]);
  
//  for (int i = 0; i < [_photoFeed numberOfItemsInFeed]; i++) {
//    if (i % 4 == 0 && i > 0) {
//      NSLog(@"\t-----");
//    }
  
//    [_photoFeed return]
//    NSString *duplicate =  ? @"(DUPLICATE)" : @"";
//    NSLog(@"\t%@  %@", [[_photoFeed objectAtIndex:i] photoID], @"");
//  }
}

- (void)insertNewRowsInTableView:(NSArray *)newPhotos
{
//  NSLog(@"_photoFeed number of items = %lu (%lu total)", (unsigned long)[_photoFeed numberOfItemsInFeed], (long)[_photoFeed totalNumberOfPhotos]);
  
  // instead of doing tableView reloadData, use table editing commands
  NSMutableArray *indexPaths = [NSMutableArray array];
  
  NSInteger section = 0;
  NSUInteger newTotalNumberOfPhotos = [_photoFeed numberOfItemsInFeed];
  for (NSUInteger row = newTotalNumberOfPhotos - newPhotos.count; row < newTotalNumberOfPhotos; row++) {
    
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
    [indexPaths addObject:path];
  }
  
  [_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - ASTableDelegate protocol methods
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  
  CGFloat currentOffSetY = scrollView.contentOffset.y;
  CGFloat contentHeight  = scrollView.contentSize.height;
  CGFloat screenHeight   = [UIScreen mainScreen].bounds.size.height;
  
  // automatic tail loading
  CGFloat screenfullsBeforeBottom = (contentHeight - currentOffSetY) / screenHeight;
  if (screenfullsBeforeBottom < AUTO_TAIL_LOADING_NUM_SCREENFULS) {
//    NSLog(@"AUTOMATIC TAIL LOADING BEGIN");
    [self loadPage];
  }
}


#pragma mark - ASTableDataSource protocol methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_photoFeed numberOfItemsInFeed];
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath;
{
  PhotoCellNode *cell = [[PhotoCellNode alloc] initWithPhotoObject:[_photoFeed objectAtIndex:indexPath.row]];
  
  return cell;
}

#pragma mark - PhotoTableViewCellProtocol

- (void)photoLikesWasTouchedWithPhoto:(PhotoModel *)photo
{
  
}

- (void)userProfileWasTouchedWithUser:(UserModel *)user
{
  UserProfileViewController *userProfileView = [[UserProfileViewController alloc] initWithUser:user];
  
  [self.navigationController pushViewController:userProfileView animated:YES];
}

- (void)photoLocationWasTouchedWithCoordinate:(CLLocationCoordinate2D)coordiantes name:(NSString *)name
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.minimumInteritemSpacing = 1;
  layout.minimumLineSpacing = 1;
  layout.headerReferenceSize = CGSizeMake(self.view.bounds.size.width, 200);
  
  CGFloat numItemsLine = 3;
  layout.itemSize = CGSizeMake((self.view.bounds.size.width - (numItemsLine - 1)) / numItemsLine,
                               (self.view.bounds.size.width - (numItemsLine - 1)) / numItemsLine);
  
  LocationCollectionViewController *locationCVC = [[LocationCollectionViewController alloc] initWithCollectionViewLayout:layout coordinates:coordiantes];
  locationCVC.navigationItem.title = name;
  
  [self.navigationController pushViewController:locationCVC animated:YES];
}

- (void)cellWasLongPressedWithPhoto:(PhotoModel *)photo
{
  UIAlertAction *savePhotoAction = [UIAlertAction actionWithTitle:@"Save Photo"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
                                                            NSLog(@"hi");
                                                          }];
  
  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * _Nonnull action) {
                                                         
                                                       }];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
  
  [alert addAction:savePhotoAction];
  [alert addAction:cancelAction];
  
  [self presentViewController:alert animated:YES completion:^{}];
}


@end

//
//  PhotoTableViewController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoTableViewController.h"
#import "PhotoTableViewCell.h"
#import "PhotoFeedModel.h"
#import "Utilities.h"


#define AUTO_TAIL_LOADING_NUM_SCREENFULS  2.5


@implementation PhotoTableViewController
{
  PhotoFeedModel *_photoFeed;
  UIView         *_statusBarOpaqueUnderlayView;
}


#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:style];
  
  if (self) {
      
    self.navigationItem.title      = @"UIKit";
    [self.navigationController setNavigationBarHidden:YES];
    
    self.refreshControl            = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
    
    _photoFeed                     = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:[self imageSizeForScreenWidth]];
    [self refreshFeed];
    
    _statusBarOpaqueUnderlayView                 = [[UIView alloc] init];
    _statusBarOpaqueUnderlayView.backgroundColor = [UIColor darkBlueColor];
    [[[UIApplication sharedApplication] keyWindow] addSubview:_statusBarOpaqueUnderlayView];
  }
  
  return self;
}

- (void)viewDidLoad  // anything involving the view should go here, not init
{
  [super viewDidLoad];
  
  self.tableView.allowsSelection = NO;
  self.tableView.separatorStyle  = UITableViewCellSeparatorStyleNone;
  [self.tableView registerClass:[PhotoTableViewCell class] forCellReuseIdentifier:@"photoCell"];
  
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  self.navigationController.hidesBarsOnSwipe = YES;
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  _statusBarOpaqueUnderlayView.frame = [[UIApplication sharedApplication] statusBarFrame];
}

#pragma mark - Instance Methods

- (void)refreshFeed
{
  // small first batch
  [_photoFeed refreshFeedWithCompletionBlock:^(NSArray *newPhotos){
    
    [self.tableView reloadData];        // overwrite tableView instead of inserting new rows
    [self.refreshControl endRefreshing];
    [self requestCommentsForPhotos:newPhotos];
    
    // immediately start second larger fetch
    [self loadPage];
    
  } numResultsToReturn:4];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return UIStatusBarStyleLightContent;
}

#pragma mark - Helper Methods

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
      PhotoTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:rowNum inSection:0]];
      
      if (cell) {
        [cell loadCommentsForPhoto:photo];
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
        // FIXME: adjust content offset - iterate over cells above to get heights...
      }
    }];
  }
}

- (CGSize)imageSizeForScreenWidth
{
  CGRect screenRect   = [[UIScreen mainScreen] bounds];
  CGFloat screenScale = [[UIScreen mainScreen] scale];
  return CGSizeMake(screenRect.size.width * screenScale, screenRect.size.width * screenScale);
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
  
  [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

//- (void)logPhotoIDsInPhotoFeed
//{
//  NSLog(@"_photoFeed number of items = %lu", (unsigned long)[_photoFeed numberOfItemsInFeed]);
//  
//  for (int i = 0; i < [_photoFeed numberOfItemsInFeed]; i++) {
//    if (i % 4 == 0 && i > 0) {
//      NSLog(@"\t-----");
//    }
//    
////    [_photoFeed return]
////    NSString *duplicate =  ? @"(DUPLICATE)" : @"";
//    NSLog(@"\t%@  %@", [[_photoFeed objectAtIndex:i] photoID], @"");
//  }
//}

#pragma mark - UITableViewDelegate

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


#pragma mark - UITableViewDataSource

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

@end

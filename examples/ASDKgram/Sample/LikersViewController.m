//
//  LikersViewController.m
//  Flickrgram
//
//  Created by Hannah Troisi on 3/14/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "LikersViewController.h"
#import "UserRowView.h"
#import "CommentFeedModel.h"

#define AUTO_TAIL_LOADING_NUM_SCREENFULS  1.0

@interface LikersViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation LikersViewController
{
  PhotoModel  *_photo;
  UITableView *_tableView;
}


#pragma mark - Lifecycle

- (instancetype)initWithPhoto:(PhotoModel *)photo
{
  self = [super initWithNibName:nil bundle:nil];
  
  if (self) {
    
    self.navigationItem.title = @"LIKERS";
    
    _photo = photo;
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.allowsSelection = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"userRowCell"];
  }
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self.view addSubview:_tableView];
  
  self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  self.navigationController.hidesBarsOnSwipe = NO;    // FIXME: why won't this work?

  _tableView.frame = self.view.bounds;
}


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
    [_photo.commentFeed requestPageWithCompletionBlock:^(NSArray *newComments) {        // FIXME: add number of items to load
      [_tableView reloadData];  //FIXME: insert
      [self.view setNeedsLayout];
    }];
  }
}


#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [_photo.commentFeed numberOfItemsInFeed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:@"userRowCell"];
  
  if ([[cell.contentView subviews] count] == 0) {
    UserRowView *userRowView = [[UserRowView alloc] initWithFrame:cell.frame withPhotoFeedModelType:UserRowViewTypeComments];
    [cell.contentView addSubview:userRowView];
  }
  
  CommentModel *comment = [_photo.commentFeed objectAtIndex:indexPath.row];
  [[[cell.contentView subviews] objectAtIndex:0] updateWithCommentModel:comment];
  
  return cell;
}

@end

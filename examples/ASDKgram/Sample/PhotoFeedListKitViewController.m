//
//  PhotoFeedListKitViewController.m
//  Sample
//
//  Created by Adlai Holler on 12/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "PhotoFeedListKitViewController.h"
#import <IGListKit/IGListKit.h>
#import "PhotoFeedModel.h"
#import "PhotoFeedSectionController.h"
#import "RefreshingSectionControllerType.h"

@interface PhotoFeedListKitViewController () <IGListAdapterDataSource, ASCollectionDelegate>
@property (nonatomic, strong) IGListAdapter *listAdapter;
@property (nonatomic, strong) PhotoFeedModel *photoFeed;
@property (nonatomic, strong, readonly) ASCollectionNode *collectionNode;
@property (nonatomic, strong, readonly) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, readonly) UIRefreshControl *refreshCtrl;
@end

@implementation PhotoFeedListKitViewController
@synthesize spinner = _spinner;

- (instancetype)init
{
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  ASCollectionNode *node = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
  if (self = [super initWithNode:node]) {
    CGRect screenRect   = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    CGSize screenWidthImageSize = CGSizeMake(screenRect.size.width * screenScale, screenRect.size.width * screenScale);
    _photoFeed = [[PhotoFeedModel alloc] initWithPhotoFeedModelType:PhotoFeedModelTypePopular imageSize:screenWidthImageSize];

    IGListAdapterUpdater *updater = [[IGListAdapterUpdater alloc] init];
    _listAdapter = [[IGListAdapter alloc] initWithUpdater:updater viewController:self workingRangeSize:0];
    _listAdapter.dataSource = self;
    self.collectionNode.listAdapter = _listAdapter;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.collectionNode.view.alwaysBounceVertical = YES;
  _refreshCtrl = [[UIRefreshControl alloc] init];
  [_refreshCtrl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
  [self.collectionNode.view addSubview:_refreshCtrl];
  _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
}

- (ASCollectionNode *)collectionNode
{
  return self.node;
}

- (void)resetAllData
{
  // nop, not used currently
}

- (void)refreshFeed
{
  // Ask the first section controller to do the refreshing.
  id<RefreshingSectionControllerType> secCtrl = [self.listAdapter sectionControllerForObject:self.photoFeed];
  if ([secCtrl conformsToProtocol:@protocol(RefreshingSectionControllerType)]) {
    [secCtrl refreshContentWithCompletion:^{
      [self.refreshCtrl endRefreshing];
    }];
  }
}

- (UIActivityIndicatorView *)spinner
{
  if (_spinner == nil) {
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [_spinner startAnimating];
  }
  return _spinner;
}

#pragma mark - IGListAdapterDataSource

- (NSArray<id <IGListDiffable>> *)objectsForListAdapter:(IGListAdapter *)listAdapter
{
  return @[ self.photoFeed ];
}

- (UIView *)emptyViewForListAdapter:(IGListAdapter *)listAdapter
{
  return self.spinner;
}

- (IGListSectionController <IGListSectionType> *)listAdapter:(IGListAdapter *)listAdapter sectionControllerForObject:(id)object
{
  if ([object isKindOfClass:[PhotoFeedModel class]]) {
    return [[PhotoFeedSectionController alloc] init];
  } else {
    ASDisplayNodeFailAssert(@"Only supports objects of class PhotoFeedModel.");
    return nil;
  }
}

@end

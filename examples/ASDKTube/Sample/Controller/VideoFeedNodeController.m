//
//  VideoFeedNodeController.m
//  AsyncDisplayKit
//
//  Created by Erekle on 5/15/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "VideoFeedNodeController.h"
#import <AsyncDisplayKit/ASVideoPlayerNode.h>
#import "VideoModel.h"
#import "VideoContentCell.h"

@interface VideoFeedNodeController ()<ASTableDelegate, ASTableDataSource>

@end

@implementation VideoFeedNodeController
{
  ASTableNode *_tableNode;
  NSMutableArray<VideoModel*> *_videoFeedData;
}

- (instancetype)init
{
  self.navigationItem.title = @"Home";
  _tableNode = [[ASTableNode alloc] init];
  _tableNode.delegate = self;
  _tableNode.dataSource = self;

  if (!(self = [super initWithNode:_tableNode])) {
    return nil;
  }

  return self;
}

- (void)loadView
{
  [super loadView];

  [self generateFeedData];

  [_tableNode.view reloadData];
}

- (void)generateFeedData
{
  _videoFeedData = [[NSMutableArray alloc] init];

  for (int i = 0; i < 30; i++) {
    [_videoFeedData addObject:[[VideoModel alloc] init]];
  }
}

#pragma mark - ASCollectionDelegate - ASCollectionDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
  return _videoFeedData.count;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  VideoModel *videoObject = [_videoFeedData objectAtIndex:indexPath.row];
  VideoContentCell *cellNode = [[VideoContentCell alloc] initWithVideoObject:videoObject];
  return cellNode;
}
@end

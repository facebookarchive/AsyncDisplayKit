//
//  VideoFeedNodeController.m
//  Sample
//
//  Created by Erekle on 5/15/16.
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

  [_tableNode reloadData];
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

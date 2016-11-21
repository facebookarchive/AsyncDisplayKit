//
//  AsyncTableViewController.m
//  Sample
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

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#import "AsyncTableViewController.h"
#import "RandomCoreGraphicsNode.h"

@interface AsyncTableViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;
}

@end

@implementation AsyncTableViewController

#pragma mark - UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;
  
  self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)reloadEverything
{
  [_tableView reloadData];
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _tableView = [[ASTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
  _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;
  
  ASRangeTuningParameters tuningParameters;
  tuningParameters.leadingBufferScreenfuls = 0.5;
  tuningParameters.trailingBufferScreenfuls = 1.0;
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypePreload];
  [_tableView setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeRender];
  
  [self.view addSubview:_tableView];
}

#pragma mark - ASTableView.

- (ASCellNodeBlock)tableView:(ASTableView *)tableView nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return ^{
    RandomCoreGraphicsNode *elementNode = [[RandomCoreGraphicsNode alloc] init];
    elementNode.size = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(320, 100));
    return elementNode;
  };
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end

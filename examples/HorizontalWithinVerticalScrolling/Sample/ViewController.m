//
//  ViewController.m
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

#import <AsyncDisplayKit/ASAssert.h>

#import "ViewController.h"
#import "HorizontalScrollCellNode.h"

@interface ViewController () <ASTableDataSource, ASTableDelegate>
{
  ASTableNode *_tableNode;
}

@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super initWithNode:_tableNode]))
    return nil;

  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  _tableNode.dataSource = self;
  _tableNode.delegate = self;
  
  self.title = @"Horizontal Scrolling Gradients";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRedo
                                                                                         target:self
                                                                                         action:@selector(reloadEverything)];

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
}

- (void)reloadEverything
{
  [_tableNode reloadDataWithCompletion:nil];
}

#pragma mark - ASTableView.

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [[HorizontalScrollCellNode alloc] initWithElementSize:CGSizeMake(100, 100)];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return 100;
}

@end

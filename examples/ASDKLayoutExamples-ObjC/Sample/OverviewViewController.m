//
//  OverviewViewController.m
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

#import "OverviewViewController.h"

#import "LayoutExampleNodes.h"
#import "LayoutExampleViewController.h"
#import "OverviewCellNode.h"

@interface OverviewViewController () <ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong) NSArray *layoutExamples;
@property (nonatomic, strong) ASTableNode *tableNode;
@end

@implementation OverviewViewController

#pragma mark - Lifecycle Methods

- (instancetype)init
{
  _tableNode = [ASTableNode new];
  self = [super initWithNode:_tableNode];
  
  if (self) {
    self.title = @"Layout Examples";
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    _tableNode.delegate = self;
    _tableNode.dataSource = self;
    
    _layoutExamples = @[[HeaderWithRightAndLeftItems class],
                        [PhotoWithInsetTextOverlay class],
                        [PhotoWithOutsetIconOverlay class],
                        [FlexibleSeparatorSurroundingContent class]];
  }
  
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  NSIndexPath *indexPath = _tableNode.indexPathForSelectedRow;
  if (indexPath != nil) {
    [_tableNode deselectRowAtIndexPath:indexPath animated:YES];
  }
}

#pragma mark - ASTable

- (NSInteger)numberOfSectionsInTableNode:(ASTableNode *)tableNode
{
  return 1;
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return [_layoutExamples count];
}

- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  OverviewCellNode *cellNode = [OverviewCellNode new];
  cellNode.layoutExampleClass = _layoutExamples[indexPath.row];
  return cellNode;
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  OverviewCellNode *node = [tableNode nodeForRowAtIndexPath:indexPath];
  LayoutExampleViewController *detail = [[LayoutExampleViewController alloc] initWithClass:node.layoutExampleClass];
  detail.title = @"Layout Example";
  [self.navigationController pushViewController:detail animated:YES];
}

@end

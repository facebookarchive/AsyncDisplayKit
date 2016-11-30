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

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#import "BlurbNode.h"
#import "KittenNode.h"


static const NSInteger kLitterSize = 20;            // intial number of kitten cells in ASTableNode
static const NSInteger kLitterBatchSize = 10;       // number of kitten cells to add to ASTableNode
static const NSInteger kMaxLitterSize = 100;        // max number of kitten cells allowed in ASTableNode

@interface ViewController () <ASTableDataSource, ASTableDelegate>
{
  ASTableNode *_tableNode;

  // array of boxed CGSizes corresponding to placekitten.com kittens
  NSMutableArray *_kittenDataSource;

  BOOL _dataSourceLocked;
  NSIndexPath *_blurbNodeIndexPath;
}

@property (nonatomic, strong) NSMutableArray *kittenDataSource;
@property (atomic, assign) BOOL dataSourceLocked;

@end


@implementation ViewController

#pragma mark - Lifecycle

- (instancetype)init
{
  _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStylePlain];
  _tableNode.dataSource = self;
  _tableNode.delegate = self;

  if (!(self = [super initWithNode:_tableNode]))
    return nil;

  // populate our "data source" with some random kittens
  _kittenDataSource = [self createLitterWithSize:kLitterSize];
  _blurbNodeIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
  
  self.title = @"Kittens";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                         target:self
                                                                                         action:@selector(toggleEditingMode)];
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone; // KittenNode has its own separator
  [self.node addSubnode:_tableNode];
}

#pragma mark - Data Model

- (NSMutableArray *)createLitterWithSize:(NSInteger)litterSize
{
  NSMutableArray *kittens = [NSMutableArray arrayWithCapacity:litterSize];
  for (NSInteger i = 0; i < litterSize; i++) {
      
    // placekitten.com will return the same kitten picture if the same pixel height & width are requested,
    // so generate kittens with different width & height values.
    u_int32_t deltaX = arc4random_uniform(10) - 5;
    u_int32_t deltaY = arc4random_uniform(10) - 5;
    CGSize size = CGSizeMake(350 + 2 * deltaX, 350 + 4 * deltaY);
      
    [kittens addObject:[NSValue valueWithCGSize:size]];
  }
  return kittens;
}

- (void)setKittenDataSource:(NSMutableArray *)kittenDataSource {
  ASDisplayNodeAssert(!self.dataSourceLocked, @"Could not update data source when it is locked !");

  _kittenDataSource = kittenDataSource;
}

- (void)toggleEditingMode
{
  [_tableNode.view setEditing:!_tableNode.view.editing animated:YES];
}


#pragma mark - ASTableNode

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  // blurb node + kLitterSize kitties
  return 1 + _kittenDataSource.count;
}

- (ASCellNode *)tableNode:(ASTableNode *)tableNode nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  // special-case the first row
  if ([_blurbNodeIndexPath compare:indexPath] == NSOrderedSame) {
    BlurbNode *node = [[BlurbNode alloc] init];
    return node;
  }

  NSValue *size = _kittenDataSource[indexPath.row - 1];
  KittenNode *node = [[KittenNode alloc] initWithKittenOfSize:size.CGSizeValue];
  return node;
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [_tableNode deselectRowAtIndexPath:indexPath animated:YES];
  
  // Assume only kitten nodes are selectable (see -tableNode:shouldHighlightRowAtIndexPath:).
  KittenNode *node = (KittenNode *)[_tableNode nodeForRowAtIndexPath:indexPath];
  
  [node toggleImageEnlargement];
}

- (BOOL)tableNode:(ASTableNode *)tableNode shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Enable selection for kitten nodes
  return [_blurbNodeIndexPath compare:indexPath] != NSOrderedSame;
}

- (void)tableNode:(ASTableNode *)tableNode willBeginBatchFetchWithContext:(nonnull ASBatchContext *)context
{
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    // populate a new array of random-sized kittens
    NSArray *moarKittens = [self createLitterWithSize:kLitterBatchSize];

    NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
      
    // find number of kittens in the data source and create their indexPaths
    NSInteger existingRows = _kittenDataSource.count + 1;
      
    for (NSInteger i = 0; i < moarKittens.count; i++) {
      [indexPaths addObject:[NSIndexPath indexPathForRow:existingRows + i inSection:0]];
    }

    // add new kittens to the data source & notify table of new indexpaths
    [_kittenDataSource addObjectsFromArray:moarKittens];
    [tableNode insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];

    [context completeBatchFetching:YES];
  });
}

- (BOOL)shouldBatchFetchForTableNode:(ASTableNode *)tableNode
{
  return _kittenDataSource.count < kMaxLitterSize;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  // Enable editing for Kitten nodes
  return [_blurbNodeIndexPath compare:indexPath] != NSOrderedSame;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Assume only kitten nodes are editable (see -tableView:canEditRowAtIndexPath:).
    [_kittenDataSource removeObjectAtIndex:indexPath.row - 1];
    [_tableNode deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
  }
}

@end

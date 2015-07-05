/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

#define NumberOfSections 10
#define NumberOfRowsPerSection 20
#define NumberOfReloadIterations 500

@interface ViewController () <ASTableViewDataSource, ASTableViewDelegate>
{
  ASTableView *_tableView;
  NSMutableArray *_sections; // Contains arrays of indexPaths representing rows
}

@end


@implementation ViewController

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain asyncDataFetching:YES];
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;
  _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  
  _sections = [NSMutableArray arrayWithCapacity:NumberOfSections];
  for (int i = 0; i < NumberOfSections; i++) {
    NSMutableArray *rowsArray = [NSMutableArray arrayWithCapacity:NumberOfRowsPerSection];
    for (int j = 0; j < NumberOfRowsPerSection; j++) {
      [rowsArray addObject:[NSIndexPath indexPathForRow:j inSection:i]];
    }
    [_sections addObject:rowsArray];
  }

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_tableView];
}

- (void)viewWillLayoutSubviews
{
  _tableView.frame = self.view.bounds;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  [self thrashTableView];
}

- (NSIndexSet *)randomIndexSet
{
  u_int32_t upperBound = (u_int32_t)_sections.count - 1;
  u_int32_t randA = arc4random_uniform(upperBound);
  u_int32_t randB = arc4random_uniform(upperBound);

  return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(MIN(randA, randB), MAX(randA, randB) - MIN(randA, randB))];
}

- (NSArray *)randomIndexPathsExisting:(BOOL)existing
{
  NSMutableArray *indexPaths = [NSMutableArray array];
  [[self randomIndexSet] enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSUInteger rowNum = [self tableView:_tableView numberOfRowsInSection:idx];
    NSIndexPath *sectionIndex = [[NSIndexPath alloc] initWithIndex:idx];
    for (NSUInteger i = (existing ? 0 : rowNum); i < (existing ? rowNum : rowNum * 2); i++) {
      // Maximize evility by sporadically skipping indicies 1/3rd of the time, but only if reloading existing rows
      if (existing && arc4random_uniform(2) == 0) {
        continue;
      }
      
      NSIndexPath *indexPath = [sectionIndex indexPathByAddingIndex:i];
      [indexPaths addObject:indexPath];
    }
  }];
  return indexPaths;
}

- (void)thrashTableView
{
  _tableView.asyncDelegate = self;
  _tableView.asyncDataSource = self;
  
  [_tableView reloadData];
  
  NSArray *indexPathsAddedAndRemoved = nil;

  for (int i = 0; i < NumberOfReloadIterations; ++i) {
    UITableViewRowAnimation rowAnimation = (arc4random_uniform(1) == 0 ? UITableViewRowAnimationMiddle : UITableViewRowAnimationNone);

    BOOL animatedScroll               = (arc4random_uniform(1) == 0 ? YES : NO);
    BOOL reloadRowsInsteadOfSections  = (arc4random_uniform(1) == 0 ? YES : NO);
    BOOL letRunloopProceed            = (arc4random_uniform(1) == 0 ? YES : NO);
    BOOL addIndexPaths                = (arc4random_uniform(1) == 0 ? YES : NO);
    BOOL useBeginEndUpdates           = (arc4random_uniform(2) == 0 ? YES : NO);
    
    if (useBeginEndUpdates) {
      [_tableView beginUpdates];
    }
    
    if (reloadRowsInsteadOfSections) {
      [_tableView reloadRowsAtIndexPaths:[self randomIndexPathsExisting:YES] withRowAnimation:rowAnimation];
    } else {
      [_tableView reloadSections:[self randomIndexSet] withRowAnimation:rowAnimation];
    }
    
    if (addIndexPaths && !indexPathsAddedAndRemoved) {
      indexPathsAddedAndRemoved = [self randomIndexPathsExisting:NO];
      for (NSIndexPath *indexPath in indexPathsAddedAndRemoved) {
        [_sections[indexPath.section] addObject:indexPath];
      }
      [_tableView insertRowsAtIndexPaths:indexPathsAddedAndRemoved withRowAnimation:rowAnimation];
    }
    
    [_tableView setContentOffset:CGPointMake(0, arc4random_uniform(_tableView.contentSize.height - _tableView.bounds.size.height)) animated:animatedScroll];
    
    if (letRunloopProceed) {
      // Run other stuff on the main queue for between 2ms and 1000ms.
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:(1 / (1 + arc4random_uniform(500)))]];
      
      if (indexPathsAddedAndRemoved) {
        for (NSIndexPath *indexPath in indexPathsAddedAndRemoved) {
          [_sections[indexPath.section] removeObjectIdenticalTo:indexPath];
        }
        [_tableView deleteRowsAtIndexPaths:indexPathsAddedAndRemoved withRowAnimation:rowAnimation];
        indexPathsAddedAndRemoved = nil;
      }
    }
    
    if (useBeginEndUpdates) {
      [_tableView endUpdates];
    }
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [(NSArray *)[_sections objectAtIndex:section] count];
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASTextCellNode *textCellNode = [ASTextCellNode new];
  textCellNode.text = indexPath.description;
  
  return textCellNode;
}

@end

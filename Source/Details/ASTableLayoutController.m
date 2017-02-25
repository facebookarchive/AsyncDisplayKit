//
//  ASTableLayoutController.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableLayoutController.h>

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASAssert.h>

@interface ASTableLayoutController()
@end

@implementation ASTableLayoutController

- (instancetype)initWithTableView:(UITableView *)tableView
{
  if (!(self = [super init])) {
    return nil;
  }
  _tableView = tableView;
  return self;
}

#pragma mark - Visible Indices

/**
 * IndexPath array for the element in the working range.
 */
- (void)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode visibleIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outVisible displayIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outDisplay preloadIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outPreload
{
  ASDisplayNodeAssert(!CGRectIsEmpty(_tableView.bounds), @"Should not talk to layout controller if table bounds is empty.");
  
  *outDisplay = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay];
  *outVisible = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeVisible];
  *outPreload = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypePreload];
}

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();

  if (rangeType == ASLayoutRangeTypeVisible) {
    return [self visibleIndexPaths];
  }
  
  CGRect visibleRect = self.tableView.bounds;
  ASRangeTuningParameters params = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];
  CGRect rangeBounds = CGRectExpandToRangeWithScrollableDirections(visibleRect, params, ASScrollDirectionVerticalDirections, scrollDirection);
  return [NSSet setWithArray:[_tableView indexPathsForRowsInRect:rangeBounds]];
}

/**
 * It's critical that the "visible rows" are actually visible, and hosted inside a cell.
 * -indexPathsForVisibleRows: is the only method that reliably answers that question.
 *
 * At the same time, -indexPathsForVisibleRows: has a bug when used with Grouped style table views
 * where it returns extra index paths.
 */
- (NSSet<NSIndexPath *> *)visibleIndexPaths
{
  NSArray *indexPaths = _tableView.indexPathsForVisibleRows;
  if (_tableView.style == UITableViewStyleGrouped && indexPaths.count != _tableView.visibleCells.count) {
    CGRect visibleRect = self.tableView.bounds;
    indexPaths = [indexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath * _Nullable indexPath, NSDictionary<NSString *,id> * _Nullable bindings) {
      return CGRectIntersectsRect(visibleRect, [_tableView rectForRowAtIndexPath:indexPath]);
    }]];
  }
  return [NSSet setWithArray:indexPaths];
}

@end
